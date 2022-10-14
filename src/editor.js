import {EditorView, basicSetup} from "codemirror"
import {defaultKeymap} from "@codemirror/commands"
import {EditorState} from "@codemirror/state"
import {keymap, placeholder} from "@codemirror/view"
import {sql} from "@codemirror/lang-sql"

export function init(parent, onSubmit) {
  const fixedHeightEditor = EditorView.theme({
    ".cm-scroller": { height: "200px", overflow: "auto", resize: "vertical" },
  });
  window.editorView = new EditorView({
    state: EditorState.create({
      extensions: [
        keymap.of([
          {key: "Ctrl-Enter", run: onSubmit, preventDefault: true},
          ...defaultKeymap
        ]),
        basicSetup,
        sql(),
        fixedHeightEditor,
        placeholder("Ctrl-Enter to submit")
      ]
    }),
    parent: parent
  })
}

export function getCursor() {
  return window.editorView.state.selection.main.head;
}

export function setCursor(cursor) {
  window.editorView.dispatch({selection: {anchor: Math.min(cursor, window.editorView.state.doc.length)}});
}

export function focus() {
  window.editorView.focus();
}

export function getValue() {
  return window.editorView.state.doc.toString();
}

export function setValue(value) {
  window.editorView.dispatch({
    changes: {
      from: 0,
      to: window.editorView.state.doc.length,
      insert: value
    },
  });
}
