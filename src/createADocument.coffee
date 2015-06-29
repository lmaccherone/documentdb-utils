documentDBUtils = require('../documentDBUtils')

config =
  databaseID: 'test-stored-procedure'
  collectionID: 'test-stored-procedure'
  document: {a:1, b:2}
  debug: false

documentDBUtils(config, (err, response) ->
  if err
    throw err
  console.log(response.stats)
  console.log(response.document)
)