{ServerSideMock} = require('documentdb-mock')
path = require('path')
mock = new ServerSideMock(path.join(__dirname, '..', 'sprocs', 'createVariedDocuments'))

exports.generateDataTest =

  basicTest: (test) ->
    mock.package({remaining: 3})
    memo = mock.lastBody
    test.deepEqual(memo, {remaining: 0, totalCount: 3, countForThisRun: 3, stillQueueing: true, continuation: null})
    test.equal(mock.rows.length, 3)
    for key in ['ProjectHierarchy', 'Priority', 'Severity', 'Points', 'State']
      test.ok(mock.lastRow.hasOwnProperty(key))

    test.done()

  throwTest: (test) ->
    f = () ->
      memo = mock.package()  # Missing {remaining: ?}

    test.throws(f)

    test.done()

  testTimeout: (test) ->
    mock.collectionOperationQueuedList = [true, false, false]

    mock.package({remaining: 3})
    memo = mock.lastBody

    test.equal(memo.remaining, 2)
    test.equal(memo.totalCount, 1)
    test.equal(memo.countForThisRun, 1)

    # Continuing
    mock.collectionOperationQueuedList = [true, true, true]
    mock.package(memo)
    memo = mock.lastBody
    test.equal(memo.remaining, 0)
    test.equal(memo.totalCount, 3)
    test.equal(memo.countForThisRun, 2)

    test.done()