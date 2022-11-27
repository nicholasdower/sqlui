export function createTable (columns, rows, id, cellRenderer) {
  const tableElement = document.createElement('table')
  if (id) tableElement.id = id
  const theadElement = document.createElement('thead')
  const headerTrElement = document.createElement('tr')
  const tbodyElement = document.createElement('tbody')
  theadElement.appendChild(headerTrElement)
  tableElement.appendChild(theadElement)
  tableElement.appendChild(tbodyElement)

  columns.forEach(function (columnName) {
    const headerElement = document.createElement('th')
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
    row.forEach(function (value, i) {
      let cellElement
      if (cellRenderer) {
        cellElement = cellRenderer(columns[i], value)
      } else {
        cellElement = document.createElement('td')
        cellElement.innerText = value
      }
      rowElement.appendChild(cellElement)
    })
    rowElement.appendChild(document.createElement('td'))
  })
  return tableElement
}
