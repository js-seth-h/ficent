
support_coffee = undefined
if ((support_coffee === undefined) && (typeof process !== "undefined" && process !== null) && ((typeof require !== "undefined" && require !== null ? require.extensions : void 0) != null) && require.extensions['.coffee']) {
  support_coffee = true
}else {
  support_coffee = false
}

if(support_coffee)
  module.exports = require('./lib');
else
  module.exports = require('./lib-js');

