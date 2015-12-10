path = require('path')
{DocumentClient} = require('documentdb')
async = require('async')
{WrappedClient, loadSprocs, getLinkArray, getLink} = require('../')


client = null
wrappedClient = null
docsRemaining = 4000
docsRetrieved = 0

exports.wrappedToArrayTest =

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
          scriptsDirectory = path.join(__dirname, '..', 'sprocs')
          spec = {scriptsDirectory, client, collectionLinks}
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

#  junkTest: (test) ->
#    test.done()

  getAllTest: (test) ->
    collectionLink = getLink('dev-test-database', 1)
    wrappedClient.readDocumentsArray(collectionLink, {maxItemCount: 1000}, (err, response, stats) ->
      if err?
        console.dir(err)
        throw new Error("Got error when trying to readDocumentsArray via WrappedClient")
      test.equal(response.length, docsRemaining)
      test.ok(stats.roundTripCount >= docsRemaining/1000)
      test.ok(stats.requestUnitCharges?)
      test.ok(stats.retries?)
#      console.log("Total number of docs = #{docsRemaining} and maxItemCount = 1000 so should only need #{docsRemaining/1000} pages. Instead it takes #{pages} pages")
      test.done()
    )

  toArrayTest: (test) ->
    collectionLink = getLink('dev-test-database', 1)
    wrappedClient.readDocuments(collectionLink, {maxItemCount: 1000}).toArray((err, response, stats) ->
      if err?
        console.dir(err)
        throw new Error("Got error when trying to readDocumentsArray via WrappedClient")
      test.equal(response.length, docsRemaining)
      test.ok(stats.roundTripCount >= docsRemaining/1000)
      test.ok(stats.requestUnitCharges?)
      test.ok(stats.retries?)
      test.done()
    )

  negativeOneMaxItemCountTest: (test) ->
    collectionLink = getLink('dev-test-database', 1)
    wrappedClient.readDocuments(collectionLink, {maxItemCount: -1}).toArray((err, response, stats) ->
      if err?
        console.dir(err)
        throw new Error("Got error when trying to readDocumentsArray via WrappedClient")
      test.equal(response.length, docsRemaining)
      if stats.roundTripCount < 2
        console.log("Didn't have enough docs in the test to cause this test to need more than one round trip. Please either rerun after maybe increasing docsRemaining")
      test.ok(stats.roundTripCount > 1)
      test.ok(stats.requestUnitCharges?)
      test.ok(stats.retries?)
      test.done()
    )

  tearDown: (callback) ->
    f = () ->
      client.deleteDatabase('dbs/dev-test-database', () ->
        callback()
      )
    setTimeout(f, 500)