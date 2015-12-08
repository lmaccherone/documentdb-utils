module.exports = (memo) ->

  unless memo?
    memo = {}

#  setImmediate = setTimeout = () ->
#    argsArray = []
#    f = arguments[0]
#    ms = arguments[1]
#    for arg, index in arguments
#      if index > 1
#        argsArray.push(arg)
#    f.apply(this, argsArray)

  getAsync = require('../mixins/getAsync')
  async = getAsync()

  async.waterfall([
    (callback) ->
      memo.stepOne = true
      callback(null, 'one')
    (parameter, callback) ->
      memo.waterfall1 = true
      memo.waterfallParameter = parameter
      callback(null, 'two')
  ], (err, result) ->
    if err?
      memo.error = err
      throw new Error(err)
    memo.waterfallEnd = true
    memo.waterfallResult = result
  )

  async.series([
    (callback) ->
      memo.series1 = true
      callback(null, 'one')
    (callback) ->
      memo.series2 = true
      callback(null, 'two')
  ], (err, result) ->
    if err?
      memo.error = err
      throw new Error(err)
    memo.seriesEnd = true
    memo.seriesResult = result
  )

  async.parallel([
    (callback) ->
      memo.parallel1 = true
      callback(null, 'one')
    (callback) ->
      memo.parallel2 = true
      callback(null, 'two')
  ], (err, result) ->
    if err?
      memo.error = err
      throw new Error(err)
    memo.parallelEnd = true
    memo.parallelResult = result
  )

  async.auto({
    one: (callback) ->
      memo.auto1 = true
      callback(null, 'one')
    two: (callback) ->
      memo.auto2 = true
      callback(null, 'two')
    three: ['one', 'two', (callback, results) ->
      memo.auto3 = true
      memo.auto3Results = results
      callback(null, 'three')
    ]
  }, (err, result) ->
    if err?
      memo.error = err
      throw new Error(err)
    memo.autoEnd = true
    memo.autoResult = result
  )
  

  getContext().getResponse().setBody(memo)