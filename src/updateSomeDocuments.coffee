documentDBUtils = require('../documentDBUtils')
DocumentClient = require("documentdb").DocumentClient

{updateSomeDocuments} = require('../stored-procedures/updateSomeDocuments')
config =
  databaseID: 'test-stored-procedure'
  collectionID: 'test-stored-procedure'
  storedProcedureID: 'updateSomeDocuments'
  storedProcedureJS: updateSomeDocuments
  memo: {remaining: 3}
  debug: false

processResponse = (err, response) ->
  if err?
    console.dir(err)
    throw new Error(err)

  console.log(response.stats)
  for t, i in response.memo.transactions
    documentLink = t.oldDocument._self
    console.log("New document #{i} expected to be: #{JSON.stringify(t.newDocument)}")
    config2 = {client: config.client, documentLink}
    documentDBUtils(config2, (err, response) ->
      if err
        throw err
      console.log(response.stats)
      console.log(response.document)
    )


documentDBUtils(config, processResponse)