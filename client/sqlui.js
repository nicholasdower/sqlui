import { EditorView } from 'codemirror'

import { base64Encode } from './base64.js'
import { copyTextToClipboard } from './clipboard.js'
import { toCsv, toTsv } from './csv.js'
import { createEditor } from './editor.js'
import { ResizeTable } from './resize-table.js'
import { createPopup } from './popup.js'

/* global google */

const PAGE_SIZE = 100

function getSqlFromUrl (url) {
  const params = url.searchParams
  if (params.has('file') && params.has('sql')) {
    // TODO: show an error.
    throw new Error('You can only specify a file or sql param, not both.')
  }
  if (params.has('sql')) {
    return params.get('sql')
  } else if (params.has('file')) {
    const file = params.get('file')
    const fileDetails = window.metadata.saved[file]
    if (!fileDetails) throw new Error(`no such file: ${file}`)
    return fileDetails.contents
  }
  throw new Error('You must specify a file or sql param')
}

function init (parent, onSubmit, onShiftSubmit) {
  addEventListener('#query-tab-button', 'click', (event) => selectTab(event, 'query'))
  addEventListener('#saved-tab-button', 'click', (event) => selectTab(event, 'saved'))
  addEventListener('#structure-tab-button', 'click', (event) => selectTab(event, 'structure'))
  addEventListener('#graph-tab-button', 'click', (event) => selectTab(event, 'graph'))
  addEventListener('#cancel-button', 'click', () => clearResult())

  addEventListener('#query-box', 'click', () => {
    focus()
  })
  const dropdownContent = document.getElementById('submit-dropdown-content')
  const dropdownButton = document.getElementById('submit-dropdown-button')
  addEventListener(dropdownButton, 'click', () => dropdownContent.classList.toggle('submit-dropdown-content-show'))

  const isMac = navigator.userAgent.includes('Mac')
  const runCurrentLabel = `run selection (${isMac ? '⌘' : 'Ctrl'}-Enter)`
  const runAllLabel = `run all (${isMac ? '⌘' : 'Ctrl'}-Shift-Enter)`

  const submitButtonCurrent = document.getElementById('submit-button-current')
  submitButtonCurrent.value = runCurrentLabel
  addEventListener(submitButtonCurrent, 'click', (event) => submitCurrent(event.target, event))

  const submitButtonAll = document.getElementById('submit-button-all')
  submitButtonAll.value = runAllLabel
  addEventListener(submitButtonAll, 'click', (event) => submitAll(event.target, event))

  const dropdownButtonCurrent = document.getElementById('submit-dropdown-button-current')
  dropdownButtonCurrent.value = runCurrentLabel
  addEventListener(dropdownButtonCurrent, 'click', (event) => submitCurrent(event.target, event))

  const dropdownAllButton = document.getElementById('submit-dropdown-button-all')
  dropdownAllButton.value = runAllLabel
  addEventListener(dropdownAllButton, 'click', (event) => submitAll(event.target, event))

  const dropdownToggleButton = document.getElementById('submit-dropdown-button-toggle')
  addEventListener(dropdownToggleButton, 'click', () => {
    submitButtonCurrent.classList.toggle('submit-button-show')
    submitButtonAll.classList.toggle('submit-button-show')
    focus(getSelection())
  })

  addEventListener('#submit-dropdown-button-copy-csv', 'click', () => {
    if (window.sqlFetch?.result) {
      copyTextToClipboard(toCsv(window.sqlFetch.result.columns, window.sqlFetch.result.rows))
    }
  })
  addEventListener('#submit-dropdown-button-copy-tsv', 'click', () => {
    if (window.sqlFetch?.result) {
      copyTextToClipboard(toTsv(window.sqlFetch.result.columns, window.sqlFetch.result.rows))
    }
  })
  addEventListener('#first-button', 'click', () => {
    window.sqlFetch.page = 0
    displaySqlFetch(window.sqlFetch)
  })
  addEventListener('#prev-button', 'click', () => {
    window.sqlFetch.page -= 1
    displaySqlFetch(window.sqlFetch)
  })
  document.querySelectorAll('.jump-button').forEach((button) => {
    addEventListener(button, 'click', (event) => {
      const jump = parseInt(event.target.dataset.jump)
      let page = 1 + window.sqlFetch.page
      if (jump < 0) {
        page -= (page % jump) === 0 ? Math.abs(jump) : page % jump
      } else {
        page += jump
        page -= page % jump
      }
      window.sqlFetch.page = Math.max(0, Math.min(window.sqlFetch.pageCount - 1, page - 1))
      displaySqlFetch(window.sqlFetch)
    })
  })
  addEventListener('#next-button', 'click', () => {
    window.sqlFetch.page += 1
    displaySqlFetch(window.sqlFetch)
  })
  addEventListener('#last-button', 'click', () => {
    window.sqlFetch.page = window.sqlFetch.pageCount - 1
    displaySqlFetch(window.sqlFetch)
  })
  addEventListener('#submit-dropdown-button-download-csv', 'click', () => {
    if (!window.sqlFetch?.result) return

    const url = new URL(window.location)
    url.searchParams.set('sql', base64Encode(getSqlFromUrl(url)))
    url.searchParams.delete('file')
    setActionInUrl(url, 'download_csv')

    const link = document.createElement('a')
    link.setAttribute('download', 'result.csv')
    link.setAttribute('href', url.href)
    link.click()

    focus(getSelection())
  })

  addEventListener(document, 'click', (event) => {
    if (event.target !== dropdownButton) {
      dropdownContent.classList.remove('submit-dropdown-content-show')
    }
  })
  addEventListener(dropdownContent, 'focusout', (event) => {
    if (!dropdownContent.contains(event.relatedTarget)) {
      dropdownContent.classList.remove('submit-dropdown-content-show')
    }
  })

  window.editorView = createEditor(parent, window.metadata, onSubmit, onShiftSubmit)
}

