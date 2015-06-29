documentDBUtils = require('../documentDBUtils')

config =
  databaseID: 'test-stored-procedure'
  collectionID: 'test-stored-procedure'
  documentLink: 'dbs/dF0DAA==/colls/dF0DAMkaDQA=/docs/dF0DAMkaDQCcCAAAAAAAAA==/'
  oldDocument: {_etag: '"00002700-0000-0000-0000-5590b4a80000"'}
  debug: false

documentDBUtils(config, (err, response) ->
  if err
    throw new Error(JSON.stringify(err))
  console.log(response.stats)
  console.log("Document deleted:", response.documentLink)
)