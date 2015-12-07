path = require('path')
{DocumentClient} = require('documentdb')
async = require('async')
{WrappedClient, loadSprocs, getLinkArray, getLink} = require('../')


client = null
wrappedClient = null
docsRemaining = 10
docsRetrieved = 0

exports.multiTest =

  setUp: (callback) ->
    urlConnection = process.env.DOCUMENT_DB_URL
    masterKey = process.env.DOCUMENT_DB_KEY
    auth = {masterKey}
    client = new DocumentClient(urlConnection, auth)
    wrappedClient = new WrappedClient()
    client.deleteDatabase('dbs/dev-test-database', () ->
      client.createDatabase({id: 'dev-test-database'}, (err, response, headers) ->
        databaseLink = 'dbs/dev-test-database'
        options = {offerType: 'S2'}
        parametersArray = [
          [databaseLink, {id: '1'}, options],
          [databaseLink, {id: '2'}, options]
        ]
        async.map(parametersArray, wrappedClient.createCollectionAsyncJSIterator, (err, result) ->
          collectionLinks = getLinkArray(['dev-test-database'], [1, 2])
          sprocDirectory = path.join(__dirname, '..', 'sprocs')
          spec = {sprocDirectory, client, collectionLinks}
          loadSprocs(spec, (err, result) ->
            if err?
              console.dir(err)
              throw new Error("Error during test setup")
            sprocLinks = getLinkArray(collectionLinks, 'createVariedDocuments')
            wrappedClient.executeStoredProcedureMulti(sprocLinks, {remaining: docsRemaining}, (err, result, stats) ->
              if err?
                throw new Error("Got error trying to create documents for test")
              console.log("Documents created for test")
              callback()
            )
          )
        )
      )
    )

  multiStoredProcedureTest: (test) ->
    sprocLinks = getLinkArray(['dev-test-database'], [1, 2], 'countDocuments')
    wrappedClient.executeStoredProcedureMulti(sprocLinks, (err, result, stats) ->
      test.equal(result.length, 2)
      test.ok(stats.requestUnitCharges?)
      test.done()
    )

  multiReadDocumentsTest: (test) ->
    collectionLinks = getLinkArray(['dev-test-database'], [1, 2])
    wrappedClient.readDocumentsArrayMulti(collectionLinks, (err, result, stats) ->
      test.equal(result.length, docsRemaining * 2)
      test.equal(stats.roundTripCount, 2)
      test.equal(stats.itemCount, docsRemaining * 2)
      test.ok(stats.requestUnitCharges?)
      test.done()
    )

  tearDown: (callback) ->
    f = () ->
      client.deleteDatabase('dbs/dev-test-database', () ->
        callback()
      )
    setTimeout(f, 500)