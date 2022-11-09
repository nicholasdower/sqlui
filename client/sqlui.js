import { EditorView } from 'codemirror'
import { defaultKeymap, history, historyKeymap, standardKeymap } from '@codemirror/commands'
import { EditorState } from '@codemirror/state'
import {
  autocompletion,
  closeBrackets,
  closeBracketsKeymap,
  completionKeymap
} from '@codemirror/autocomplete'
import {
  bracketMatching,
  defaultHighlightStyle,
  foldGutter, foldKeymap,
  indentOnInput,
  syntaxHighlighting
} from '@codemirror/language'
import {
  lintKeymap
} from '@codemirror/lint'
import {
  highlightSelectionMatches, searchKeymap
} from '@codemirror/search'
import {
  crosshairCursor,
  drawSelection, dropCursor, highlightActiveLine,
  highlightActiveLineGutter,
  highlightSpecialChars,
  keymap,
  lineNumbers,
  placeholder, rectangularSelection
} from '@codemirror/view'
import { MySQL, sql } from '@codemirror/lang-sql'

/* global google */

function init (parent, onSubmit, onShiftSubmit) {
  document.getElementById('query-tab-button').addEventListener('click', function (event) {
    selectTab(event, 'query')
  })
  document.getElementById('saved-tab-button').addEventListener('click', function (event) {
    selectTab(event, 'saved')
  })
  document.getElementById('structure-tab-button').addEventListener('click', function (event) {
    selectTab(event, 'structure')
  })
  document.getElementById('graph-tab-button').addEventListener('click', function (event) {
    selectTab(event, 'graph')
  })
  document.getElementById('submit-all-button').addEventListener('click', function (event) {
    submitAll(event.target, event)
  })
  document.getElementById('submit-current-button').addEventListener('click', function (event) {
    submitCurrent(event.target, event)
  })
  document.getElementById('cancel-button').addEventListener('click', function (event) {
    clearResult()
  })

  const isMac = navigator.userAgent.includes('Mac')
  document.getElementById('submit-current-button').value = `run selection (${isMac ? '⌘' : 'Ctrl'}-Shift-Enter)`
  document.getElementById('submit-all-button').value = `run (${isMac ? '⌘' : 'Ctrl'}-Shift-Enter)`

  const fixedHeightEditor = EditorView.theme({
    '.cm-scroller': { height: '200px', overflow: 'auto', resize: 'vertical' }
  })
  const schemas = Object.entries(window.metadata.schemas)
  const editorSchema = {}
  schemas.forEach(([schemaName, schema]) => {
    Object.entries(schema.tables).forEach(([tableName, table]) => {
      const qualifiedTableName = schemas.length === 1 ? tableName : `${schemaName}.${tableName}`
      editorSchema[qualifiedTableName] = Object.keys(table.columns)
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
    { key: 'Cmd-Enter', run: onSubmit, preventDefault: true, shift: onShiftSubmit },
    { key: 'Ctrl-Enter', run: onSubmit, preventDefault: true, shift: onShiftSubmit },
    ...closeBracketsKeymap,
    ...customDefaultKeymap,
    ...searchKeymap,
    ...historyKeymap,
    ...foldKeymap,
    ...completionKeymap,
    ...lintKeymap
  ])
  window.editorView = new EditorView({
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
        sql({
          dialect: MySQL,
          upperCaseKeywords: true,
          schema: editorSchema
        }),
        fixedHeightEditor,
        placeholder("Let's query!")
      ]
    }),
    parent
  })
}

function getSelection () {
  const anchor = window.editorView.state.selection.main.anchor
  const head = window.editorView.state.selection.main.head
  if (anchor === head) {
    return `${anchor}`
  } else {
    return `${anchor}-${head}`
  }
}

