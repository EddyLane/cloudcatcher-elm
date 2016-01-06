'use strict';

var buffer = require('./buffer');

function typedBuffer(binString, buffType, type) {
  // buffType is either 'binary' or 'base64'
  var buff = new buffer(binString, buffType);
  buff.type = type; // non-standard, but used for consistency with the browser
  return buff;
}

module.exports = typedBuffer;