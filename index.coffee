# TODO: Add all the other functions to index.coffee
path = require('path')

module.exports.WrappedClient = require(path.join(__dirname, 'src', 'WrappedClient'))
module.exports.getLink = require(path.join(__dirname, 'src', 'getLink'))