import styles from './popup.css'
import { copyTextToClipboard } from './clipboard.js'

export function createPopup (title, text) {
  const popupWrapperElement = document.createElement('div')
  popupWrapperElement.id = 'popup-wrapper'
  popupWrapperElement.classList.add(styles['popup-wrapper'])
  document.body.appendChild(popupWrapperElement)

  popupWrapperElement.addEventListener('click', () => {
    document.body.removeChild(popupWrapperElement)
  })

  const popupElement = document.createElement('div')
  popupElement.id = 'popup'
  popupElement.classList.add(styles.popup)
  popupWrapperElement.appendChild(popupElement)

  popupElement.addEventListener('click', (event) => {
    event.stopPropagation()
  })

  const titleElement = document.createElement('div')
  titleElement.classList.add(styles.title)
  titleElement.innerText = title
  popupElement.appendChild(titleElement)

  const contentElement = document.createElement('pre')
  contentElement.classList.add(styles.content)
  contentElement.innerText = text
  popupElement.appendChild(contentElement)

  const buttonBarElement = document.createElement('div')
  buttonBarElement.classList.add(styles['button-bar'])
  popupElement.appendChild(buttonBarElement)

  const copyElement = document.createElement('input')
  copyElement.classList.add(styles.button)
  copyElement.type = 'button'
  copyElement.value = 'Copy'
  buttonBarElement.appendChild(copyElement)

  copyElement.addEventListener('click', (event) => {
    copyTextToClipboard(text)
  })

  const closeElement = document.createElement('input')
  closeElement.id = 'popup-close'
  closeElement.classList.add(styles.button)
  closeElement.type = 'button'
  closeElement.value = 'Close'
  buttonBarElement.appendChild(closeElement)

  closeElement.addEventListener('click', (event) => {
    document.body.removeChild(popupWrapperElement)
  })

  closeElement.focus()
}

document.addEventListener('keydown', (event) => {
  if (event.code === 'Escape') {
    const wrapperElement = document.getElementById('popup-wrapper')
    if (wrapperElement) {
      event.preventDefault()
      document.body.removeChild(wrapperElement)
    }
  } else if (event.code === 'Tab') {
    const wrapperElement = document.getElementById('popup-wrapper')
    if (wrapperElement) {
      event.preventDefault()
      document.getElementById('popup-close').focus()
    }
  }
})
