{documentDBUtils} = require('./documentDBUtils')

filterQuery = null
#filterQuery = "SELECT * FROM c WHERE c.Severity = 2"

{count} = require('./count')
config =
  databaseID: 'test-stored-procedure'
  collectionID: 'test-stored-procedure'
  storedProcedureID: 'count'
  storedProcedureJS: count
  memo: {filterQuery}
  debug: false

processResponse = (err, response) ->
  if err?
    console.dir(err)
    throw new Error(err)

  # At this point, response has all of the config information that documentDBUtils needed to acquire to do what you
  # asked it to do.
  #
  # It are also contains two addtional fields:
  # 1) `stats` containing timings about the execution; and
  # 2) `memo` the output of the stored procedure

  console.log(response.stats)
  console.log(response.memo)

documentDBUtils(config, processResponse)