function setSelection (selection) {
  let anchor
  let head
  if (selection.includes('-')) {
    selection = selection.split('-').map(x => parseInt(x))
    anchor = Math.min(selection[0], window.editorView.state.doc.length)
    head = Math.min(selection[1], window.editorView.state.doc.length)
  } else {
    anchor = Math.min(parseInt(selection), window.editorView.state.doc.length)
    head = anchor
  }
  window.editorView.dispatch({ selection: { anchor, head } })
}

function focus () {
  window.editorView.focus()
}

function getValue () {
  return window.editorView.state.doc.toString()
}

function setValue (value) {
  window.editorView.dispatch({
    changes: {
      from: 0,
      to: window.editorView.state.doc.length,
      insert: value
    }
  })
}

function setTabInUrl (url, tab) {
  url.pathname = url.pathname.replace(/\/[^/]+$/, `/${tab}`)
}

function getTabFromUrl (url) {
  const match = url.pathname.match(/\/([^/]+)$/)
  if (match && ['query', 'graph', 'structure', 'saved'].includes(match[1])) {
    return match[1]
  } else {
    throw new Error(`invalid tab: ${url.pathname}`)
  }
}

function updateTabs () {
  const url = new URL(window.location)
  setTabInUrl(url, 'graph')
  document.getElementById('graph-tab-button').href = url.pathname + url.search
  setTabInUrl(url, 'saved')
  document.getElementById('saved-tab-button').href = url.pathname + url.search
  setTabInUrl(url, 'structure')
  document.getElementById('structure-tab-button').href = url.pathname + url.search
  setTabInUrl(url, 'query')
  document.getElementById('query-tab-button').href = url.pathname + url.search
}

function selectTab (event, tab) {
  const url = new URL(window.location)
  setTabInUrl(url, tab)
  route(event.target, event, url, true)
}

function route (target = null, event = null, url = null, internal = false) {
  if (url) {
    if (event) {
      event.preventDefault()
      if (!(target instanceof EditorView && event instanceof KeyboardEvent)) {
        if (event.shiftKey) {
          window.open(url).focus()
          return
        }
        if (event.metaKey) {
          window.open(url, '_blank').focus()
          return
        }
      }
    }
    if (url.href !== window.location.href) {
      window.history.pushState({}, '', url)
    }
  } else {
    url = new URL(window.location)
  }
  updateTabs()
  window.tab = getTabFromUrl(url)

  const tabElement = document.getElementById(`${window.tab}-tab-button`)
  Array.prototype.forEach.call(document.getElementsByClassName('selected-tab-button'), function (selected) {
    selected.classList.remove('selected-tab-button')
    selected.classList.add('tab-button')
  })
  tabElement.classList.remove('tab-button')
  tabElement.classList.add('selected-tab-button')

  Array.prototype.forEach.call(document.getElementsByClassName('tab-content-element'), function (selected) {
    selected.style.display = 'none'
  })

  switch (window.tab) {
    case 'query':
      selectResultTab(internal)
      break
    case 'graph':
      selectGraphTab(internal)
      break
    case 'saved':
      selectSavedTab()
      break
    case 'structure':
      selectStructureTab()
      break
    default:
      throw new Error(`Unexpected tab: ${window.tab}`)
  }
}

