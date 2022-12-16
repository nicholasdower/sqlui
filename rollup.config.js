import { nodeResolve } from '@rollup/plugin-node-resolve';
import postcss from 'rollup-plugin-postcss';

export default {
  input: 'client/sqlui.js',
  output: {
    file: 'client/resources/sqlui.js',
    format: 'iife',
    name: 'sqlui',
    globals: {
      google: 'google'
    }
  },
  plugins: [
    nodeResolve(),
    postcss({
      modules: true,
    })
  ]
};
