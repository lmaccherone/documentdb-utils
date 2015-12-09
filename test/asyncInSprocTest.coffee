path = require('path')
{DocumentClient} = require('documentdb')
async = require('async')
{WrappedClient, loadSprocs, getLinkArray, getLink} = require('../')


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
    sprocLink = getLink('dev-test-database', 1, 'testAsync')
    client.executeStoredProcedure(sprocLink, (err, response, headers) ->
      if err?
        console.dir(err)
        throw new Error("Got error running testUnderscore sproc")

      expected =
        stepOne: true,
        waterfall1: true,
        waterfallParameter: 'one',
        waterfallEnd: true,
        waterfallResult: 'two',
        series1: true,
        series2: true,
        seriesEnd: true,
        seriesResult: [ 'one', 'two' ],
        parallel1: true,
        parallel2: true,
        parallelEnd: true,
        parallelResult: [ 'one', 'two' ],
        auto1: true,
        auto2: true,
        auto3: true,
        auto3Results: { one: 'one', two: 'two', three: 'three' },
        autoEnd: true,
        autoResult: { one: 'one', two: 'two', three: 'three' }

      test.deepEqual(response, expected)
      test.done()
    )

  tearDown: (callback) ->
    f = () ->
      client.deleteDatabase('dbs/dev-test-database', () ->
        callback()
      )
    setTimeout(f, 500)