function selectStructureTab () {
  Array.prototype.forEach.call(document.getElementsByClassName('structure-element'), function (selected) {
    selected.style.display = 'flex'
  })

  if (window.structureLoaded) {
    return
  }

  const schemasElement = document.getElementById('schemas')
  const tablesElement = document.getElementById('tables')
  const columnsElement = document.getElementById('columns')
  const indexesElement = document.getElementById('indexes')

  const schemaNames = Object.keys(window.metadata.schemas)
  if (schemaNames.length === 1) {
    schemasElement.style.display = 'none'
    // TODO: duplicate code
    while (tablesElement.firstChild) {
      tablesElement.removeChild(tablesElement.firstChild)
    }
    const schemaName = schemaNames[0]
    const schema = window.metadata.schemas[schemaName]
    const tableNames = Object.keys(schema.tables)
    tableNames.forEach(function (tableName) {
      const optionElement = document.createElement('option')
      optionElement.value = tableName
      optionElement.innerText = tableName
      tablesElement.appendChild(optionElement)
    })
  } else {
    schemasElement.style.display = 'flex'
    schemaNames.forEach(function (schemaName) {
      const optionElement = document.createElement('option')
      optionElement.value = schemaName
      optionElement.innerText = schemaName
      schemasElement.appendChild(optionElement)
    })
    schemasElement.addEventListener('change', function () {
      while (tablesElement.firstChild) {
        tablesElement.removeChild(tablesElement.firstChild)
      }
      const schemaName = schemasElement.value
      const schema = window.metadata.schemas[schemaName]
      const tableNames = Object.keys(schema.tables)
      tableNames.forEach(function (tableName) {
        const optionElement = document.createElement('option')
        optionElement.value = tableName
        optionElement.innerText = tableName
        tablesElement.appendChild(optionElement)
      })
    })
  }
  tablesElement.addEventListener('change', function () {
    while (columnsElement.firstChild) {
      columnsElement.removeChild(columnsElement.firstChild)
    }
    while (indexesElement.firstChild) {
      indexesElement.removeChild(indexesElement.firstChild)
    }
    const schemaName = schemaNames.length === 1 ? schemaNames[0] : schemasElement.value
    const tableName = tablesElement.value
    const table = window.metadata.schemas[schemaName].tables[tableName]

    const columnEntries = Object.entries(table.columns)
    if (columnEntries.length > 0) {
      const columns = Object.keys(columnEntries[0][1])
      const rows = []
      for (const [, column] of columnEntries) {
        const row = []
        for (const [, value] of Object.entries(column)) {
          row.push(value)
        }
        rows.push(row)
      }
      createTable(columnsElement, columns, rows)
    }

    const indexEntries = Object.entries(table.indexes)
    if (indexEntries.length > 0) {
      const firstIndex = indexEntries[0][1]
      const indexColumns = Object.keys(firstIndex)
      const indexColumnKeys = Object.keys(firstIndex[indexColumns[0]])
      const columns = indexColumnKeys

      const rows = []
      for (const [, index] of indexEntries) {
        for (const [, column] of Object.entries(index)) {
          const row = []
          for (const [, value] of Object.entries(column)) {
            row.push(value)
          }
          rows.push(row)
        }
      }
      createTable(indexesElement, columns, rows)
    }
  })
  window.structureLoaded = true
}

function createTable (parent, columns, rows) {
  const tableElement = document.createElement('table')
  const theadElement = document.createElement('thead')
  const headerTrElement = document.createElement('tr')
  const tbodyElement = document.createElement('tbody')
  theadElement.appendChild(headerTrElement)
  tableElement.appendChild(theadElement)
  tableElement.appendChild(tbodyElement)
  parent.appendChild(tableElement)

  columns.forEach(function (columnName) {
    const headerElement = document.createElement('th')
    headerElement.classList.add('cell')
    headerElement.innerText = columnName
    headerTrElement.appendChild(headerElement)
  })
  if (columns.length > 0) {
    headerTrElement.appendChild(document.createElement('th'))
  }
  let highlight = false
  rows.forEach(function (row) {
    const rowElement = document.createElement('tr')
    if (highlight) {
      rowElement.classList.add('highlighted-row')
    }
    highlight = !highlight
    tbodyElement.appendChild(rowElement)
    row.forEach(function (value) {
      const cellElement = document.createElement('td')
      cellElement.classList.add('cell')
      cellElement.innerText = value
      rowElement.appendChild(cellElement)
    })
    rowElement.appendChild(document.createElement('td'))
  })
}

