{ServerSideMock} = require('documentdb-mock')
path = require('path')
mock = new ServerSideMock(path.join(__dirname, '..', 'sprocs', 'getLatestForEachID'))

exports.countTest =

  basicTest: (test) ->
    mock.nextResources = [
      {UserId: 1, value: 10, DateCreated: "2015-12-10 22:44:03"}
      {UserId: 1, value: 20, DateCreated: "2015-12-10 22:45:03"}
      {UserId: 2, value: 10, DateCreated: "2015-12-10 22:45:04"}
      {UserId: 1, value: 30, DateCreated: "2015-12-10 22:46:03"}
      {UserId: 2, value: 20, DateCreated: "2015-12-10 22:46:04"}
    ]

    mock.package()

    expected = {
      '1': { UserId: 1, value: 30, DateCreated: '2015-12-10 22:46:03' },
      '2': { UserId: 2, value: 20, DateCreated: '2015-12-10 22:46:04' }
    }
    result = mock.lastBody.result

    test.deepEqual(result, expected)

    test.done()

  testContinuation: (test) ->
    firstBatch =  [
      {UserId: 1, value: 10, DateCreated: "2015-12-10 22:44:03"}
      {UserId: 1, value: 20, DateCreated: "2015-12-10 22:45:03"}
      {UserId: 2, value: 10, DateCreated: "2015-12-10 22:45:04"}
    ]
    secondBatch = [
      {UserId: 1, value: 30, DateCreated: "2015-12-10 22:46:03"}
      {UserId: 2, value: 20, DateCreated: "2015-12-10 22:46:04"}
    ]
    mock.resourcesList = [firstBatch, secondBatch]

    firstHeaders = {continuation: 'ABC123'}
    secondHeaders = {}
    mock.headersList = [firstHeaders, secondHeaders]

    mock.package()
    
    expected = {
      '1': { UserId: 1, value: 30, DateCreated: '2015-12-10 22:46:03' },
      '2': { UserId: 2, value: 20, DateCreated: '2015-12-10 22:46:04' }
    }
    result = mock.lastBody.result

    test.deepEqual(result, expected)

    test.done()

