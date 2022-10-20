import { nodeResolve } from '@rollup/plugin-node-resolve';

export default {
  input: 'client/sqlui.js',
  output: {
    file: 'resources/sqlui.js',
    format: 'iife',
    name: 'sqlui'
  },
  plugins: [nodeResolve()]
};