function selectGraphTab (internal) {
  document.getElementById('query-box').style.display = 'flex'
  document.getElementById('submit-box').style.display = 'flex'
  document.getElementById('graph-box').style.display = 'flex'
  document.getElementById('graph-status').style.display = 'flex'
  document.getElementById('fetch-sql-box').style.display = 'none'
  document.getElementById('cancel-button').style.display = 'none'
  maybeFetchResult(internal)

  const selection = getSelection()
  focus()
  setSelection(selection)
}

function selectResultTab (internal) {
  document.getElementById('query-box').style.display = 'flex'
  document.getElementById('submit-box').style.display = 'flex'
  document.getElementById('result-box').style.display = 'flex'
  document.getElementById('result-status').style.display = 'flex'
  document.getElementById('fetch-sql-box').style.display = 'none'
  document.getElementById('cancel-button').style.display = 'none'
  const selection = getSelection()
  focus()
  setSelection(selection)
  maybeFetchResult(internal)
}

function selectSavedTab () {
  Array.prototype.forEach.call(document.getElementsByClassName('saved-element'), function (selected) {
    selected.style.display = 'flex'
  })

  if (window.savedLoaded) {
    return
  }

  const savedElement = document.getElementById('saved-box')
  if (savedElement.children.length > 0) {
    return
  }
  const saved = window.metadata.saved
  const numFiles = Object.keys(saved).length
  setSavedStatus(`${numFiles} file${numFiles === 1 ? '' : 's'}`)
  Object.values(saved).forEach(file => {
    const viewUrl = new URL(window.location.origin + window.location.pathname)
    setTabInUrl(viewUrl, 'query')
    viewUrl.searchParams.set('file', file.filename)

    const viewLinkElement = document.createElement('a')
    viewLinkElement.classList.add('view-link')
    viewLinkElement.innerText = 'view'
    viewLinkElement.href = viewUrl.pathname + viewUrl.search
    viewLinkElement.addEventListener('click', function (event) {
      clearResult()
      route(event.target, event, viewUrl, true)
    })

    const runUrl = new URL(window.location.origin + window.location.pathname)
    setTabInUrl(runUrl, 'query')
    runUrl.searchParams.set('file', file.filename)
    runUrl.searchParams.set('run', 'true')

    const runLinkElement = document.createElement('a')
    runLinkElement.classList.add('run-link')
    runLinkElement.innerText = 'run'
    runLinkElement.href = runUrl.pathname + runUrl.search
    runLinkElement.addEventListener('click', function (event) {
      clearResult()
      route(event.target, event, runUrl, true)
    })

    const nameElement = document.createElement('h2')
    nameElement.innerText = file.filename

    const nameAndLinksElement = document.createElement('div')
    nameAndLinksElement.classList.add('name-and-links')
    nameAndLinksElement.appendChild(nameElement)
    nameAndLinksElement.appendChild(viewLinkElement)
    nameAndLinksElement.appendChild(runLinkElement)

    const descriptionElement = document.createElement('p')
    descriptionElement.innerText = file.description

    const divElement = document.createElement('div')
    divElement.classList.add('saved-list-item')
    divElement.appendChild(nameAndLinksElement)
    divElement.appendChild(descriptionElement)

    savedElement.appendChild(divElement)
  })
  window.savedLoaded = true
}

function submitAll (target, event) {
  submit(target, event)
}

function submitCurrent (target, event) {
  submit(target, event, getSelection())
}

function submit (target, event, selection = null) {
  clearResult()
  const url = new URL(window.location)
  let sql = getValue().trim()
  sql = sql === '' ? null : sql

  url.searchParams.set('run', 'true')

  if (url.searchParams.has('file')) {
    if (window.metadata.saved[url.searchParams.get('file')].contents !== getValue()) {
      url.searchParams.delete('file')
      url.searchParams.set('sql', sql)
    }
  } else {
    let sqlParam = url.searchParams.get('sql')?.trim()
    sqlParam = sqlParam === '' ? null : sqlParam

    if (sqlParam !== sql && sql === null) {
      url.searchParams.delete('sql')
    } else if (sqlParam !== sql) {
      url.searchParams.set('sql', sql)
    }
  }

  if (sql) {
    if (selection) {
      url.searchParams.set('selection', selection)
    } else {
      url.searchParams.delete('selection')
    }
  } else {
    url.searchParams.delete('selection')
    url.searchParams.delete('sql')
    url.searchParams.delete('file')
    url.searchParams.delete('run')
  }

  route(target, event, url, true)
}

