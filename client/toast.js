import styles from './toast.css'

export function toast (text) {
  const toastElement = document.createElement('div')
  toastElement.innerText = text
  toastElement.classList.add(styles.toast)
  document.body.appendChild(toastElement)
  toastElement.onanimationend = (e) => {
    if (e.animationName === styles.fadeout) {
      document.body.removeChild(toastElement)
    }
  }
}
