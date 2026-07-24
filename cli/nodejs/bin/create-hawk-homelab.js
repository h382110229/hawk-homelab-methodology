#!/usr/bin/env node
'use strict';

const { init } = require('../lib/init');

init(process.argv.slice(2)).catch((err) => {
  console.error(err);
  process.exit(1);
});