function clearResult () {
  if (window.sqlFetch?.state === 'pending' || window.sqlFetch?.spinner === 'always') {
    window.sqlFetch.state = 'aborted'
    window.sqlFetch.spinner = 'never'
    window.sqlFetch.fetchController.abort()
    displaySqlFetch(window.sqlFetch)
    return
  }
  window.sqlFetch = null
  clearSpinner()
  clearGraphBox()
  clearGraphStatus()
  clearResultBox()
  clearResultStatus()
}

function clearResultStatus () {
  document.getElementById('result-status').innerText = ''
}

function clearGraphStatus () {
  document.getElementById('graph-status').innerText = ''
}

function clearResultBox () {
  const resultElement = document.getElementById('result-box')
  while (resultElement.firstChild) {
    resultElement.removeChild(resultElement.firstChild)
  }
}

function clearGraphBox () {
  const graphElement = document.getElementById('graph-box')
  while (graphElement.firstChild) {
    graphElement.removeChild(graphElement.firstChild)
  }
}

function updateResultTime (sqlFetch) {
  if (window.sqlFetch === sqlFetch) {
    if (sqlFetch.state === 'pending' || sqlFetch.spinner === 'always') {
      displaySqlFetch(sqlFetch)
      setTimeout(() => { updateResultTime(sqlFetch) }, 500)
    }
  }
}

function fetchSql (sqlFetch) {
  window.sqlFetch = sqlFetch
  updateResultTime(sqlFetch)
  setTimeout(function () {
    if (window.sqlFetch === sqlFetch && sqlFetch.state === 'pending') {
      window.sqlFetch.spinner = 'always'
      displaySqlFetch(sqlFetch)
      setTimeout(function () {
        if (window.sqlFetch === sqlFetch) {
          window.sqlFetch.spinner = 'if_pending'
          displaySqlFetch(sqlFetch)
        }
      }, 400) // If we display a spinner, ensure it is displayed for at least 400 ms
    }
  }, 300) // Don't display the spinner unless the response takes more than 300 ms
  fetch('query', {
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json'
    },
    method: 'POST',
    body: JSON.stringify({
      sql: sqlFetch.sql,
      selection: sqlFetch.selection,
      variables: sqlFetch.variables
    }),
    signal: sqlFetch.fetchController.signal
  })
    .then((response) => {
      const contentType = response.headers.get('content-type')
      if (contentType && contentType.indexOf('application/json') !== -1) {
        response.json().then((result) => {
          if (result?.query) {
            sqlFetch.state = 'success'
            sqlFetch.result = result
          } else {
            sqlFetch.state = 'error'
            if (result?.error) {
              sqlFetch.error_message = result.error
              sqlFetch.error_details = result.stacktrace
            } else if (result) {
              sqlFetch.error_message = 'failed to execute query'
              sqlFetch.error_details = result.toString()
            } else {
              sqlFetch.error_message = 'failed to execute query'
            }
          }
          displaySqlFetch(sqlFetch)
        })
      } else {
        response.text().then((result) => {
          sqlFetch.state = 'error'
          sqlFetch.error_message = 'failed to execute query'
          sqlFetch.error_details = result
          displaySqlFetch(sqlFetch)
        })
      }
    })
    .catch(function (error) {
      if (sqlFetch.state === 'pending') {
        sqlFetch.state = 'error'
        sqlFetch.error_message = 'failed to execute query'
        sqlFetch.error_details = error
      }
      displaySqlFetch(sqlFetch)
    })
}

