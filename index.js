
if(require.extensions['.coffee'])
  module.exports = require('./lib')
else
  module.exports = require('./lib-js')
