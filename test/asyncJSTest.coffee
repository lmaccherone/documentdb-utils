path = require('path')
{DocumentClient} = require('documentdb')
async = require('async')
{WrappedClient, loadSprocs, getLinkArray, getLink} = require('../')


client = null
wrappedClient = null
docsRemaining = 10
docsRetrieved = 0

exports.asyncJSTest =

  setUp: (callback) ->
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
          sprocDirectory = path.join(__dirname, '..', 'sprocs')
          spec = {sprocDirectory, client, collectionLinks}
          loadSprocs(spec, (err, result) ->
            if err?
              console.dir(err)
              throw new Error("Error during test setup")
            sprocLink = getLink(collectionLinks[0], 'createVariedDocuments')
            wrappedClient.executeStoredProcedure(sprocLink, {remaining: docsRemaining}, (err, response) ->
              if err?
                throw new Error("Got error trying to create documents for test")
              console.log("Documents created for test")
              callback()
            )
          )
        )
      )
    )

  arrayTest: (test) ->
    collectionLink = getLink('dev-test-database', 1)
    wrappedClient.readDocumentsArrayAsyncJSIterator([collectionLink, {maxItemCount: 5}], (err, response) ->
      if err?
        console.dir(err)
        throw new Error("Got error when trying to readDocumentsArray via WrappedClient")
      test.equal(response.response.length, docsRemaining)
      test.ok(response.headers?)
      test.ok(response.other > 1)
      test.done()
    )

  createDocumentTest: (test) ->
    collectionLink = getLink('dev-test-database', 1)
    wrappedClient.createDocumentAsyncJSIterator([collectionLink, {a: 1}], (err, response) ->
      if err?
        console.dir(err)
        throw new Error("Got error when trying to readDocumentsArray via WrappedClient")
      test.equal(response.response.a, 1)
      test.ok(response.headers?)
      test.ok(response.other?)
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
      test.equal(result[1].response.b, docs[1].b)
      test.done()
    )

  tearDown: (callback) ->
    f = () ->
      client.deleteDatabase('dbs/dev-test-database', () ->
        callback()
      )
    setTimeout(f, 500)