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
    exampleHeaders = {'x-ms-retry-after-ms': '300'}
    mock.nextHeaders = exampleHeaders

    iterator = client.queryDocuments(collectionLink, query, options)

    iterator.executeNext((err, result, headers) ->

      test.deepEqual(result, nextResources)
      test.deepEqual(headers, exampleHeaders)
      test.equal(iterator.hasMoreResults(), false)

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

    iterator.executeNext((err, result, headers, retries) ->
      if err?
        console.dir(err)
        throw new Error("Got unexpected error during error429Test")

      test.deepEqual(result, firstBatch)
      test.deepEqual(headers, firstHeaders)
      test.equal(retries, 1)

      iterator.executeNext((err, result, headers, retries) ->
        if err?
          console.dir(err)
          throw new Error("Got unexpected error during error429Test")

        test.deepEqual(result, secondBatch)
        test.deepEqual(headers, secondHeaders)
        test.equal(retries, 0)

        test.equal(mock.lastEntityLink, collectionLink)
        test.equal(mock.lastQueryFilter, query)
        test.equal(mock.lastOptions, options)

        test.done()
      )
    )

#  arrayError429Test: (test) ->
#    firstBatch = [
#      {id: 1, value: 10}
#      {id: 2, value: 20}
#    ]
#    secondBatch = [
#      {id: 3, value: 30}
#      {id: 4, value: 40}
#    ]
#    mock.resourcesList = [null, firstBatch, secondBatch]
#    error429 = {code: 429, body: "429 Error"}
#    mock.errorList = [error429, null, null]
#
#    collectionLink = 'dbs/A/colls/1'
#    query = "SELECT * FROM c"
#    options = {maxItemCount: 2}
#
#    iterator = client.queryDocumentsArray(collectionLink, query, options, (err, result, stats) ->
#      if err?
#        console.dir(err)
#        throw new Error("Got unexpected error during error429Test")
#
#      console.dir(result)
#      console.dir(stats)
#
#      test.done()
#    )

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
#    firstOptions = {continuation: 'ABC123'}
#    secondOptions = {}
#    mock.optionsList = [firstOptions, secondOptions]
#
#    mock.package()
#
#    test.equal(mock.lastBody.count, 4)
#    test.ok(!mock.lastBody.continuation?)
#
#    # Note, lastOptions is NOT the last options returned from a collection operation. This is the last one you sent in.
#    test.equal(mock.lastOptions.continuation, 'ABC123')
#
#    test.done()
#
#  testTimeout: (test) ->
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
#    firstOptions = {continuation: 'ABC123'}
#    secondOptions = {}
#    mock.optionsList = [firstOptions, secondOptions]
#
#    mock.collectionOperationQueuedList = [true, false, true]
#
#    mock.package()
#
#    memo = mock.lastBody
#
#    test.equal(memo.count, 2)
#    test.equal(memo.continuation, 'ABC123')
#
#    mock.package(memo)
#
#    test.equal(memo.count, 4)
#
#    test.done()
