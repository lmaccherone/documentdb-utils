f1 = () ->
  mixinToInsert3 = require('../test-examples/mixinToInsert3')
  z = 300
  return z

f2 = (x) ->
  return x * 2

module.exports = {f1, f2}