export function copyTextToClipboard(text) {
  const type = 'text/plain'
  const blob = new Blob([text], { type })
  navigator.clipboard.write([new window.ClipboardItem({ [type]: blob })])
}