function parseSqlVariables (params) {
  return Object.fromEntries(
    Array.from(params).filter(([key]) => {
      return key.match(/^_.+/)
    }).map(([key, value]) => {
      return [key.replace(/^_/, ''), value]
    })
  )
}

function maybeFetchResult (internal) {
  const url = new URL(window.location)
  const params = url.searchParams
  const sql = params.get('sql')
  const file = params.get('file')
  const selection = params.get('selection')
  const hasSqluiReferrer = document.referrer && new URL(document.referrer).origin === url.origin
  const variables = parseSqlVariables(params)

  // Only allow auto-run if coming from another SQLUI page. The idea here is to let the app link to URLs with run=true
  // but not other apps. This allows meta/shift-clicking to run a query.
  let run = false
  if (params.has('run')) {
    run = (internal || hasSqluiReferrer) && ['1', 'true'].includes(params.get('run')?.toLowerCase())
    url.searchParams.delete('run')
    window.history.replaceState({}, '', url)
  }

  if (params.has('file') && params.has('sql')) {
    // TODO: show an error.
    throw new Error('You can only specify a file or sql, not both.')
  }

  const existingRequest = window.sqlFetch
  if (existingRequest) {
    const selectionMatches = selection === existingRequest.selection
    const sqlMatches = params.has('sql') && sql === existingRequest.sql
    const fileMatches = params.has('file') && file === existingRequest.file
    const variablesMatch = JSON.stringify(variables) === JSON.stringify(existingRequest.variables)
    const queryMatches = sqlMatches || fileMatches
    if (selectionMatches && queryMatches && variablesMatch) {
      displaySqlFetch(existingRequest)
      if (params.has('selection')) {
        focus()
        setSelection(selection)
      }
      return
    }
  }

  clearResult()

  const sqlFetch = buildSqlFetch(sql, file, variables, selection)
  if (params.has('sql') || params.has('file')) {
    setValue(sqlFetch.sql)
    if (run) {
      fetchSql(sqlFetch)
    }
  }
  if (params.has('selection')) {
    focus()
    setSelection(selection)
  }
}

function buildSqlFetch (sql, file, variables, selection) {
  const sqlFetch = {
    fetchController: new AbortController(),
    state: 'pending',
    startedAt: window.performance.now(),
    spinner: 'never',
    finished: null,
    sql,
    file,
    selection,
    variables
  }

  if (file) {
    const fileDetails = window.metadata.saved[file]
    if (!fileDetails) {
      throw new Error(`no such file: ${file}`)
    }
    sqlFetch.file = file
    sqlFetch.sql = fileDetails.contents
  } else if (sql) {
    sqlFetch.sql = sql
  }

  return sqlFetch
}

