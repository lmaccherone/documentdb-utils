{ClientSideMock} = require('documentdb-mock')
path = require('path')
_ = require(path.join('..'))._

path = require('path')
WrappedClient = require(path.join(__dirname, '..', 'src', 'WrappedClient'))

mock = new ClientSideMock()
client = new WrappedClient(mock)

module.exports =

  confirmLeaveAloneString: (test) ->
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

  confirmLeaveAloneSqlQuerySpec: (test) ->
    nextResources = [
      {id: 1, value: 10}
      {id: 2, value: 20}
      {id: 3, value: 30}
    ]
    collectionLink = 'dbs/A/colls/1'
    query = {
      query: "SELECT * FROM c WHERE c.myField = $1"
      parameters: [
        {name: '$1', value: "John"}
      ]
    }
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

  convertFromMongo: (test) ->
    nextResources = [
      {id: 1, value: 10}
      {id: 2, value: 20}
      {id: 3, value: 30}
    ]
    collectionLink = 'dbs/A/colls/1'
    query = {
      query: {value: 30}
      fields: ['value']
      collectionName: 'food'
    }
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
      test.equal(mock.lastQueryFilter, "SELECT food.value FROM food WHERE food.value = 30")
      test.equal(mock.lastOptions, options)

      test.done()
    )

  defaultsForMongo: (test) ->
    query = {query: {value: 30}}
    iterator = client.queryDocuments('', query, {})
    test.equal(mock.lastQueryFilter, "SELECT * FROM c WHERE c.value = 30")

    query = {query: {value: 30}, fields: ['value']}
    iterator = client.queryDocuments('', query, {})
    test.equal(mock.lastQueryFilter, "SELECT c.value FROM c WHERE c.value = 30")

    query = {query: {value: 30}, collectionName: 'junk'}
    iterator = client.queryDocuments('', query, {})
    test.equal(mock.lastQueryFilter, "SELECT * FROM junk WHERE junk.value = 30")

    test.done()