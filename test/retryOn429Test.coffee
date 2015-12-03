path = require('path')
{DocumentClient} = require('documentdb')
WrappedClient = require(path.join(__dirname, "..", "src", "WrappedClient"))
loadSprocs = require(path.join(__dirname, "..", "src", "loadSprocs"))
getLinkArray = require(path.join(__dirname, "..", "src", "getLinkArray"))

client = null

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
        client.createCollection(databaseLink, {id: '1'}, (err, response, headers) ->
          client.createCollection(databaseLink, {id: '2'}, (err, response, headers) ->
            collectionLinks = getLinkArray(['dev-test-database'], [1, 2])
            sprocDirectory = path.join(__dirname, '..', 'sprocs')
            spec = {sprocDirectory, client, collectionLinks}
            loadSprocs(spec, (err) ->
              console.log('All sprocs loaded')
              callback()
            )
          )
        )
      )
    )

  theTest: (test) ->
    console.log('hello')
    test.done()


  tearDown: (callback) ->
    f = () ->
      client.deleteDatabase('dbs/dev-test-database', () ->
        callback()
      )
    setTimeout(f, 500)