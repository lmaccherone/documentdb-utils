path = require('path')
{DocumentClient} = require('documentdb')
async = require('async')
{WrappedClient, loadSprocs, getLinkArray, getLink} = require('../')


client = null
docsRemaining = 8000
docsRetrieved = 0

getPagesUntilError = (iterator, callback) ->
  iterator.executeNext((err, response, headers, retries) ->
    if err?
      console.log('should not get here')
      return callback(err, response, headers)

    docsRetrieved += response.length
    console.log("#{docsRetrieved}/#{docsRemaining} docs retrieved")
    if iterator.hasMoreResults()
      getPagesUntilError(iterator, callback)
    else
      return callback(err, response, headers, retries)

  )

exports.retryOn429Test =

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
            # result now contains all sprocLinks
            callback()
          )
        )
      )
    )

  callbackMethodTest: (test) ->
    wrappedClient = new WrappedClient(client)
    collectionLink = getLink('dev-test-database', 1)
    sprocLink = getLink(collectionLink, 'createVariedDocuments')
    async.forever(
      (next) ->
        client.executeStoredProcedure(sprocLink, {remaining: 1000}, next)
      (err) ->
        unless err?.code is 429
          console.dir(err)
          throw new Error("Got something other than a 429 error when trying to create load")
        wrappedClient.createDocument(collectionLink, {a:1}, (err, response, headers) ->
          if err?
            console.dir(err)
            throw new Error("Got error when trying to create document via WrappedClient")
          test.equal(response.a, 1)
          test.done()
        )
    )

  queryIteratorTest: (test) ->
    wrappedClient = new WrappedClient(client)
    collectionLink = getLink('dev-test-database', 1)
    sprocLink = getLink(collectionLink, 'createVariedDocuments')
    iterator = wrappedClient.readDocuments(collectionLink, {maxItemCount: -1})
    async.forever(
      (next) ->
        wrappedClient.executeStoredProcedure(sprocLink, {remaining: docsRemaining}, (err, response, headers) ->
          if err?
            console.dir(err)
          if response.remaining > 0
            next(err)
          else
            console.log('Done creating load')
            next({code: 499})
        )
      (err) ->
        unless err? and err.code is 499
          console.dir(err)
          throw new Error("Got something other than a 499 error when trying to create load with wrapped client")
        getPagesUntilError(iterator, (err, response, headers, retries) ->
          if err?
            console.dir(err)
            throw new Error("Unexepected error during queryIteratorTest")
          if retries <= 0
            console.log("""
              It's very hard to deterministically recreate 429 erros. This test run did not produce any retries,
              so this test will fail. You should rerun this queryIteratorTest until it passes (usually within 2-3 tries).
            """)
          test.ok(retries > 0)
          test.done()
        )
    )

  tearDown: (callback) ->
    f = () ->
      client.deleteDatabase('dbs/dev-test-database', () ->
        callback()
      )
    setTimeout(f, 500)