function addEventListener (elementOrSelector, type, func) {
  if (typeof elementOrSelector === 'string') {
    document.querySelector(elementOrSelector).addEventListener(type, func)
  } else {
    elementOrSelector.addEventListener(type, func)
  }
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
  window.editorView.dispatch({
    selection: {
      anchor,
      head
    }
  })
}

function focus (selection = null) {
  window.editorView.focus()
  if (selection) setSelection(selection)
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

function setActionInUrl (url, action) {
  url.pathname = url.pathname.replace(/\/[^/]+$/, `/${action}`)
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
  setActionInUrl(url, 'graph')
  document.getElementById('graph-tab-button').href = url.pathname + url.search
  setActionInUrl(url, 'saved')
  document.getElementById('saved-tab-button').href = url.pathname + url.search
  setActionInUrl(url, 'structure')
  document.getElementById('structure-tab-button').href = url.pathname + url.search
  setActionInUrl(url, 'query')
  document.getElementById('query-tab-button').href = url.pathname + url.search
}

function selectTab (event, tab) {
  const url = new URL(window.location)
  setActionInUrl(url, tab)
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

  setStatus('')

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
      while (columnsElement.firstChild) {
        columnsElement.removeChild(columnsElement.firstChild)
      }
      while (indexesElement.firstChild) {
        indexesElement.removeChild(indexesElement.firstChild)
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
      const cellRenderer = function (cellElement, _rowIndex, _columnIndex, value) {
        cellElement.style.textAlign = (typeof value) === 'string' ? 'left' : 'right'
        return document.createTextNode(value)
      }
      columnsElement.appendChild(new ResizeTable(columns, rows, null, cellRenderer))
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
      const cellRenderer = function (cellElement, _rowIndex, _columnIndex, value) {
        cellElement.style.textAlign = (typeof value) === 'string' ? 'left' : 'right'
        return document.createTextNode(value)
      }
      indexesElement.appendChild(new ResizeTable(columns, rows, null, cellRenderer))
    }
  })
  window.structureLoaded = true
}

function selectGraphTab (internal) {
  document.getElementById('query-box').style.display = 'flex'
  document.getElementById('submit-box').style.display = 'flex'
  document.getElementById('graph-box').style.display = 'flex'
  document.getElementById('fetch-sql-box').style.display = 'none'
  document.getElementById('cancel-button').style.display = 'none'
  updateDownloadButtons(window?.sqlFetch)
  maybeFetchResult(internal)

  focus(getSelection())
}

function selectResultTab (internal) {
  document.getElementById('query-box').style.display = 'flex'
  document.getElementById('submit-box').style.display = 'flex'
  document.getElementById('result-box').style.display = 'flex'
  document.getElementById('fetch-sql-box').style.display = 'none'
  document.getElementById('cancel-button').style.display = 'none'
  focus(getSelection())
  maybeFetchResult(internal)
}

