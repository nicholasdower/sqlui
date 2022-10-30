import { EditorView, basicSetup } from 'codemirror'
import { defaultKeymap } from '@codemirror/commands'
import { EditorState } from '@codemirror/state'
import { keymap, placeholder } from '@codemirror/view'
import { sql } from '@codemirror/lang-sql'

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

  const fixedHeightEditor = EditorView.theme({
    '.cm-scroller': { height: '200px', overflow: 'auto', resize: 'vertical' }
  })
  window.editorView = new EditorView({
    state: EditorState.create({
      extensions: [
        keymap.of([
          { key: 'Ctrl-Enter', run: onSubmit, preventDefault: true, shift: onShiftSubmit },
          ...defaultKeymap
        ]),
        basicSetup,
        sql(),
        fixedHeightEditor,
        placeholder('Ctrl-Enter to submit')
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
  route(event.target, event, url)
}

function route (target = null, event = null, url = null) {
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
      selectQueryTab()
      break
    case 'graph':
      selectGraphTab()
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

function selectGraphTab () {
  Array.prototype.forEach.call(document.getElementsByClassName('graph-element'), function (selected) {
    selected.style.display = 'flex'
  })

  google.charts.load('current', { packages: ['corechart', 'line'] })
  google.charts.setOnLoadCallback(function () {
    loadQueryOrGraphTab(loadGraphResult, queryErrorCallback('graph-status'))
  })

  const selection = getSelection()
  focus()
  setSelection(selection)
}

function selectQueryTab () {
  Array.prototype.forEach.call(document.getElementsByClassName('query-element'), function (selected) {
    selected.style.display = 'flex'
  })

  const selection = getSelection()
  focus()
  setSelection(selection)

  loadQueryOrGraphTab(loadQueryResult, queryErrorCallback('query-status'))
}

function queryErrorCallback (statusElementId) {
  const statusElement = document.getElementById(statusElementId)
  return function (message, error) {
    if (error) {
      console.log(`${message}\n${error}`)
      statusElement.innerText = `error: ${message} (check console)`
    } else {
      statusElement.innerText = `error: ${message}`
    }
  }
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
  if (Object.keys(saved).length === 1) {
    setSavedStatus('1 file')
  } else {
    setSavedStatus(`${saved.length} files`)
  }
  Object.values(saved).forEach(file => {
    const divElement = document.createElement('div')
    divElement.classList.add('saved-list-item')
    divElement.addEventListener('click', function (event) {
      clearResult()
      const url = new URL(window.location.origin + window.location.pathname)
      setTabInUrl(url, 'query')
      url.searchParams.set('file', file.filename)
      route(event.target, event, url)
    })
    const nameElement = document.createElement('h2')
    nameElement.innerText = file.filename
    divElement.appendChild(nameElement)

    const descriptionElement = document.createElement('p')
    descriptionElement.innerText = file.description
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
  const url = new URL(window.location)
  let sql = getValue().trim()
  sql = sql === '' ? null : sql

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
  }

  route(target, event, url)
}

function clearResult () {
  clearGraphStatus()
  clearQueryStatus()
  clearGraphBox()
  clearResultBox()
  window.result = null
}

function clearQueryStatus () {
  document.getElementById('query-status').innerText = ''
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

function fetchSql (sql, selection, successCallback, errorCallback) {
  fetch('query', {
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json'
    },
    method: 'POST',
    body: JSON.stringify({
      sql,
      selection
    })
  })
    .then((response) => {
      const contentType = response.headers.get('content-type')
      if (contentType && contentType.indexOf('application/json') !== -1) {
        response.json().then((result) => {
          if (result?.query) {
            successCallback(result)
          } else if (result?.error) {
            errorCallback(result.error, result.stacktrace)
          } else if (result) {
            errorCallback('failed to execute query', result.toString())
          } else {
            errorCallback('failed to execute query')
          }
        })
      } else {
        response.text().then((result) => {
          errorCallback('failed to execute query', result)
        })
      }
    })
    .catch(function (error) {
      errorCallback('failed to execute query', error.stack)
    })
}

function loadQueryOrGraphTab (callback, errorCallback) {
  const params = new URLSearchParams(window.location.search)
  const sql = params.get('sql')
  const file = params.get('file')
  const selection = params.get('selection')
  if (params.has('file') && params.has('sql')) {
    // TODO: show an error.
    throw new Error('You can only specify a file or sql, not both.')
  }
  if (window.result) {
    if ((params.has('sql') && sql === window.result.query) || (params.has('file') && file === window.result.file)) {
      if (selection === window.result.selection) {
        callback()
        if (params.has('selection')) {
          focus()
          setSelection(selection)
        }
        return
      }
    }
  }

  clearResult()

  if (params.has('sql')) {
    setValue(sql)
    fetchSql(params.get('sql'), selection, function (result) {
      window.result = result
      callback()
    }, errorCallback)
  } else if (params.has('file')) {
    const file = window.metadata.saved[params.get('file')]
    if (!file) {
      throw new Error(`no such file: ${params.get('file')}`)
    }
    const fileSql = file.contents
    setValue(fileSql)
    fetchSql(fileSql, selection, function (result) {
      window.result = result
      callback()
    }, errorCallback)
  }
  if (params.has('selection')) {
    focus()
    setSelection(selection)
  }
}

function loadQueryResult () {
  const resultElement = document.getElementById('result-box')
  if (resultElement.children.length > 0) {
    return
  }

  setQueryStatus(window.result)

  // if (!window.result.rows) {
  //   return
  // }

  const tableElement = document.createElement('table')
  const theadElement = document.createElement('thead')
  const headerElement = document.createElement('tr')
  const tbodyElement = document.createElement('tbody')
  theadElement.appendChild(headerElement)
  tableElement.appendChild(theadElement)
  tableElement.appendChild(tbodyElement)
  resultElement.appendChild(tableElement)

  window.result.columns.forEach(column => {
    const template = document.createElement('template')
    template.innerHTML = `<th class="cell">${column}</th>`
    headerElement.appendChild(template.content.firstChild)
  })
  if (window.result.columns.length > 0) {
    headerElement.appendChild(document.createElement('th'))
  }
  let highlight = false
  window.result.rows.forEach(function (row) {
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

  document.getElementById('result-box').style.display = 'flex'
}

function loadGraphResult () {
  setGraphStatus(window.result)

  if (!window.result.rows) {
    return
  }
  if (window.result.rows.length === 0 || window.result.columns.length < 2) {
    return
  }
  const dataTable = new google.visualization.DataTable()
  window.result.columns.forEach((column, index) => {
    dataTable.addColumn(window.result.column_types[index], column)
  })

  window.result.rows.forEach((row) => {
    const rowValues = row.map((value, index) => {
      if (window.result.column_types[index] === 'date' || window.result.column_types[index] === 'datetime') {
        return new Date(value)
      } else if (window.result.column_types[index] === 'timeofday') {
        // TODO: This should be hour, minute, second, milliseconds
        return [0, 0, 0, 0]
      } else {
        return value
      }
    })
    dataTable.addRow(rowValues)
  })

  const graphBoxElement = document.getElementById('graph-box')

  const chart = new google.visualization.LineChart(graphBoxElement)
  const options = {
    hAxis: {
      title: window.result.columns[0]
    },
    vAxis: {
      title: window.result.columns[1]
    }
  }
  chart.draw(dataTable, options)
}

function setGraphStatus (result) {
  const statusElement = document.getElementById('graph-status')

  if (result.total_rows === 1) {
    statusElement.innerText = `${result.total_rows} row`
  } else {
    statusElement.innerText = `${result.total_rows} rows`
  }

  if (result.total_rows > result.rows.length) {
    statusElement.innerText += ` (truncated to ${result.rows.length})`
  }
}

function setQueryStatus (result) {
  const statusElement = document.getElementById('query-status')

  if (result.total_rows === 1) {
    statusElement.innerText = `${result.total_rows} row`
  } else {
    statusElement.innerText = `${result.total_rows} rows`
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
  if (window.tab === 'graph' && window.result) {
    clearGraphBox()
    loadGraphResult()
  }
})

window.onload = function () {
  fetch('metadata', {
    headers: {
      Accept: 'application/json'
    },
    method: 'GET'
  })
    .then((response) => {
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
            document.getElementById('server-name').innerText = result.server
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
