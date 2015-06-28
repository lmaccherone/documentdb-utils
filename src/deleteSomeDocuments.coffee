documentDBUtils = require('../documentDBUtils')
DocumentClient = require("documentdb").DocumentClient

{deleteSomeDocuments} = require('../stored-procedures/deleteSomeDocuments')
config =
  databaseID: 'test-stored-procedure'
  collectionID: 'test-stored-procedure'
  storedProcedureID: 'deleteSomeDocuments'
  storedProcedureJS: deleteSomeDocuments
  memo: {remaining: 3}
  debug: false

processResponse = (err, response) ->
  if err?
    console.dir(err)
    throw new Error(err)

  console.log(response.stats)
  console.log(response.memo)

documentDBUtils(config, processResponse)