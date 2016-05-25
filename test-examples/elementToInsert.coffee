module.exports = {

  f1: () ->
    mixinToInsert3 = require('../test-examples/mixinToInsert3')
    z = 300
    return z
    
  f2: (x) ->
    return x * 2
    
  o2: {a: 'something'}
}