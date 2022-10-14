import { nodeResolve } from '@rollup/plugin-node-resolve';

export default {
  input: 'src/editor.js',
  output: {
    file: 'build/editor.bundle.js',
    format: 'iife',
    name: 'editor'
  },
  plugins: [nodeResolve()]
};
