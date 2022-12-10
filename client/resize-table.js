class Drag {
  tableElement = null
  scrolled = null
  scrollOffset = null
  containerOffset = null
  containerWidth = null
  thElement = null
  colElement = null
  otherColsWidth = null
  lastColElement = null
}

let drag = new Drag()

document.addEventListener('mousedown', (event) => {
  if (!event.target.classList.contains('col-resizer')) return

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
  drag.tableElement = tableElement
  drag.containerWidth = containerElement.clientWidth
  drag.scrollOffset = containerElement.scrollLeft
  drag.scrolled = drag.scrollOffset > 0
  drag.containerOffset = containerElement.offsetLeft
  drag.thElement = thElement
  drag.colElement = tableElement.querySelector(`col[data-col-id=${event.target.dataset.colId}]`)

  const colElements = Array.from(drag.colElement.parentElement.childNodes)
  drag.lastColElement = colElements[colElements.length - 1]
  drag.otherColsWidth = 0
  for (let i = 0; i < colElements.length; i++) {
    if (colElements[i] !== drag.colElement && i !== (colElements.length - 1)) {
      drag.otherColsWidth += colElements[i].getBoundingClientRect().width
    }
    colElements[i].style.width = `${colElements[i].getBoundingClientRect().width}px`
  }
  tableElement.style.tableLayout = 'fixed'
  tableElement.style.width = `${tableElement.getBoundingClientRect().width}px`
})

document.addEventListener('mouseup', (event) => {
  drag = new Drag()
})

document.addEventListener('mousemove', (event) => {
  if (!drag.colElement) return

  const newColumnWidth = Math.max(0, drag.scrollOffset + (event.clientX - drag.containerOffset) - drag.thElement.offsetLeft)
  if (newColumnWidth < drag.colElement.getBoundingClientRect().width && newColumnWidth < 30) return

  drag.colElement.style.width = `${newColumnWidth}px`
  drag.tableElement.columnsWidth = newColumnWidth + drag.otherColsWidth
  let lastColWidth
  if (drag.scrolled) {
    lastColWidth = (drag.scrollOffset + drag.containerWidth) - (drag.tableElement.columnsWidth)
  } else {
    lastColWidth = Math.max(10, drag.containerWidth - (drag.tableElement.columnsWidth))
  }
  drag.lastColElement.style.width = lastColWidth + 'px'
  drag.tableElement.style.width = (drag.otherColsWidth + newColumnWidth + lastColWidth) + 'px'
})

export class ResizeTable extends HTMLTableElement {
  constructor (columns, rows, cellRenderer) {
    super()

    this.columns = columns
    this.cellRenderer = cellRenderer

    this.style.tableLayout = 'auto'
    this.style.width = '100%'

    const colgroupElement = document.createElement('colgroup')
    this.appendChild(colgroupElement)

    const theadElement = document.createElement('thead')
    this.appendChild(theadElement)

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
        colElement.dataset.colId = `col-${index}`
        colgroupElement.appendChild(colElement)
        colElements.push(colElement)

        const resizerElement = document.createElement('div')
        resizerElement.classList.add('col-resizer')
        resizerElement.dataset.colId = colElement.dataset.colId
        contentWrapperElement.appendChild(resizerElement)

        nameElement.innerText = column
      })

      headerTrElement.appendChild(document.createElement('th'))
      const lastColElement = document.createElement('col')
      lastColElement.style.width = '100%'
      colElements.push(lastColElement)

      const containerMutationObserver = new MutationObserver(function (mutationList, observer) {
        if (mutationList.length !== 1) {
          throw new Error(`Expected 1 mutation, found ${mutationList.length}`)
        }
        const mutation = mutationList[0]
        if (this.parentElement) {
          if (this.parentElement !== mutation.target) {
            throw new Error('Unexpected table parent')
          }
          return
        }

        observer.resizeObserver.unobserve(mutation.target)
        observer.resizeObserver = null
        observer.disconnect()
      }.bind(this))

      const tableResizeObserver = new ResizeObserver(function () {
        if (!this.parentElement) {
          this.observingContainer = false
          return
        }
        if (this.observingContainer) {
          return
        }
        this.observingContainer = true

        const containerResizeObserver = new ResizeObserver(function () {
          if (this.style.tableLayout === 'auto') return
          if (this.parentElement.scrollLeft > 0) return
          if (!this.columnsWidth) throw new Error('columnsWidth not set')

          const remainingWidth = Math.max(10, this.parentElement.clientWidth - this.columnsWidth)
          colElements.slice(-1)[0].style.width = `${remainingWidth}px`
          this.style.width = `${this.columnsWidth + remainingWidth}px`
        }.bind(this))
        containerResizeObserver.observe(this.parentElement)

        containerMutationObserver.resizeObserver = containerResizeObserver
        containerMutationObserver.containerElement = this.parentElement
        containerMutationObserver.observe(this.parentElement, { childList: true })
      }.bind(this))
      tableResizeObserver.observe(this)

      colgroupElement.appendChild(lastColElement)

      this.updateTableBody(rows, cellRenderer)
    }
  }

  updateTableBody (rows, cellRenderer) {
    this.style.tableLayout = 'auto'

    if (this.tbodyElement) this.removeChild(this.tbodyElement)
    const tbodyElement = document.createElement('tbody')
    this.appendChild(tbodyElement)
    this.tbodyElement = tbodyElement

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

  getTableBody () {
    return this.tbodyElement
  }
}

customElements.define('resize-table', ResizeTable, { extends: 'table' })
