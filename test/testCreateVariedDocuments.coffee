rewire = require("rewire")
generateData = rewire('../stored-procedures/createVariedDocuments')
DocumentDBMock = require('../DocumentDBMock')
mock = new DocumentDBMock(generateData)

exports.generateDataTest =

  basicTest: (test) ->
    memo = generateData.generateData({remaining: 3})
    test.deepEqual(memo, {remaining: 0, totalCount: 3, countForThisRun: 3})
    test.equal(mock.rows.length, 3)
    for key in ['ProjectHierarchy', 'Priority', 'Severity', 'Points', 'State']
      test.ok(mock.lastRow.hasOwnProperty(key))

    test.done()

  throwTest: (test) ->
    f = () ->
      memo = generateData.generateData()  # Missing {remaining: ?}

    test.throws(f)

    test.done()

  testTimeout: (test) ->
    mock.collectionOperationQueuedList = [true, false, false]

    memo = generateData.generateData({remaining: 3})

    test.equal(memo.remaining, 2)
    test.equal(memo.totalCount, 1)
    test.equal(memo.countForThisRun, 1)

    # Continuing
    mock.collectionOperationQueuedList = [true, true, true]
    memo = generateData.generateData(memo)
    test.equal(memo.remaining, 0)
    test.equal(memo.totalCount, 3)
    test.equal(memo.countForThisRun, 2)

    test.done()