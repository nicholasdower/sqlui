import styles from './popup.css'
import { copyTextToClipboard } from './clipboard.js'
import { toast } from './toast.js'

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
  popupElement.appendChild(contentElement)

  let renderedText = text
  let clipboardText = text
  let formatted = false
  if (text === null) {
    renderedText = 'null'
    contentElement.style.color = '#888'
    clipboardText = ''
  } else if (typeof text === 'string' && text.match(/^\s*(?:\{.*\}|\[.*\])\s*$/)) {
    try {
      renderedText = JSON.stringify(JSON.parse(text), null, 2)
      clipboardText = renderedText
      formatted = renderedText !== text
    } catch (_) { }
  }
  contentElement.innerText = renderedText

  const buttonBarElement = document.createElement('div')
  buttonBarElement.classList.add(styles['button-bar'])
  popupElement.appendChild(buttonBarElement)

  const copyElement = document.createElement('input')
  copyElement.classList.add(styles.button)
  copyElement.type = 'button'
  copyElement.value = 'Copy'
  buttonBarElement.appendChild(copyElement)

  copyElement.addEventListener('click', (event) => {
    copyTextToClipboard(clipboardText)
    toast('Text copied to clipboard.')
  })

  if (formatted) {
    const copyOriginalElement = document.createElement('input')
    copyOriginalElement.classList.add(styles.button)
    copyOriginalElement.type = 'button'
    copyOriginalElement.value = 'Copy Original'
    buttonBarElement.appendChild(copyOriginalElement)

    copyOriginalElement.addEventListener('click', (event) => {
      copyTextToClipboard(text)
      toast('Text copied to clipboard.')
    })
  }

  const spacerElement = document.createElement('div')
  spacerElement.style.flex = 1
  buttonBarElement.appendChild(spacerElement)

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

export function closePopup () {
  const wrapperElement = document.getElementById('popup-wrapper')
  if (wrapperElement) {
    document.body.removeChild(wrapperElement)
    return true
  }
  return false
}

document.addEventListener('keydown', (event) => {
  if (event.code === 'Escape') {
    if (closePopup()) {
      event.preventDefault()
    }
  } else if (event.code === 'Tab') {
    const wrapperElement = document.getElementById('popup-wrapper')
    if (wrapperElement) {
      event.preventDefault()
      document.getElementById('popup-close').focus()
    }
  }
})
