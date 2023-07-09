import { EditorView } from 'codemirror'
import {
  autocompletion,
  closeBrackets,
  closeBracketsKeymap, completeFromList,
  completionKeymap
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

function toString (context, node) { // eslint-disable-line no-unused-vars
  const nodeText = node ? context.state.doc.sliceString(node.from, node.to).toLowerCase() : null
  return `${node?.name}(${nodeText})`
}

export function createEditor (parent, metadata, onSubmit, onShiftSubmit) {
  const fixedHeightEditor = EditorView.theme({
    '.cm-scroller': {
      overflow: 'auto'
    }
  })
  const schemas = Object.entries(metadata.schemas)
  const editorSchema = {}
  const tables = []
  const aliases = []
  schemas.forEach(([schemaName, schema]) => {
    Object.entries(schema.tables).forEach(([tableName, table]) => {
      const qualifiedTableName = schemas.length === 1 ? tableName : `${schemaName}.${tableName}`
      const quotedQualifiedTableName = schemas.length === 1 ? `\`${tableName}\`` : `\`${schemaName}\`.\`${tableName}\``
      const columns = Object.keys(table.columns)
      editorSchema[qualifiedTableName] = columns
      const alias = metadata.tables[qualifiedTableName]?.alias
      if (alias) {
        aliases.push(alias)
        aliases.push(`\`${alias}\``)
      }

      let boost = metadata.tables[qualifiedTableName]?.boost
      boost = boost ? boost * 2 : null
      if (alias) {
        editorSchema[alias] = columns
        // Add a completion which inserts the table name and alias for use just after join or from.
        tables.push({
          label: `${qualifiedTableName} ${alias}`,
          boost: boost + 1,
          completion_types: ['table_with_alias'],
          quoted: `${quotedQualifiedTableName} \`${alias}\``,
          unquoted: `${qualifiedTableName} ${alias}`
        })
        tables.push({
          label: alias,
          boost: boost + 1,
          type: 'constant',
          completion_types: ['alias_only'],
          quoted: '`' + alias + '`',
          unquoted: alias
        })
      }
      tables.push({
        label: qualifiedTableName,
        boost,
        completion_types: ['table_with_alias', 'alias_only', 'table_only'],
        quoted: quotedQualifiedTableName,
        unquoted: qualifiedTableName
      })
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
    ...completionKeymap
  ])
  const sqlConfig = {
    dialect: MySQL,
    upperCaseKeywords: false,
    schema: editorSchema,
    tables
  }
  const originalSchemaCompletionSource = schemaCompletionSource(sqlConfig)

  const joinCompletions = []
  metadata.joins.forEach((join) => {
    joinCompletions.push({ label: join.label, apply: join.apply, type: 'keyword' })
  })
  const customJoinCompletionSource = completeFromList(joinCompletions)

  const sqlExtension = new LanguageSupport(
    MySQL.language,
    [
      MySQL.language.data.of({
        autocomplete: (context) => {
          const result = originalSchemaCompletionSource(context)
          if (!result?.options || result.options.length === 0) return result

          const tree = syntaxTree(context.state)
          let node = tree.resolveInner(context.pos, -1)
          if (!node) return result

          // We want to customize the autocomplete options based on context. For instance, after select or where, we
          // should autocomplete aliases, if they are defined, otherwise table names. After from, we should autocomplete
          // table names with aliases. Etc. We start by trying to identify the node before our current position. The
          // method for accomplishing this seems to vary based on the user's context.
          let foundSchema
          if (node.name === 'Statement') {
            // The current node can be a Statement if the cursor is at the end of "from " (for instance) and there is a
            // complete statement in the editor (semicolon present). In that case we want to find the node just before
            // the current position.
            node = node.childBefore(context.pos)
          } else if (node.name === 'Script') {
            // It seems the node can sometimes be a Script if the cursor is at the end of the last statement in the
            // editor and the statement doesn't end in a semicolon. In that case we can find the last statement in the
            // Script.
            node = node.lastChild?.childBefore(context.pos)
          } else if (node.name === 'Parens') {
            // The current node can be a Parens if we are inside of a function or sub query, for instance just after a
            // space after a "select" in "select * from (select ) as foo". In that case we can find the last statement
            // in the Parens.
            node = node.childBefore(context.pos)
          } else if (['Identifier', 'QuotedIdentifier', 'Keyword', '.'].includes(node.name)) {
            // If the node is an Identifier, we might be in the middle of typing the table name. If the node is a
            // Keyword, we might be in the middle of typing a table name that is similar to a Keyword, for instance
            // "orders" or "selections" or "fromages". In these cases, look for the previous sibling. If the node is a
            // '.' or if the previous sibling is a '.', we might be in the middle of typing something like
            // "schema.table" or "`schema`.table" or "`schema`.`table`". In these cases we need to record the schema
            // used so that we can autocomplete table names with aliases.
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

          // We now have the node before the node the user is currently creating. Step back or up until we find a Keyword.
          while (true) {
            const nodeText = node ? context.state.doc.sliceString(node.from, node.to).toLowerCase() : null
            if (!node || (node.name === 'Keyword' &&
              ['where', 'select', 'from', 'into', 'join', 'straight_join', 'database', 'as'].includes(nodeText))) {
              break
            }

            node = node?.prevSibling || node?.parent
          }
          const nodeText = node ? context.state.doc.sliceString(node.from, node.to).toLowerCase() : null
          let completionType = 'table_only'
          if (node?.name === 'Keyword') {
            if (['from', 'join', 'straight_join'].includes(nodeText)) {
              completionType = 'table_with_alias'
            } else if (['where', 'select'].includes(nodeText)) {
              completionType = 'alias_only'
            }

            if (['join', 'straight_join'].includes(nodeText)) {
              const customJoins = customJoinCompletionSource(context)
              if (customJoins?.options) {
                result.options = result.options.concat(customJoins.options)
              }
            }
          }
          result.options = result.options.filter((option) => {
            if (option.completion_types === undefined && option.type === 'constant' && aliases.includes(option.label)) {
              // The default options already include an alias if the statement includes one in the from clause.
              // In that case we want to remove it in favor of our own alias option.
              return false
            }
            // Allow any options we didn't create plus options we created which are of the expected type.
            return option.completion_types === undefined || option.completion_types.includes(completionType)
          })
          result.options = result.options.map((option) => {
            // Some shenanigans. If the default autocomplete function quoted the label, we want to ensure the quote
            // only applies to the table name and not the alias. You might think we could do this by overriding the
            // apply function but apply is set to null when quoting.
            // See https://github.com/codemirror/lang-sql/blob/ebf115fffdbe07f91465ccbd82868c587f8182bc/src/complete.ts#L90
            if (option.quoted) {
              if (option.label.match(/^`.*`$/)) {
                option.apply = option.quoted
              } else {
                option.apply = option.unquoted
              }
            }
            if (foundSchema && completionType === 'table_with_alias') {
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
        autocomplete: keywordCompletionSource(MySQL, false)
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
        placeholder('Let\'s squeal!')
      ]
    }),
    parent
  })
}

function unquoteSqlId (identifier) {
  const match = identifier.match(/^`(.*)`$/)
  return match ? match[1] : identifier
}