function selectSavedTab () {
  Array.prototype.forEach.call(document.getElementsByClassName('saved-element'), function (selected) {
    selected.style.display = 'flex'
  })

  const savedElement = document.getElementById('saved-box')
  const saved = window.metadata.saved
  const numFiles = Object.keys(saved).length
  setStatus(`${numFiles} file${numFiles === 1 ? '' : 's'}`)

  if (savedElement.children.length > 0) {
    return
  }

  Object.values(saved).forEach(file => {
    const viewUrl = new URL(window.location.origin + window.location.pathname)
    setActionInUrl(viewUrl, 'query')
    viewUrl.searchParams.set('file', file.filename)

    const viewLinkElement = document.createElement('a')
    viewLinkElement.classList.add('view-link')
    viewLinkElement.innerText = 'view'
    viewLinkElement.href = viewUrl.pathname + viewUrl.search
    addEventListener(viewLinkElement, 'click', (event) => {
      clearResult()
      route(event.target, event, viewUrl, true)
    })

    const runUrl = new URL(window.location.origin + window.location.pathname)
    setActionInUrl(runUrl, 'query')
    runUrl.searchParams.set('file', file.filename)
    runUrl.searchParams.set('run', 'true')

    const runLinkElement = document.createElement('a')
    runLinkElement.classList.add('run-link')
    runLinkElement.innerText = 'run'
    runLinkElement.href = runUrl.pathname + runUrl.search
    addEventListener(runLinkElement, 'click', (event) => {
      clearResult()
      route(event.target, event, viewUrl, true)
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
}

function submitAll (target, event) {
  submit(target, event)
}

function submitCurrent (target, event) {
  submit(target, event, getSelection())
}

function submit (target, event, selection = null) {
  if (!target || !event) {
    throw new Error('you must specify target and event')
  }
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
    window.sqlFetch.abort()
    displaySqlFetch(window.sqlFetch)
    return
  }
  window.sqlFetch = null
  clearSpinner()
  clearGraphBox()
  clearStatus()
  clearResultBox()
  disableDownloadButtons()
}

function clearStatus () {
  document.getElementById('status-message').innerText = ''
}

function setStatus (message) {
  const element = document.getElementById('status-message')
  element.innerText = message
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
      setTimeout(() => {
        updateResultTime(sqlFetch)
      }, 500)
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
      sqlFetch.endedAt = window.performance.now()
      const contentType = response.headers.get('content-type')
      if (contentType && contentType.indexOf('application/json') !== -1) {
        response.json().then((result) => {
          if (result?.query) {
            sqlFetch.state = 'success'
            sqlFetch.result = result
            sqlFetch.pageCount = Math.ceil(result.rows.length / sqlFetch.pageSize)
          } else {
            sqlFetch.state = 'error'
            if (result?.error) {
              sqlFetch.errorMessage = result.error
              sqlFetch.errorDetails = result.stacktrace
            } else if (result) {
              sqlFetch.errorMessage = 'failed to execute query'
              sqlFetch.errorDetails = result.toString()
            } else {
              sqlFetch.errorMessage = 'failed to execute query'
            }
          }
          displaySqlFetch(sqlFetch)
        }).catch(function (error) {
          setSqlFetchError(sqlFetch, error)
          displaySqlFetch(sqlFetch)
        })
      } else {
        response.text().then((result) => {
          sqlFetch.state = 'error'
          sqlFetch.errorMessage = 'failed to execute query'
          sqlFetch.errorDetails = result
          displaySqlFetch(sqlFetch)
        }).catch(function (error) {
          setSqlFetchError(sqlFetch, error)
          displaySqlFetch(sqlFetch)
        })
      }
    })
    .catch(function (error) {
      setSqlFetchError(sqlFetch, error)
      displaySqlFetch(sqlFetch)
    })
}

function setSqlFetchError (sqlFetch, error) {
  // Ignore the error unless pending since the error may be the result of aborting.
  if (sqlFetch.state === 'pending') {
    sqlFetch.endedAt = window.performance.now()
    sqlFetch.state = 'error'
    sqlFetch.errorMessage = 'failed to execute query'
    sqlFetch.errorDetails = error
  }
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
        focus(selection)
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
    focus(selection)
  }
}

class SqlFetch {
  constructor (sql, file, variables, selection) {
    this.sql = sql
    this.file = file
    this.variables = variables
    this.selection = selection
    this.startedAt = window.performance.now()
    this.endedAt = null
    this.state = 'pending'
    this.fetchController = new AbortController()
    this.spinner = 'never'
    this.finished = null
    this.page = 0
    this.pageSize = PAGE_SIZE
    this.pageCount = null
  }

