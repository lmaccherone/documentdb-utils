module.exports = (memo) ->
  getUnderscore = require('../mixins/getUnderscore')
  _ = getUnderscore()

  unless memo?
    memo = {}

  memo.allTestsPass = true


  # TODO: Implement tests from: https://github.com/joonhocho/underscore-node/tree/master/test
  memo.isFalse = _.isEqual(1, 2)
  memo.isTrue = _.isEqual(1, 1)

  getContext().getResponse().setBody(memo)