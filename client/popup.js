import styles from './popup.css'

export function createPopup (title, text) {
  const wrapperElement = document.createElement('div')
  wrapperElement.id = 'popup'
  wrapperElement.classList.add(styles['popup-wrapper'])
  document.body.appendChild(wrapperElement)

  const contentElement = document.createElement('div')
  contentElement.classList.add(styles['popup-content'])
  wrapperElement.appendChild(contentElement)

  const closeElement = document.createElement('input')
  closeElement.classList.add(styles['popup-close'])
  closeElement.type = 'button'
  closeElement.value = 'Close'
  contentElement.appendChild(closeElement)

  closeElement.addEventListener('click', (event) => {
    document.body.removeChild(wrapperElement)
  })

  const titleElement = document.createElement('div')
  titleElement.classList.add(styles['popup-title'])
  titleElement.innerText = title
  wrapperElement.appendChild(titleElement)

  const preElement = document.createElement('pre')
  preElement.classList.add(styles['popup-pre'])
  contentElement.appendChild(preElement)
  preElement.innerText = text

  wrapperElement.addEventListener('click', () => {
    document.body.removeChild(wrapperElement)
  })

  contentElement.addEventListener('click', (event) => {
    event.stopPropagation()
  })
}

document.addEventListener('keydown', (event) => {
  if (event.code === 'Escape') {
    const popupWrapperElement = document.getElementById('popup')
    if (popupWrapperElement) {
      document.body.removeChild(popupWrapperElement)
    }
  }
})
