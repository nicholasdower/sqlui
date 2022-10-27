import { EditorView, basicSetup } from 'codemirror'
import { defaultKeymap } from '@codemirror/commands'
import { EditorState } from '@codemirror/state'
import { keymap, placeholder } from '@codemirror/view'
import { sql } from '@codemirror/lang-sql'

/* global google */

function init (parent, onSubmit) {
  const fixedHeightEditor = EditorView.theme({
    '.cm-scroller': { height: '200px', overflow: 'auto', resize: 'vertical' }
  })
  window.editorView = new EditorView({
    state: EditorState.create({
      extensions: [
        keymap.of([
          { key: 'Ctrl-Enter', run: onSubmit, preventDefault: true },
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

function getCursor () {
  return window.editorView.state.selection.main.head
}

function setCursor (cursor) {
  window.editorView.dispatch({ selection: { anchor: Math.min(cursor, window.editorView.state.doc.length) } })
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

export function selectTab (tab) {
  window.tab = tab
  const url = new URL(window.location)
  if (url.searchParams.has('tab')) {
    if (url.searchParams.get('tab') !== tab) {
      if (tab === 'query') {
        url.searchParams.delete('tab')
        window.history.pushState({}, '', url)
        return route()
      } else {
        url.searchParams.set('tab', tab)
        window.history.pushState({}, '', url)
        return route()
      }
    }
  } else {
    if (tab !== 'query') {
      url.searchParams.set('tab', tab)
      window.history.pushState({}, '', url)
      return route()
    }
  }

  const tabElement = document.getElementById(`${tab}-tab-button`)
  Array.prototype.forEach.call(document.getElementsByClassName('selected-tab-button'), function (selected) {
    selected.classList.remove('selected-tab-button')
    selected.classList.add('tab-button')
  })
  tabElement.classList.remove('tab-button')
  tabElement.classList.add('selected-tab-button')

  Array.prototype.forEach.call(document.getElementsByClassName('tab-content-element'), function (selected) {
    selected.style.display = 'none'
  })

  switch (tab) {
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
      throw new Error(`Unexpected tab: ${tab}`)
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
  headerTrElement.appendChild(document.createElement('th'))
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
    loadQueryOrGraphTab(loadGraphResult)
  })

  const cursor = getCursor()
  focus()
  setCursor(cursor)
}

function selectQueryTab () {
  Array.prototype.forEach.call(document.getElementsByClassName('query-element'), function (selected) {
    selected.style.display = 'flex'
  })

  const cursor = getCursor()
  focus()
  setCursor(cursor)

  loadQueryOrGraphTab(loadQueryResult)
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
  if (saved && saved.length === 1) {
    setSavedStatus('1 file')
  } else {
    setSavedStatus(`${saved.length} files`)
  }
  saved.forEach(file => {
    const divElement = document.createElement('div')
    divElement.addEventListener('click', function (event) {
      clearResult()
      const url = new URL(window.location)
      url.searchParams.delete('sql')
      url.searchParams.delete('tab')
      url.searchParams.set('file', file.filename)
      window.history.pushState({}, '', url)
      route()
    })
    const nameElement = document.createElement('h1')
    nameElement.innerText = file.filename
    divElement.appendChild(nameElement)

    const descriptionElement = document.createElement('p')
    descriptionElement.innerText = file.description
    divElement.appendChild(descriptionElement)

    savedElement.appendChild(divElement)
  })
  window.savedLoaded = true
}

function submit () {
  const url = new URL(window.location)
  url.searchParams.set('cursor', getCursor())

  let sql = getValue().trim()
  sql = sql === '' ? null : sql

  if (url.searchParams.has('file')) {
    url.searchParams.delete('file')
    url.searchParams.set('sql', sql)
    window.history.pushState({}, '', url)
  } else {
    let sqlParam = url.searchParams.get('sql')?.trim()
    sqlParam = sqlParam === '' ? null : sqlParam

    if (sqlParam !== sql) {
      if (sql === null) {
        url.searchParams.delete('sql')
        window.history.pushState({}, '', url)
      } else {
        url.searchParams.set('sql', sql)
        window.history.pushState({}, '', url)
      }
    } else {
      window.history.replaceState({}, '', url)
    }
  }
  clearResult()
  route()
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

function fetchSql (sql, cursor, callback) {
  fetch('query', {
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json'
    },
    method: 'POST',
    body: JSON.stringify({
      sql,
      cursor
    })
  })
    .then((response) => response.json())
    .then((result) => callback(result))
}

function fetchFile (name, callback) {
  fetch(`query_file?file=${name}`, {
    headers: {
      Accept: 'application/json'
    },
    method: 'GET'
  })
    .then((response) => response.json())
    .then((result) => callback(result))
}

function loadQueryOrGraphTab (callback) {
  const params = new URLSearchParams(window.location.search)
  const sql = params.get('sql')
  const file = params.get('file')
  const cursor = params.has('cursor') ? params.get('cursor') : 0

  if (params.has('sql') && window.result && sql === window.result.query) {
    callback()
    return
  } else if (params.has('file') && window.result && file === window.result.file) {
    callback()
    return
  }

  if (params.has('file') && params.has('sql') && cursor === window.result.cursor) {
    // TODO: show an error.
    throw new Error('You can only specify a file or sql, not both.')
  }

  clearResult()

  if (params.has('sql')) {
    setValue(sql)
    const cursor = params.has('cursor') ? params.get('cursor') : 0
    fetchSql(params.get('sql'), cursor, function (result) {
      window.result = result
      callback()
    })
  } else if (params.has('file')) {
    setValue('')
    fetchFile(file, function (result) {
      window.result = result
      if (window.result.query) {
        setValue(result.query)
      }
      callback()
    })
  }
  if (params.has('cursor')) {
    focus()
    setCursor(cursor)
  }
}

function loadQueryResult () {
  const resultElement = document.getElementById('result-box')
  if (resultElement.children.length > 0) {
    return
  }

  setQueryStatus(window.result)

  if (!window.result.rows) {
    return
  }

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
  headerElement.appendChild(document.createElement('th'))
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
  if (!result.rows) {
    // TODO use a popup
    console.log('error parsing graph result')
    console.log(JSON.stringify(result, null, 2))
    statusElement.innerText = 'error, check console'
    return
  }

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
  if (!result.rows) {
    // TODO use a popup
    console.log('error parsing query result')
    console.log(JSON.stringify(result, null, 2))
    statusElement.innerText = 'error, check console'
    return
  }

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

function route () {
  selectTab(new URLSearchParams(window.location.search).get('tab') || 'query')
}

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
            document.getElementById('loading-error').innerHTML = `
                <pre>
                  error loading metadata, response:
                  ${JSON.stringify(result)}
                </pre>
              `
          } else {
            window.metadata = result
            document.getElementById('loading-box').style.display = 'none'
            document.getElementById('main-box').style.display = 'flex'
            document.getElementById('header').innerText = result.server
            const queryElement = document.getElementById('query')

            init(queryElement, function () {
              submit()
            })
            route()
          }
        })
      } else {
        console.log(response)
        document.getElementById('loading-error').innerHTML = `
                <pre>
                  error loading metadata, response:
                  ${response}
                </pre>
              `
      }
    })
    .catch(function (error) {
      console.log(error)
      document.getElementById('loading-error').innerHTML = `
                <pre>
                  error loading metadata:
                  ${error.stack}
                </pre>
              `
    })
}