function displaySqlFetchInResultTab (fetch) {
  if (fetch.state === 'pending' || fetch.spinner === 'always') {
    clearResultBox()
    if (fetch.spinner === 'never') {
      document.getElementById('result-box').style.display = 'flex'
      clearSpinner()
    } else {
      document.getElementById('result-box').style.display = 'none'
      displaySpinner(fetch)
    }
    return
  }

  document.getElementById('cancel-button').style.display = 'none'
  document.getElementById('fetch-sql-box').style.display = 'none'
  document.getElementById('result-box').style.display = 'flex'

  if (fetch.state === 'aborted') {
    clearResultBox()
    document.getElementById('result-status').innerText = 'query cancelled'
    return
  }

  if (fetch.state === 'error') {
    clearResultBox()
    displaySqlFetchError('result-status', fetch.error_message, fetch.error_details)
    return
  }

  if (fetch.state !== 'success') {
    throw new Error(`unexpected fetch sql request status: ${fetch.status}`)
  }

  if (document.getElementById('result-table')) {
    // Results already displayed.
    return
  }

  clearResultBox()
  displaySqlFetchResultStatus('result-status', fetch)

  const tableElement = document.createElement('table')
  tableElement.id = 'result-table'
  const theadElement = document.createElement('thead')
  const headerElement = document.createElement('tr')
  const tbodyElement = document.createElement('tbody')
  theadElement.appendChild(headerElement)
  tableElement.appendChild(theadElement)
  tableElement.appendChild(tbodyElement)
  document.getElementById('result-box').appendChild(tableElement)

  fetch.result.columns.forEach(column => {
    const template = document.createElement('template')
    template.innerHTML = `<th class="cell">${column}</th>`
    headerElement.appendChild(template.content.firstChild)
  })
  if (fetch.result.columns.length > 0) {
    headerElement.appendChild(document.createElement('th'))
  }
  let highlight = false
  fetch.result.rows.forEach(function (row) {
    const rowElement = document.createElement('tr')
    if (highlight) {
      rowElement.classList.add('highlighted-row')
    }
    highlight = !highlight
    tbodyElement.appendChild(rowElement)
    row.forEach(function (value) {
      const template = document.createElement('template')
      template.innerHTML = `<td class="cell">${value}</td>`
      rowElement.appendChild(template.content.firstChild)
    })
    rowElement.appendChild(document.createElement('td'))
  })
}

function displaySqlFetch (fetch) {
  if (window.tab === 'query') {
    displaySqlFetchInResultTab(fetch)
  } else if (window.tab === 'graph') {
    displaySqlFetchInGraphTab(fetch)
  }
}

function displaySqlFetchError (statusElementId, message, details) {
  const statusElement = document.getElementById(statusElementId)
  if (details) {
    console.log(`${message}\n${details}`)
    statusElement.innerText = `error: ${message} (check console)`
  } else {
    statusElement.innerText = `error: ${message}`
  }
}

function clearSpinner () {
  document.getElementById('cancel-button').style.display = 'none'
  document.getElementById('fetch-sql-box').style.display = 'none'
}

function displaySpinner (fetch) {
  document.getElementById('cancel-button').style.display = 'flex'
  document.getElementById('fetch-sql-box').style.display = 'flex'

  const elapsed = window.performance.now() - fetch.startedAt
  const seconds = Math.floor((elapsed / 1000) % 60)
  const minutes = Math.floor((elapsed / 1000 / 60) % 60)
  let display = `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`
  if (elapsed >= 1000 * 60 * 60) {
    const hours = Math.floor((elapsed / 1000 / 60 / 60) % 24)
    display = `${hours.toString().padStart(2, '0')}:${display}`
    if (elapsed >= 1000 * 60 * 60 * 24) {
      const days = Math.floor(elapsed / 1000 / 60 / 60 / 24)
      if (days === 1) {
        display = `${days} day ${display}`
      } else {
        display = `${days.toLocaleString()} days ${display}`
      }
    }
  }
  document.getElementById('result-time').innerText = display
}

