class Drag {
  scrolled = null
  scrollOffset = null
  containerOffset = null
  containerWidth = null
  thElement = null
  colElement = null
  otherColWidths = null
  lastColElement = null
}

let drag = new Drag()

document.addEventListener('mousedown', (event) => {
  if (event.target.classList.contains('col-resizer')) {
    drag = new Drag()
    event.preventDefault()
    const thElement = event.target.parentElement.parentElement
    if (thElement.tagName.toLowerCase() !== 'th') {
      throw new Error(`expected th element, found: ${thElement}`)
    }
    const trElement = thElement.parentElement
    const theadElement = trElement.parentElement
    const tableElement = theadElement.parentElement
    const containerElement = tableElement.parentElement
    drag.containerWidth = containerElement.clientWidth
    drag.scrollOffset = containerElement.scrollLeft
    drag.scrolled = drag.scrollOffset > 0
    drag.containerOffset = containerElement.offsetLeft
    drag.thElement = thElement
    drag.colElement = document.getElementById(event.target.dataset.colId)

    const colElements = Array.from(drag.colElement.parentElement.childNodes)
    drag.lastColElement = colElements[colElements.length - 1]
    drag.otherColsWidth = 0
    for (let i = 0; i < colElements.length - 1; i++) {
      if (colElements[i] !== drag.colElement) {
        drag.otherColsWidth += colElements[i].getBoundingClientRect().width
      }
      colElements[i].style.width = `${colElements[i].getBoundingClientRect().width}px`
    }
    tableElement.style.tableLayout = 'fixed'
  }
})

document.addEventListener('mouseup', (event) => {
  drag = new Drag()
})

document.addEventListener('mousemove', (event) => {
  if (!drag.colElement) return

  const newColumnWidth = Math.max(0, drag.scrollOffset + (event.clientX - drag.containerOffset) - drag.thElement.offsetLeft)
  if (newColumnWidth < drag.colElement.getBoundingClientRect().width && newColumnWidth < 30) return

  drag.colElement.style.width = `${newColumnWidth}px`
  if (drag.scrolled) {
    drag.lastColElement.style.width = ((drag.scrollOffset + drag.containerWidth) - (newColumnWidth + drag.otherColsWidth)) + 'px'
  } else {
    drag.lastColElement.style.width = (Math.max(10, drag.containerWidth - (newColumnWidth + drag.otherColsWidth))) + 'px'
  }
})

export function createTable (containerElement, columns, rows, id, cellRenderer) {
  if (!containerElement) throw new Error('missing table containerElement')
  if (!columns) throw new Error('missing table columns')
  if (!rows) throw new Error('missing table rows')
  if (!id) throw new Error('missing table id')

  const tableElement = document.createElement('table')
  containerElement.appendChild(tableElement)
  if (id) tableElement.id = id
  tableElement.style.tableLayout = 'auto'

  const colgroupElement = document.createElement('colgroup')
  tableElement.appendChild(colgroupElement)

  const theadElement = document.createElement('thead')
  tableElement.appendChild(theadElement)

  const headerTrElement = document.createElement('tr')
  theadElement.appendChild(headerTrElement)

  if (columns.length > 0) {
    const colElements = []
    columns.forEach(function (column, index) {
      const headerElement = document.createElement('th')
      headerTrElement.appendChild(headerElement)

      const contentWrapperElement = document.createElement('div')
      contentWrapperElement.classList.add('col-content-wrapper')
      headerElement.appendChild(contentWrapperElement)

      const nameElement = document.createElement('div')
      nameElement.classList.add('col-name')
      contentWrapperElement.appendChild(nameElement)

      const colElement = document.createElement('col')
      colElement.id = `${id}-col-${index}`
      colgroupElement.appendChild(colElement)
      colElements.push(colElement)

      const resizerElement = document.createElement('div')
      resizerElement.classList.add('col-resizer')
      resizerElement.dataset.colId = colElement.id
      contentWrapperElement.appendChild(resizerElement)

      nameElement.innerText = column
    })

    headerTrElement.appendChild(document.createElement('th'))
    const lastColElement = document.createElement('col')
    lastColElement.style.width = '100%'
    colElements.push(lastColElement)

    let columnsWidth
    function resize () {
      if (tableElement.style.tableLayout === 'auto') {
        return
      }
      if (!columnsWidth) {
        columnsWidth = 0
        colElements.slice(0, -1).forEach((element, index) => {
          columnsWidth += element.getBoundingClientRect().width
        })
      }
      const remainingWidth = Math.max(10, containerElement.clientWidth - columnsWidth)
      colElements.slice(-1)[0].style.width = `${remainingWidth}px`
      tableElement.style.width = `${columnsWidth + remainingWidth}px`
    }

    const resizeObserver = new ResizeObserver(resize)
    resizeObserver.observe(containerElement)

    const mutationObserver = new MutationObserver((mutationList, observer) => {
      if (!tableElement.parentElement) {
        resizeObserver.unobserve(containerElement)
        resizeObserver.unobserve(containerElement)
        observer.disconnect()
      }
    })
    mutationObserver.observe(containerElement, { childList: true })
    colgroupElement.appendChild(lastColElement)

    setTableBody(rows, tableElement, cellRenderer)
  }

  return tableElement
}

export function getTableBody (tableElement) {
  return tableElement.getElementsByTagName('tbody')[0]
}

export function setTableBody (rows, tableElement, cellRenderer) {
  tableElement.style.tableLayout = 'auto'

  let tbodyElement = getTableBody(tableElement)
  tbodyElement?.parentElement?.removeChild(tbodyElement)

  tbodyElement = document.createElement('tbody')
  tableElement.appendChild(tbodyElement)

  let highlight = false
  rows.forEach(function (row) {
    const rowElement = document.createElement('tr')
    if (highlight) {
      rowElement.classList.add('highlighted-row')
    }
    highlight = !highlight
    tbodyElement.appendChild(rowElement)
    row.forEach(function (value, index) {
      if (cellRenderer) {
        cellRenderer(rowElement, index, value)
      } else {
        const cellElement = document.createElement('td')
        cellElement.innerText = value
        rowElement.appendChild(cellElement)
      }
    })
    rowElement.appendChild(document.createElement('td'))
  })
}
