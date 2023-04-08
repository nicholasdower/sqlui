export function createVerticalResizer (resizerElement, resizableElement, min, max) {
  let startY = null
  let startHeight = null

  const moveListener = (event) => {
    const y = event.clientY - startY
    const height = Math.min(max, Math.max(min, startHeight + y))
    resizableElement.style.height = `${height}px`
  }

  resizerElement.addEventListener('mousedown', (event) => {
    if (event.button !== 0) return
    event.preventDefault()
    startY = event.clientY
    startHeight = resizableElement.clientHeight
    document.addEventListener('mousemove', moveListener)
  })

  document.addEventListener('mouseup', (_) => {
    startY = null
    document.removeEventListener('mousemove', moveListener)
  })
}
