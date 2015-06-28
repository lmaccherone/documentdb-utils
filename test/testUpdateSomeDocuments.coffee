rewire = require("rewire")
updateSomeDocuments = rewire('../stored-procedures/updateSomeDocuments')
DocumentDBMock = require('../DocumentDBMock')
mock = new DocumentDBMock(updateSomeDocuments)

exports.updateSomeDocumentsTest =

  basicTest: (test) ->
    mock.nextResources = [
      {_self: '1', etag: '1', id: 1, value: 10}
      {_self: '2', etag: '2', id: 2, value: 20}
      {_self: '3', etag: '3', id: 3, value: 30}
    ]

    memo = updateSomeDocuments.updateSomeDocuments({remaining: 3})

    test.equal(memo.remaining, 0)
    for r, i in mock.rows
      transaction = memo.transactions[i]
      test.deepEqual(transaction.newDocument, r)

    test.done()

  throwTest: (test) ->
    mock.nextResources = [
      {_self: '1', etag: '1', id: 1, value: 10}
    ]

    f = () ->
      memo = updateSomeDocuments.updateSomeDocuments({remaining: 3})

    test.throws(f)

    test.done()