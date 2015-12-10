{ServerSideMock} = require('documentdb-mock')
path = require('path')
mock = new ServerSideMock(path.join(__dirname, '..', 'sprocs', 'countDocuments'))

exports.countTest =

  basicTest: (test) ->
    mock.nextResources = [
      {id: 1, value: 10}
      {id: 2, value: 20}
      {id: 3, value: 30}
    ]

    mock.package()

    test.equal(mock.lastBody.count, 3)
    test.ok(!mock.lastBody.continuation?)

    test.done()

  testContinuation: (test) ->
    firstBatch = [
      {id: 1, value: 10}
      {id: 2, value: 20}
    ]
    secondBatch = [
      {id: 3, value: 30}
      {id: 4, value: 40}
    ]
    mock.resourcesList = [firstBatch, secondBatch]

    firstHeaders = {continuation: 'ABC123'}
    secondHeaders = {}
    mock.headersList = [firstHeaders, secondHeaders]

    mock.package()

    test.equal(mock.lastBody.count, 4)
    test.ok(!mock.lastBody.continuation?)

    # Note, lastResponseOptions is NOT the last options returned from a collection operation. This is the last one you sent in.
    test.equal(mock.lastOptions.continuation, 'ABC123')

    test.done()

  testTimeout: (test) ->
    firstBatch = [
      {id: 1, value: 10}
      {id: 2, value: 20}
    ]
    secondBatch = [
      {id: 3, value: 30}
      {id: 4, value: 40}
    ]
    mock.resourcesList = [firstBatch, secondBatch]

    firstHeaders = {continuation: 'ABC123'}
    secondHeaders = {}
    mock.headersList = [firstHeaders, secondHeaders]

    mock.collectionOperationQueuedList = [true, false, true]

    mock.package()

    memo = mock.lastBody

    test.equal(memo.count, 2)
    test.equal(memo.continuation, 'ABC123')

    mock.package(memo)

    test.equal(memo.count, 4)

    test.done()
