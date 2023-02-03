export function createVerticalResizer (resizerElement, resizableElement, min, max) {
  let dragging = false
  let startY = null
  let startHeight = null

  resizerElement.addEventListener('mousedown', (event) => {
    dragging = true
    event.preventDefault()
    startY = event.clientY
    startHeight = resizableElement.clientHeight
  })

  document.addEventListener('mouseup', (_) => {
    dragging = false
    startY = null
  })

  document.addEventListener('mousemove', (event) => {
    if (!dragging) return

    const y = event.clientY - startY
    const height = Math.min(max, Math.max(min, startHeight + y))
    console.log(`y: ${y}, height: ${height}`)
    resizableElement.style.height = `${height}px`
  })
}
