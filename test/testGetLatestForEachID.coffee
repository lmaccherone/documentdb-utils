{ServerSideMock} = require('documentdb-mock')
path = require('path')
mock = new ServerSideMock(path.join(__dirname, '..', 'sprocs', 'getLatestForEachID'))

exports.countTest =

  basicTest: (test) ->
    mock.nextResources = [
      {UserId: 1, value: 10, DateCreated: "2015-12-10 22:44:03"}
      {UserId: 1, value: 20, DateCreated: "2015-12-10 22:45:03"}
      {UserId: 2, value: 30, DateCreated: "2015-12-10 22:45:04"}
      {UserId: 1, value: 20, DateCreated: "2015-12-10 22:46:03"}
      {UserId: 2, value: 30, DateCreated: "2015-12-10 22:46:04"}
    ]

    mock.package()

    console.log(mock.lastBody)

    test.equal(mock.lastBody.count, 3)
    test.ok(!mock.lastBody.continuation?)

    test.done()

#  testContinuation: (test) ->
#    firstBatch = [
#      {id: 1, value: 10}
#      {id: 2, value: 20}
#    ]
#    secondBatch = [
#      {id: 3, value: 30}
#      {id: 4, value: 40}
#    ]
#    mock.resourcesList = [firstBatch, secondBatch]
#
#    firstHeaders = {continuation: 'ABC123'}
#    secondHeaders = {}
#    mock.headersList = [firstHeaders, secondHeaders]
#
#    mock.package()
#
#    test.equal(mock.lastBody.count, 4)
#    test.ok(!mock.lastBody.continuation?)
#
#    # Note, lastResponseOptions is NOT the last options returned from a collection operation. This is the last one you sent in.
#    test.equal(mock.lastOptions.continuation, 'ABC123')
#
#    test.done()

