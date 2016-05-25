{ClientSideMock} = require('documentdb-mock')
path = require('path')
_ = require(path.join('..'))._

path = require('path')
WrappedClient = require(path.join(__dirname, '..', 'src', 'WrappedClient'))

mock = new ClientSideMock()
client = new WrappedClient(mock)

exports.mockedQueryDocumentsTest =

  basicTest: (test) ->
    nextResources = [
      {id: 1, value: 10}
      {id: 2, value: 20}
      {id: 3, value: 30}
    ]
    collectionLink = 'dbs/A/colls/1'
    query = "SELECT * FROM c"
    options = {maxItemCount: 1000}

    mock.nextResources = _.cloneDeep(nextResources)
    nonRetryHeaders = {'x-ms-request-charge': 1000}
    retryHeaders = {'x-ms-retry-after-ms': '30', 'x-ms-request-charge': 100}
    mock.nextHeaders = nonRetryHeaders

    iterator = client.queryDocuments(collectionLink, query, options)

    iterator.executeNext((err, result, headers) ->

      test.deepEqual(result, nextResources)
      test.deepEqual(headers, nonRetryHeaders)

      test.equal(mock.lastEntityLink, collectionLink)
      test.equal(mock.lastQueryFilter, query)
      test.equal(mock.lastOptions, options)

      test.done()
    )

  error429Test: (test) ->
    firstBatch = [
      {id: 1, value: 10}
      {id: 2, value: 20}
    ]
    secondBatch = [
      {id: 3, value: 30}
      {id: 4, value: 40}
    ]
    mock.resourcesList = [null, firstBatch, secondBatch]
    error429 = {code: 429, body: "429 Error"}
    mock.errorList = [error429, null, null]
    firstHeaders = {'x-ms-retry-after-ms': '300'}
    secondHeaders = {'x-ms-retry-after-ms': '400'}
    mock.headersList = [{}, firstHeaders, secondHeaders]

    collectionLink = 'dbs/A/colls/1'
    query = "SELECT * FROM c"
    options = {maxItemCount: 2}

    iterator = client.queryDocuments(collectionLink, query, options)

    iterator.executeNext((err, result, headers, roundTripCount, retries, totalDelay, totalTime) ->
      if err?
        console.dir(err)
        throw new Error("Got unexpected error during error429Test")

      test.deepEqual(result, firstBatch)
      test.deepEqual(headers, firstHeaders)
      test.equal(retries, 1)
      test.equal(roundTripCount, 2)
      test.equal(totalDelay, 0)
      test.ok(_.isNumber(totalTime))

      iterator.executeNext((err, result, headers, roundTripCount, retries, totalDelay, totalTime) ->
        if err?
          console.dir(err)
          throw new Error("Got unexpected error during error429Test")

        test.deepEqual(result, secondBatch)
        test.deepEqual(headers, secondHeaders)
        test.equal(roundTripCount, 1)
        test.equal(retries, 0)
        test.equal(totalDelay, 0)
        test.ok(_.isNumber(totalTime))

        test.equal(mock.lastEntityLink, collectionLink)
        test.equal(mock.lastQueryFilter, query)
        test.equal(mock.lastOptions, options)

        test.done()
      )
    )

  error429OutOfRetriesTest: (test) ->
    error429 = {code: 429, body: "429 Error"}
    mock.errorList = [error429, error429, error429, error429]

    collectionLink = 'dbs/A/colls/1'
    query = "SELECT * FROM c"
    options = {maxItemCount: 2}

    iterator = client.queryDocuments(collectionLink, query, options)

    iterator.executeNext((err, result, headers, retries) ->
      test.deepEqual(err, error429)
      test.done()
    )

  error429UnderRetryLimitTest: (test) ->
    error429 = {code: 429, body: "429 Error"}
    mock.errorList = [error429, error429, error429, null]

    collectionLink = 'dbs/A/colls/1'
    query = "SELECT * FROM c"
    options = {maxItemCount: 2}

    iterator = client.queryDocuments(collectionLink, query, options)

    iterator.executeNext((err, result, headers, retries) ->
      test.equal(err, null)
      test.done()
    )

  arrayError429Test: (test) ->
    firstBatch = [
      {id: 1, value: 10}
      {id: 2, value: 20}
    ]
    secondBatch = [
      {id: 3, value: 30}
      {id: 4, value: 40}
    ]
    mock.resourcesList = [null, firstBatch, secondBatch]
    error429 = {code: 429, body: "429 Error"}
    mock.errorList = [error429, null, null]
    nonRetryHeaders = {'x-ms-request-charge': 1000}
    retryHeaders = {'x-ms-retry-after-ms': '10', 'x-ms-request-charge': 2000}
    mock.headersList = [retryHeaders, nonRetryHeaders, nonRetryHeaders]

    collectionLink = 'dbs/A/colls/1'
    query = "SELECT * FROM c"
    options = {maxItemCount: 2}

    iterator = client.queryDocumentsArray(collectionLink, query, options, (err, result, stats) ->
      if err?
        console.dir(err)
        throw new Error("Got unexpected error during error429Test")

      test.deepEqual(result, firstBatch.concat(secondBatch))

      test.equal(stats.roundTripCount, 2)
      test.equal(stats.retries, 1)
      test.equal(stats.requestUnitCharges, 2000)
      test.equal(stats.totalDelay, 10)
      test.ok(stats.totalTime >= stats.totalDelay)

      test.done()
    )