function displaySqlFetchInGraphTab (fetch) {
  if (fetch.state === 'pending' || fetch.spinner === 'always') {
    clearGraphBox()
    if (fetch.spinner === 'never') {
      document.getElementById('graph-box').style.display = 'flex'
      clearSpinner()
    } else {
      document.getElementById('graph-box').style.display = 'none'
      displaySpinner(fetch)
    }
    return
  }

  document.getElementById('cancel-button').style.display = 'none'
  document.getElementById('fetch-sql-box').style.display = 'none'
  document.getElementById('graph-box').style.display = 'flex'

  if (fetch.state === 'aborted') {
    clearGraphBox()
    document.getElementById('graph-status').innerText = 'query cancelled'
    return
  }

  if (fetch.state === 'error') {
    clearGraphBox()
    displaySqlFetchError('graph-status', fetch.error_message, fetch.error_details)
    return
  }

  if (fetch.state !== 'success') {
    throw new Error(`unexpected fetch sql request status: ${fetch.status}`)
  }
  clearGraphBox()
  displaySqlFetchResultStatus('graph-status', fetch)

  if (!fetch.result.rows) {
    return
  }
  if (fetch.result.rows.length === 0 || fetch.result.columns.length < 2) {
    return
  }
  const dataTable = new google.visualization.DataTable()
  fetch.result.columns.forEach((column, index) => {
    dataTable.addColumn(fetch.result.column_types[index], column)
  })

  fetch.result.rows.forEach((row) => {
    const rowValues = row.map((value, index) => {
      if (fetch.result.column_types[index] === 'date' || fetch.result.column_types[index] === 'datetime') {
        return new Date(value)
      } else if (fetch.result.column_types[index] === 'timeofday') {
        // TODO: This should be hour, minute, second, milliseconds
        return [0, 0, 0, 0]
      } else {
        return value
      }
    })
    dataTable.addRow(rowValues)
  })

  const chart = new google.visualization.LineChart(document.getElementById('graph-box'))
  const options = {
    hAxis: {
      title: fetch.result.columns[0]
    },
    vAxis: {
      title: fetch.result.columns[1]
    }
  }
  chart.draw(dataTable, options)
}

function displaySqlFetchResultStatus (statusElementId, sqlFetch) {
  const result = sqlFetch.result
  const statusElement = document.getElementById(statusElementId)
  const elapsed = Math.round(100 * (window.performance.now() - sqlFetch.startedAt) / 1000.0) / 100

  if (result.total_rows === 1) {
    statusElement.innerText = `${result.total_rows} row (${elapsed}s)`
  } else {
    statusElement.innerText = `${result.total_rows} rows (${elapsed}s)`
  }

  if (result.total_rows > result.rows.length) {
    statusElement.innerText += ` (truncated to ${result.rows.length})`
  }
}

function setSavedStatus (status) {
  document.getElementById('saved-status').innerText = status
}

window.addEventListener('popstate', function (event) {
  route()
})

window.addEventListener('resize', function (event) {
  if (window.tab === 'graph' && window.sqlFetch.result) {
    clearGraphBox()
    displaySqlFetchInGraphTab(window.sqlFetch)
  }
})

window.onload = function () {
  Promise.all([
    google.charts.load('current', { packages: ['corechart', 'line'] }),
    fetch('metadata', {
      headers: {
        Accept: 'application/json'
      },
      method: 'POST'
    })
  ])
    .then((results) => {
      const response = results[1]
      const contentType = response.headers.get('content-type')
      if (contentType && contentType.indexOf('application/json') !== -1) {
        return response.json().then((result) => {
          if (result.error) {
            let error = `<pre>${result.error}`
            if (result.stacktrace) {
              error += '\n' + result.stacktrace + '</pre>'
            }
            document.getElementById('loading-box').innerHTML = error
          } else if (!result.server) {
            document.getElementById('loading-box').innerHTML = `
                <pre>
                  error loading metadata, response:
                  ${JSON.stringify(result)}
                </pre>
              `
          } else {
            window.metadata = result
            document.getElementById('loading-box').style.display = 'none'
            document.getElementById('main-box').style.display = 'flex'
            document.getElementById('server-name').innerText = window.metadata.server
            document.title = `SQLUI ${window.metadata.server}`
            document.getElementById('header-link').href = result.list_url_path
            const queryElement = document.getElementById('query')

            init(queryElement, submitCurrent, submitAll)
            route()
          }
        })
      } else {
        console.log(response)
        document.getElementById('loading-box').style.display = 'flex'
        document.getElementById('main-box').style.display = 'none'
        document.getElementById('loading-box').innerHTML = `<pre>${response}</pre>`
      }
    })
    .catch(function (error) {
      console.log(error)
      document.getElementById('loading-box').style.display = 'flex'
      document.getElementById('main-box').style.display = 'none'
      document.getElementById('loading-box').innerHTML = `<pre>${error.stack}</pre>`
    })
}
