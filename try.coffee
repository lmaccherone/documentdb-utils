{documentDBUtils} = require('./documentDBUtils')

{hello} = require('./hello')

config =
  databaseID: 'test-stored-procedure'
  collectionID: 'test-stored-procedure'
  storedProcedureID: 'hello'
  storedProcedureJS: hello
  memo: {}

processResponse = (err, response) ->
  if err?
    throw err
  console.log('First execution including sending stored procedure to DocumentDB')
  console.log(response.memo)
  console.log(response.stats)
  config2 =
    storedProcedureLink: response.storedProcedureLink
    memo: {}
  documentDBUtils(config2, (err, response) ->
    if err
      throw err
    console.log('\nSecond execution')
    console.log(response.memo)
    console.log(response.stats)
  )

documentDBUtils(config, processResponse)