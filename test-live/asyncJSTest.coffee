path = require('path')
{DocumentClient} = require('documentdb')
async = require('async')
{WrappedClient, loadSprocs, loadUDFs, getLinkArray, getLink} = require('../index')


client = null
wrappedClient = null
docsRemaining = 10
docsRetrieved = 0

exports.asyncJSTest =

  setUp: (setUpCallback) ->
    urlConnection = process.env.DOCUMENT_DB_URL
    masterKey = process.env.DOCUMENT_DB_KEY
    auth = {masterKey}
    client = new DocumentClient(urlConnection, auth)
    wrappedClient = new WrappedClient(client)
    client.deleteDatabase('dbs/dev-test-database', () ->
      client.createDatabase({id: 'dev-test-database'}, (err, response, headers) ->
        databaseLink = response._self
        client.createCollection(databaseLink, {id: '1'}, {offerType: 'S2'}, (err, response, headers) ->
          collectionLinks = getLinkArray(['dev-test-database'], [1])
          async.parallel([
            (callback) ->
              scriptsDirectory = path.join(__dirname, '..', 'udfs')
              udfSpec = {scriptsDirectory, client, collectionLinks}
              loadUDFs(udfSpec, (err, result) ->
                sprocLink = getLink(collectionLinks[0], 'createVariedDocuments')
                console.log("UDFs loaded for test")
                callback(err, result)
              )
            , (callback) ->
              scriptsDirectory = path.join(__dirname, '..', 'sprocs')
              spec = {scriptsDirectory, client, collectionLinks}
              loadSprocs(spec, (err, result) ->
                console.log("sprocs loaded for test")
                sprocLink = getLink(collectionLinks[0], 'createVariedDocuments')
                wrappedClient.executeStoredProcedure(sprocLink, {remaining: docsRemaining}, (err, response) ->
                  console.log("Documents created for test")
                  callback(err, response)
                )
              )
          ],
            (err, results) ->
              if err?
                throw new Error("Got error trying to load sprocs, UDFs or call to createVariedDocuments sproc in test setup")
              console.log("Test setup done")
              setUpCallback()
          )
        )
      )
    )

  arrayTest: (test) ->
    collectionLink = getLink('dev-test-database', 1)
    wrappedClient.readDocumentsArrayAsyncJSIterator([collectionLink, {maxItemCount: 4}], (err, result, stats) ->
      if err?
        console.dir(err)
        throw new Error("Got error when trying to readDocumentsArray via WrappedClient")
      test.equal(result.length, docsRemaining)
      test.equal(stats.roundTripCount, 3)
      test.equal(stats.retries, 0)
      test.equal(stats.totalDelay, 0)
      test.ok(stats.totalTime >= 10)
      test.done()
    )

  createDocumentTest: (test) ->
    collectionLink = getLink('dev-test-database', 1)
    wrappedClient.createDocumentAsyncJSIterator([collectionLink, {a: 1}], (err, result) ->
      if err?
        console.dir(err)
        throw new Error("Got error when trying to createDocumentAsyncJSIterator via WrappedClient")
      test.equal(result.response.a, 1)
      test.ok(result.headers?)
      test.equal(result.retries, 0)
      test.equal(result.totalDelay, 0)
      test.ok(result.totalTime >= 10)
      test.done()
    )

  asyncMapTest: (test) ->
    docs = [
      {a: 1},
      {b: 2}
    ]
    collectionLink = getLink('dev-test-database', 1)
    parametersArray = ([collectionLink, doc] for doc in docs)

    async.map(parametersArray, wrappedClient.createDocumentAsyncJSIterator, (err, result) ->
      if err?
        throw new Error("Got unexpected error in asyncMapTest")
      test.equal(result.length, docs.length)
      test.equal(result[0].response.a, docs[0].a)
      test.ok(result[0].headers?)
      test.equal(result[0].retries, 0)
      test.equal(result[0].totalDelay, 0)
      test.ok(result[0].totalTime >= 10)

      test.equal(result[1].response.b, docs[1].b)
      test.ok(result[1].headers?)
      test.equal(result[1].retries, 0)
      test.equal(result[1].totalDelay, 0)
      test.ok(result[1].totalTime >= 10)
      test.done()
    )

  sprocAsyncMapTest: (test) ->
    sprocLink = getLink('dev-test-database', 1, 'countDocuments')
    parametersArray = [[sprocLink]]

    async.map(parametersArray, wrappedClient.executeStoredProcedureAsyncJSIterator, (err, result) ->
      if err?
        console.dir(err)
        throw new Error("Got unexpected error in sprocAsyncMapTest")
      test.equal(result[0].response.count, docsRemaining)
      test.equal(result[0].roundTripCount, 1)
      test.ok(result[0].headers?)
      test.equal(result[0].retries, 0)
      test.equal(result[0].totalDelay, 0)
      test.ok(result[0].totalTime >= 10)
      test.done()
    )

  tearDown: (callback) ->
    f = () ->
      client.deleteDatabase('dbs/dev-test-database', () ->
        callback()
      )
    setTimeout(f, 500)