  abort () {
    this.state = 'aborted'
    this.endedAt = window.performance.now()
    this.spinner = 'never'
    this.fetchController.abort()
  }

  getDuration () {
    return (this.endedAt || window.performance.now()) - this.startedAt
  }
}
function buildSqlFetch (sql, file, variables, selection) {
  const sqlFetch = new SqlFetch(sql, file, variables, selection)

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

const createCellLink = function (link, value) {
  const linkElement = document.createElement('a')
  linkElement.href = link.template.replaceAll('{*}', encodeURIComponent(value))
  linkElement.innerText = link.short_name
  linkElement.target = '_blank'

  const abbrElement = document.createElement('abbr')
  abbrElement.title = link.long_name
  abbrElement.appendChild(linkElement)

  return abbrElement
}

const resultCellRenderer = function (cellElement, rowIndex, columnIndex, value) {
  const column = window.sqlFetch.result.columns[columnIndex]
  const columnType = window.sqlFetch.result.column_types[columnIndex]

  cellElement.dataset.column = columnIndex.toString()
  cellElement.dataset.row = rowIndex.toString()

  if (typeof value === 'string' && value.indexOf('\n') >= 0) {
    value = value.replaceAll('\n', '¶')
  }

  if (value && window.metadata.columns[column]?.links?.length > 0) {
    const linksElement = document.createElement('div')
    window.metadata.columns[column].links.forEach((link) => {
      linksElement.appendChild(createCellLink(link, value))
    })

    const textElement = document.createElement('div')
    textElement.classList.add('cell-value')
    textElement.style.textAlign = columnType === 'string' ? 'left' : 'right'
    textElement.innerText = value

    const wrapperElement = document.createElement('div')
    wrapperElement.classList.add('cell-content-wrapper')
    wrapperElement.appendChild(linksElement)
    wrapperElement.appendChild(textElement)

    return wrapperElement
  } else {
    cellElement.style.textAlign = columnType === 'string' ? 'left' : 'right'
    return document.createTextNode(value)
  }
}

function resultHeaderRenderer (headerElement, columnIndex, value) {
  headerElement.dataset.column = columnIndex.toString()

  if (typeof value === 'string' && value.indexOf('\n') >= 0) {
    value = value.replaceAll('\n', '¶')
  }
  return document.createTextNode(value)
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
    setStatus('query cancelled')
    return
  }

  if (fetch.state === 'error') {
    clearResultBox()
    displaySqlFetchError(fetch.errorMessage, fetch.errorDetails)
    return
  }

  if (fetch.state !== 'success') {
    throw new Error(`unexpected fetch sql request status: ${fetch.status}`)
  }

  displaySqlFetchResultStatus(fetch)

  const pageStart = fetch.page * fetch.pageSize
  const rows = fetch.result.rows.slice(pageStart, pageStart + fetch.pageSize)

  let tableElement = document.getElementById('result-table')
  if (tableElement) {
    const resultBody = tableElement.getTableBody()
    if (resultBody.dataset.page === fetch.page) {
      // Results already displayed.
      return
    }
    tableElement.updateTableBody(rows, resultCellRenderer)
  } else {
    clearResultBox()
    const resultBoxElement = document.getElementById('result-box')
    tableElement = new ResizeTable(fetch.result.columns, rows, resultHeaderRenderer, resultCellRenderer)
    tableElement.id = 'result-table'
    registerTableCellPopup(tableElement)
    resultBoxElement.appendChild(tableElement)
  }
  tableElement.setAttribute('data-page', fetch.page)
}

