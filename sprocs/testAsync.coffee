module.exports = (memo) ->
  getAsync = require('../mixins/getAsync')
  async = getAsync()

  unless memo?
    memo = {}

  async.waterfall([
    (callback) ->
      memo.stepOne = true
      callback(null, 'one')
    (callback) ->
      memo.stepTwo = true
      callback(null, 'two')
  ], (err, result) ->
    if err?
      memo.error = err
      throw new Error(err)
    memo.gotToEnd = true
  )

  getContext().getResponse().setBody(memo)