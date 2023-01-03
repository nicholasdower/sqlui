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
  closeElement.id = 'popup-close'
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
  preElement.id = 'popup-pre'
  preElement.classList.add(styles['popup-pre'])
  contentElement.appendChild(preElement)
  preElement.innerText = text

  wrapperElement.addEventListener('click', () => {
    document.body.removeChild(wrapperElement)
  })

  contentElement.addEventListener('click', (event) => {
    event.stopPropagation()
  })

  closeElement.focus()
}

document.addEventListener('keydown', (event) => {
  if (event.code === 'Escape') {
    const wrapperElement = document.getElementById('popup')
    if (wrapperElement) {
      event.preventDefault()
      document.body.removeChild(wrapperElement)
    }
  } else if (event.code === 'Tab') {
    const wrapperElement = document.getElementById('popup')
    if (wrapperElement) {
      event.preventDefault()
      document.getElementById('popup-close').focus()
    }
  }
})
