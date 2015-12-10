{ServerSideMock} = require('documentdb-mock')
path = require('path')
mock = new ServerSideMock(path.join(__dirname, '..', 'sprocs', 'updateSomeDocuments'))

exports.updateSomeDocumentsTest =

  basicTest: (test) ->
    mock.nextResources = [
      {_self: '1', etag: '1', id: 1, value: 10}
      {_self: '2', etag: '2', id: 2, value: 20}
      {_self: '3', etag: '3', id: 3, value: 30}
    ]

    memo = mock.package({remaining: 3})

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
      memo = mock.package({remaining: 3})

    test.throws(f)

    test.done()