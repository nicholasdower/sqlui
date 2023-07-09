'use strict';

Object.defineProperty(exports, '__esModule', { value: true });

var pluginNodeResolve = require('@rollup/plugin-node-resolve');
var postcss = require('rollup-plugin-postcss');

var rollup_config = {
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
    pluginNodeResolve.nodeResolve(),
    postcss({
      modules: true,
    })
  ]
};

exports.default = rollup_config;
