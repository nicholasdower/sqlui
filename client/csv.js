export function toCsv (columns, rows) {
  let text = columns.map((header) => {
    if (typeof header === 'string' && (header.includes('"') || header.includes(','))) {
      return `"${header.replaceAll('"', '""')}"`
    } else {
      return header
    }
  }).join(',') + '\n'
  text += rows.map((row) => {
    return row.map((cell) => {
      if (typeof cell === 'string' && (cell.includes('"') || cell.includes(','))) {
        return `"${cell.replaceAll('"', '""')}"`
      } else {
        return cell
      }
    }).join(',')
  }).join('\n')

  return text
}

export function toTsv (columns, rows) {
  if (columns.find((cell) => cell === '\t')) {
    throw new Error('TSV input may not contain a tab character.')
  }
  let text = columns.join('\t') + '\n'

  text += rows.map((row) => {
    if (row.find((cell) => cell === '\t')) {
      throw new Error('TSV input may not contain a tab character.')
    }
    return row.join('\t')
  }).join('\n')

  return text
}
