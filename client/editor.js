import { EditorView } from 'codemirror'
import {
  autocompletion,
  closeBrackets,
  closeBracketsKeymap,
  completeFromList,
  completionKeymap,
  ifNotIn
} from '@codemirror/autocomplete'
import { defaultKeymap, history, historyKeymap } from '@codemirror/commands'
import {
  keywordCompletionSource,
  MySQL,
  schemaCompletionSource
} from '@codemirror/lang-sql'
import {
  bracketMatching,
  defaultHighlightStyle,
  foldGutter,
  foldKeymap,
  indentOnInput, LanguageSupport,
  syntaxHighlighting, syntaxTree
} from '@codemirror/language'
import { lintKeymap } from '@codemirror/lint'
import { highlightSelectionMatches, searchKeymap } from '@codemirror/search'
import { EditorState } from '@codemirror/state'
import {
  crosshairCursor,
  drawSelection,
  dropCursor,
  highlightActiveLine,
  highlightActiveLineGutter,
  highlightSpecialChars,
  keymap,
  lineNumbers,
  placeholder,
  rectangularSelection
} from '@codemirror/view'

export function createEditor (parent, metadata, onSubmit, onShiftSubmit) {
  const fixedHeightEditor = EditorView.theme({
    '.cm-scroller': {
      height: '200px',
      overflow: 'auto',
      resize: 'vertical'
    }
  })
  const schemas = Object.entries(metadata.schemas)
  const editorSchema = {}
  const tables = []
  schemas.forEach(([schemaName, schema]) => {
    Object.entries(schema.tables).forEach(([tableName, table]) => {
      const qualifiedTableName = schemas.length === 1 ? tableName : `${schemaName}.${tableName}`
      const quotedQualifiedTableName = schemas.length === 1 ? `\`${tableName}\`` : `\`${schemaName}\`.\`${tableName}\``
      const columns = Object.keys(table.columns)
      editorSchema[qualifiedTableName] = columns
      const alias = metadata.tables[qualifiedTableName]?.alias
      const boost = metadata.tables[qualifiedTableName]?.boost
      if (alias) {
        editorSchema[alias] = columns
        tables.push({
          label: qualifiedTableName,
          detail: alias,
          boost,
          alias_type: 'with',
          quoted: `${quotedQualifiedTableName} \`${alias}\``,
          unquoted: `${qualifiedTableName} ${alias}`
        })
        tables.push({
          label: qualifiedTableName,
          detail: alias,
          boost,
          alias_type: 'only',
          quoted: '`' + alias + '`',
          unquoted: alias
        })
      } else {
        tables.push({
          label: qualifiedTableName
        })
      }
    })
  })
  // I prefer to use Cmd-Enter/Ctrl-Enter to submit the query. Here I am replacing the default mapping.
  // See https://codemirror.net/docs/ref/#commands.defaultKeymap
  // See https://github.com/codemirror/commands/blob/6aa9989f38fe3c7dbc9b72c5015a3db97370c07a/src/commands.ts#L891
  const customDefaultKeymap = defaultKeymap.map(keymap => {
    if (keymap.key === 'Mod-Enter') {
      keymap.key = 'Shift-Enter'
    }
    return keymap
  })
  const editorKeymap = keymap.of([
    {
      key: 'Cmd-Enter',
      run: onSubmit,
      preventDefault: true,
      shift: onShiftSubmit
    },
    {
      key: 'Ctrl-Enter',
      run: onSubmit,
      preventDefault: true,
      shift: onShiftSubmit
    },
    ...closeBracketsKeymap,
    ...customDefaultKeymap,
    ...searchKeymap,
    ...historyKeymap,
    ...foldKeymap,
    ...completionKeymap,
    ...lintKeymap
  ])
  const sqlConfig = {
    dialect: MySQL,
    upperCaseKeywords: true,
    schema: editorSchema,
    tables
  }
  const originalSchemaCompletionSource = schemaCompletionSource(sqlConfig)
  const originalKeywordCompletionSource = keywordCompletionSource(MySQL, true)
  const keywordCompletions = []
  metadata.joins.forEach((join) => {
    ['JOIN', 'INNER JOIN', 'LEFT JOIN', 'RIGHT JOIN', 'CROSS JOIN'].forEach((type) => {
      keywordCompletions.push({ label: `${type} ${join.label}`, apply: `${type} ${join.apply}`, type: 'keyword' })
    })
  })
  let combinedKeywordCompletionSource
  if (keywordCompletions.length > 0) {
    const customKeywordCompletionSource = ifNotIn(['QuotedIdentifier', 'SpecialVar', 'String', 'LineComment', 'BlockComment', '.'], completeFromList(keywordCompletions))
    combinedKeywordCompletionSource = function (context) {
      const original = originalKeywordCompletionSource(context)
      const custom = customKeywordCompletionSource(context)
      if (original?.options && custom?.options) {
        original.options = original.options.concat(custom.options)
      }
      return original
    }
  } else {
    combinedKeywordCompletionSource = originalKeywordCompletionSource
  }
  const sqlExtension = new LanguageSupport(
    MySQL.language,
    [
      MySQL.language.data.of({
        autocomplete: (context) => {
          const result = originalSchemaCompletionSource(context)
          if (!result?.options) return result

          const tree = syntaxTree(context.state)
          let node = tree.resolveInner(context.pos, -1)
          if (!node) return result

          // We are trying to identify the case where we are autocompleting a table name after "from" or "join"

          // TODO: we don't handle the case where a user typed "select table.foo from". In that case we probably
          // shouldn't autocomplete the alias. Though, if the user typed "select table.foo, t.bar", we won't know
          // what to do. Maybe it is ok to force users to simply delete the alias after autocompleting.

          // TODO: if table aliases aren't enabled, we don't need to override autocomplete.

          let foundSchema
          if (node.name === 'Statement') {
            // The node can be a Statement if the cursor is at the end of "from " and there is a complete
            // statement in the editor (semicolon present). In that case we want to find the node just before the
            // current position so that we can check whether it is "from" or "join".
            node = node.childBefore(context.pos)
          } else if (node.name === 'Script') {
            // It seems the node can sometimes be a Script if the cursor is at the end of the last statement in the
            // editor and the statement doesn't end in a semicolon. In that case we can find the last statement in the
            // Script so that we can check whether it is "from" or "join".
            node = node.lastChild?.childBefore(context.pos)
          } else if (['Identifier', 'QuotedIdentifier', 'Keyword', '.'].includes(node.name)) {
            // If the node is an Identifier, we might be in the middle of typing the table name. If the node is a
            // Keyword but isn't "from" or "join", we might be in the middle of typing a table name that is similar
            // to a Keyword, for instance "orders" or "selections" or "fromages". In these cases, look for the previous
            // sibling so that we can check whether it is "from" or "join". If we found a '.' or if the previous
            // sibling is a '.', we might be in the middle of typing something like "schema.table" or
            // "`schema`.table" or "`schema`.`table`". In these cases we need to record the schema used so that we
            // can autocomplete table names with aliases.
            if (node.name !== '.') {
              node = node.prevSibling
            }

            if (node?.name === '.') {
              node = node.prevSibling
              if (['Identifier', 'QuotedIdentifier'].includes(node?.name)) {
                foundSchema = unquoteSqlId(context.state.doc.sliceString(node.from, node.to))
                node = node.parent
                if (node?.name === 'CompositeIdentifier') {
                  node = node.prevSibling
                }
              }
            }
          }

          const nodeText = node ? context.state.doc.sliceString(node.from, node.to).toLowerCase() : null
          if (node?.name === 'Keyword' && ['from', 'join'].includes(nodeText)) {
            result.options = result.options.filter((option) => {
              return option.alias_type === undefined || option.alias_type === 'with'
            })
          } else {
            result.options = result.options.filter((option) => {
              return option.alias_type === undefined || option.alias_type === 'only'
            })
          }
          result.options = result.options.map((option) => {
            // Some shenanigans. If the default autocomplete function quoted the label, we want to ensure the quote
            // only applies to the table name and not the alias. You might think we could do this by overriding the
            // apply function but apply is set to null when quoting.
            // See https://github.com/codemirror/lang-sql/blob/ebf115fffdbe07f91465ccbd82868c587f8182bc/src/complete.ts#L90
            if (option.alias_type) {
              if (option.label.match(/^`.*`$/)) {
                option.apply = option.quoted
              } else {
                option.apply = option.unquoted
              }
            }
            if (foundSchema) {
              const unquotedLabel = unquoteSqlId(option.label)
              const quoted = unquotedLabel !== option.label
              const tableConfig = metadata.tables[`${foundSchema}.${unquotedLabel}`]
              const alias = tableConfig?.alias
              const boost = tableConfig?.boost || -1
              const optionOverride = {
                label: option.label
              }
              if (alias) {
                optionOverride.label = quoted ? `\`${unquotedLabel}\` \`${alias}\`` : `${option.label} ${alias}`
              }
              if (boost) {
                optionOverride.boost = boost
              }
              if (alias || boost) return optionOverride
            }
            return option
          })
          return result
        }
      }),
      MySQL.language.data.of({
        autocomplete: combinedKeywordCompletionSource
      })
    ]
  )
  return new EditorView({
    state: EditorState.create({
      extensions: [
        lineNumbers(),
        highlightActiveLineGutter(),
        highlightSpecialChars(),
        history(),
        foldGutter(),
        drawSelection(),
        dropCursor(),
        EditorState.allowMultipleSelections.of(true),
        indentOnInput(),
        syntaxHighlighting(defaultHighlightStyle, { fallback: true }),
        bracketMatching(),
        closeBrackets(),
        autocompletion(),
        rectangularSelection(),
        crosshairCursor(),
        highlightActiveLine(),
        highlightSelectionMatches(),
        editorKeymap,
        sqlExtension,
        fixedHeightEditor,
        placeholder('Let\'s query!')
      ]
    }),
    parent
  })
}

function unquoteSqlId (identifier) {
  const match = identifier.match(/^`(.*)`$/)
  return match ? match[1] : identifier
}
