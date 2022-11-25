export function createTable (document, parent, columns, rows, id) {
  const tableElement = document.createElement('table')
  if (id) tableElement.id = id
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
