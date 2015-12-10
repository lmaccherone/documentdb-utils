path = require('path')
{DocumentClient} = require('documentdb')
async = require('async')
{WrappedClient, loadSprocs, getLinkArray, getLink} = require('../index')


client = null
wrappedClient = null
collectionLinks = null

exports.underscoreTest =

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
          scriptsDirectory = path.join(__dirname, '..', 'sprocs')
          spec = {scriptsDirectory, client, collectionLinks}
          loadSprocs(spec, (err, result) ->
            sprocLink = getLink(collectionLinks[0], 'createVariedDocuments')
            console.log("sprocs loaded for test")
            setUpCallback(err, result)
          )
        )
      )
    )


  theTest: (test) ->
    sprocLink = getLink('dev-test-database', 1, 'testUnderscore')
    client.executeStoredProcedure(sprocLink, (err, response, headers) ->
      if err?
        console.dir(err)
        throw new Error("Got error running testUnderscore sproc")
      console.log(response)
      test.done()
    )

  tearDown: (callback) ->
    f = () ->
      client.deleteDatabase('dbs/dev-test-database', () ->
        callback()
      )
    setTimeout(f, 500)