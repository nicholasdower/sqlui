const drag = {
  containerElement: null,
  tableElement: null,
  thElement: null,
  colElement: null,
  otherColWidths: null,
  lastColElement: null
}

document.addEventListener('mousedown', (event) => {
  if (event.target.classList.contains('col-resizer')) {
    event.preventDefault()
    const thElement = event.target.parentElement.parentElement
    if (thElement.tagName.toLowerCase() !== 'th') {
      throw new Error(`expected th element, found: ${thElement}`)
    }
    const trElement = thElement.parentElement
    const theadElement = trElement.parentElement
    drag.tableElement = theadElement.parentElement
    drag.containerElement = drag.tableElement.parentElement
    drag.thElement = thElement
    drag.colElement = document.getElementById(event.target.dataset.colId)

    const colElements = Array.from(drag.colElement.parentElement.childNodes)
    drag.lastColElement = colElements[colElements.length - 1]
    drag.otherColWidths = []
    for (let i = 0; i < colElements.length - 1; i++) {
      if (colElements[i] !== drag.colElement) {
        drag.otherColWidths.push(colElements[i].getBoundingClientRect().width)
      }
    }
    colElements.forEach((element) => {
      element.style.width = `${element.getBoundingClientRect().width}px`
    })
    drag.tableElement.style.tableLayout = 'fixed'
  }
})

document.addEventListener('mouseup', (event) => {
  drag.containerElement = null
  drag.tableElement = null
  drag.thElement = null
  drag.colElement = null
  drag.otherColWidths = null
  drag.lastColElement = null
})

document.addEventListener('mousemove', (event) => {
  if (drag.colElement) {
    const scrollOffset = drag.containerElement.scrollLeft
    const scrolled = scrollOffset > 0
    const containerOffset = drag.containerElement.offsetLeft
    const newColumnWidth = Math.max(0, scrollOffset + (event.clientX - containerOffset) - drag.thElement.offsetLeft)
    if (newColumnWidth < drag.colElement.getBoundingClientRect().width && newColumnWidth < 30) return

    drag.colElement.style.width = `${newColumnWidth}px`
    let runningWidth = newColumnWidth
    drag.otherColWidths.forEach((width) => {
      runningWidth += width
    })
    let remainingWidth
    if (scrolled) {
      remainingWidth = (scrollOffset + drag.containerElement.getBoundingClientRect().width) - runningWidth
    } else {
      remainingWidth = Math.max(10, drag.containerElement.getBoundingClientRect().width - runningWidth)
    }
    drag.lastColElement.style.width = `${remainingWidth}px`
    runningWidth += remainingWidth
    drag.tableElement.style.width = `${runningWidth}px`
  }
})

export function createTable (containerElement, columns, rows, id, cellRenderer) {
  if (!containerElement) throw new Error('missing table containerElement')
  if (!columns) throw new Error('missing table columns')
  if (!rows) throw new Error('missing table rows')
  if (!id) throw new Error('missing table id')

  const tableElement = document.createElement('table')
  if (id) tableElement.id = id

  const colgroupElement = document.createElement('colgroup')
  tableElement.appendChild(colgroupElement)

  const theadElement = document.createElement('thead')
  tableElement.appendChild(theadElement)

  const tbodyElement = document.createElement('tbody')
  tableElement.appendChild(tbodyElement)

  const headerTrElement = document.createElement('tr')
  theadElement.appendChild(headerTrElement)

  const nonLastColElements = []
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
    nonLastColElements.push(colElement)

    const resizerElement = document.createElement('div')
    resizerElement.classList.add('col-resizer')
    resizerElement.dataset.colId = colElement.id
    contentWrapperElement.appendChild(resizerElement)

    nameElement.innerText = column
  })
  if (columns.length > 0) {
    headerTrElement.appendChild(document.createElement('th'))
    const lastColElement = document.createElement('col')
    lastColElement.style.width = '100%'
    function resize () {
      let runningWidth = 0
      const colElements = Array.from(tableElement.getElementsByTagName('col'))
      nonLastColElements.forEach((element, index) => {
        runningWidth += element.getBoundingClientRect().width
      })
      const remainingWidth = Math.max(10, containerElement.getBoundingClientRect().width - runningWidth)
      colElements[colElements.length - 1].style.width = `${remainingWidth}px`
      runningWidth += remainingWidth
      tableElement.style.width = `${runningWidth}px`
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
  }
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
  containerElement.appendChild(tableElement)
}
