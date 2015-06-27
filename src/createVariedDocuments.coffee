documentDBUtils = require('../documentDBUtils')

{generateData} = require('../stored-procedures/createVariedDocuments')
config =
  databaseID: 'test-stored-procedure'
  collectionID: 'test-stored-procedure'
  storedProcedureID: 'generateData'
  storedProcedureJS: generateData
  memo: {remaining: 100}
  debug: false

processResponse = (err, response) ->
  if err?
    console.dir(err)
    throw new Error(err)

  console.log(response.stats)
  console.log(response.memo)

documentDBUtils(config, processResponse)