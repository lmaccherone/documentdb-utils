path = require('path')
StorageEngine = require(path.join('..', 'StorageEngineForDocumentDB'))
{DocumentClient} = require('documentdb')

se = null

config =
  firstTopLevelID: 'dev-test-database'
  firstSecondLevelID: 'dev-test-collection'
  terminate: false
  debug: false

user =
  password: ';/klikl.o;/;'
  _EntityID: 100
  _TenantID: 'a'
  username: 'username'
  tenantIDsICanRead: ['a', 'b']
  tenantIDsICanWrite: ['a']
  tenantIDsICanAdmin: ['a']

session = null

exports.retryOn429Test =

  setUp: (callback) ->
    urlConnection = process.env.DOCUMENT_DB_URL
    masterKey = process.env.DOCUMENT_DB_KEY
    auth = {masterKey}
    client = new DocumentClient(urlConnection, auth)
    client.deleteDatabase('dbs/dev-test-database', () =>
      callback()
    )

  theTest: (test) ->

    se = new StorageEngine(config, () =>
      c = se.storageEngineConfig
      test.equal(c.id, 'storage-engine-config')
      test.equal(c.mode, 'RUNNING')
      test.equal(c.lastValidFrom, '0001-01-01T00:00:00.000Z')
      test.deepEqual(c.partitionConfig.topLevelLookupMap, {default: 'dev-test-database'})

      se.upsertUser(session?.id, user, (err, result, memo) =>
        if err?
          console.dir(err)
          throw new Error(err)
        test.equal(result._EntityID, 100)
        test.equal(result._TenantID, 'a')
        test.equal(result.username, 'username')
        test.ok(result._IsTemporalizeUser)
        test.ok(result.salt?)
        test.ok(result.hash?)
        test.ok(! result.password?)
        se.login('username', 'wrong password', (err, session) =>
          test.equal(err.code, 401)
          test.equal(err.body, "Password does not match")
          se.login('username', ';/klikl.o;/;', (err, session) =>
            if err?
              console.dir(err)
              throw new Error(err)
            test.ok(session._IsSession)
            test.equal(session.user._TenantID, 'a')
            test.equal(session.user.username, 'username')
            test.ok(not session.user.password?)
            test.ok(se.sessionCacheByID[session.id]?)
            se.upsert(session.id, {_TenantID: 'a', _EntityID: 1, a: 1, c: 3}, (err, result, memo) =>
              first = result
              test.equal(first.a, 1)
              test.equal(first.c, 3)
              test.ok(not first.b?)

              se.upsert(session.id, {_TenantID: 'a', _EntityID: 1, a: 10, b: 20, c: null}, (err, result, memo) =>

                queryConfig =
                  topLevelPartitionKey: 'a'
                  secondLevelPartitionKey: 1
                  fields: '*'
                #            fields: ["a", "b", "c"]

                se.query(session.id, queryConfig, (err, response, memo) =>
                  if err?
                    throw err

                  test.equal(response.length, 2)
                  first = response[0]
                  second = response[1]
                  test.equal(first.a, 1)
                  test.equal(second.a, 10)
                  test.equal(first.c, 3)
                  test.equal(second.b, 20)
                  test.ok(not first.b?)
                  test.ok(not second.c?)
                  test.equal(memo.storageEngineConfig.lastValidFrom, second._ValidFrom)
                  test.equal(memo.storageEngineConfig.lastValidFrom, first._ValidTo)
                  test.equal(memo.requestCount, memo.responseCount)

                  se.logout(session.id, (err, result) =>
                    test.ok(result)
                    test.ok(not se.sessionCacheByID[session.id]?)

                    se.terminate = true
                    test.done()
                  )
                )
              )
            )
          )
        )
      )
    )

  tearDown: (callback) ->
    f = () =>
      se.client.deleteDatabase(se._getLink(config.firstTopLevelID), () =>
        callback()
      )
    setTimeout(f, config.refreshConfigMS + 500)