function registerTableCellPopup (tableElement) {
  const listener = (event) => {
    if (event.which === 1 && event.detail === 2) {
      let node = event.target
      while (!['td', 'th', 'table'].includes(node.tagName.toLowerCase()) && node.parentNode) {
        node = node.parentNode
      }
      if (node.tagName.toLowerCase() === 'td') {
        if (event.type === 'mousedown') {
          const row = parseInt(node.dataset.row)
          const column = parseInt(node.dataset.column)
          const title = window.sqlFetch.result.columns[column].replaceAll('\n', '¶')
          createPopup(title, window.sqlFetch.result.rows[row][column])
        }
        event.preventDefault()
      } else if (node.tagName.toLowerCase() === 'th') {
        if (event.type === 'mousedown') {
          const column = parseInt(node.dataset.column)
          const value = window.sqlFetch.result.columns[column]
          const title = value.replaceAll('\n', '¶')
          createPopup(title, value)
        }
        event.preventDefault()
      }
    }
  }
  // We only open the popup on mouseup but we need to preventDefault on mousedown to avoid the clicked text from
  // being highlighted.
  addEventListener(tableElement, 'mouseup', listener)
  addEventListener(tableElement, 'mousedown', listener)
}
function disableDownloadButtons () {
  document.getElementById('submit-dropdown-button-download-csv').classList.add('disabled')
  document.getElementById('submit-dropdown-button-copy-csv').classList.add('disabled')
  document.getElementById('submit-dropdown-button-copy-tsv').classList.add('disabled')
}

function enableDownloadButtons () {
  document.getElementById('submit-dropdown-button-download-csv').classList.remove('disabled')
  document.getElementById('submit-dropdown-button-copy-csv').classList.remove('disabled')
  document.getElementById('submit-dropdown-button-copy-tsv').classList.remove('disabled')
}

function updateDownloadButtons (fetch) {
  if (fetch?.state === 'success') {
    enableDownloadButtons()
  } else {
    disableDownloadButtons()
  }
}

function displaySqlFetch (fetch) {
  updateDownloadButtons(fetch)
  if (window.tab === 'query') {
    displaySqlFetchInResultTab(fetch)
  } else if (window.tab === 'graph') {
    displaySqlFetchInGraphTab(fetch)
  }
}

function displaySqlFetchError (message, details) {
  if (details) {
    console.log(details)
  }
  setStatus(message)
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
    setStatus('query cancelled')
    return
  }

  if (fetch.state === 'error') {
    clearGraphBox()
    displaySqlFetchError(fetch.errorMessage, fetch.errorDetails)
    return
  }

  if (fetch.state !== 'success') {
    throw new Error(`unexpected fetch sql request status: ${fetch.status}`)
  }
  clearGraphBox()
  displaySqlFetchResultStatus(fetch)

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

function displaySqlFetchResultStatus (sqlFetch) {
  const result = sqlFetch.result
  const elapsed = Math.round(100 * (sqlFetch.getDuration() / 1000.0)) / 100

  let message
  if (result.rows.length === 1) {
    message = `1 row returned after ${elapsed}s`
  } else {
    message = `${result.rows.length.toLocaleString()} rows returned after ${elapsed}s`
  }

  if (result.total_rows > result.rows.length) {
    message += ` (truncated from ${result.total_rows.toLocaleString()})`
  }
  setStatus(message)

  const pageCountBox = document.getElementById('page-count-box')
  pageCountBox.style.display = 'flex'
  pageCountBox.innerText = `${sqlFetch.page + 1} of ${sqlFetch.pageCount}`
  if (sqlFetch.pageCount > 1) {
    document.getElementById('pagination-box').style.display = 'flex'
    document.getElementById('next-button').disabled = sqlFetch.page + 1 === sqlFetch.pageCount
    document.getElementById('prev-button').disabled = sqlFetch.page === 0
  }

  if (sqlFetch.pageCount > 2) {
    document.getElementById('first-button').style.display = 'flex'
    document.getElementById('last-button').style.display = 'flex'
    document.getElementById('first-button').disabled = sqlFetch.page === 0
    document.getElementById('last-button').disabled = sqlFetch.page === sqlFetch.pageCount - 1
  } else {
    document.getElementById('last-button').style.display = 'none'
    document.getElementById('first-button').style.display = 'none'
  }

  document.querySelectorAll('.jump-button').forEach((button) => {
    const jump = parseInt(button.dataset.jump)
    if (jump < 0) {
      button.disabled = sqlFetch.page === 0
    } else {
      button.disabled = sqlFetch.page === sqlFetch.pageCount - 1
    }
    const min = button.dataset.min ? parseInt(button.dataset.min) : 0
    const max = button.dataset.max ? parseInt(button.dataset.max) : Infinity
    button.style.display = sqlFetch.pageCount >= min && sqlFetch.pageCount <= max ? '' : 'none'
  })
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
            let error = '<div style="font-family: monospace; font-size: 16px;">\n'
            error += `<div>${result.error}</div>\n`
            if (result.stacktrace) {
              error += '<pre>\n' + result.stacktrace + '\n</pre>\n'
            }
            error += '</div>\n'
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
