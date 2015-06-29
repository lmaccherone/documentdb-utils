documentDBUtils = require('../documentDBUtils')

utils = {}
utils.clone = (obj) ->
  if not obj? or typeof obj isnt 'object'
    return obj

  if obj instanceof Date
    return new Date(obj.getTime())

  if obj instanceof RegExp
    flags = ''
    flags += 'g' if obj.global?
    flags += 'i' if obj.ignoreCase?
    flags += 'm' if obj.multiline?
    flags += 'y' if obj.sticky?
    return new RegExp(obj.source, flags)

  newInstance = new obj.constructor()

  for key of obj
    newInstance[key] = utils.clone(obj[key])

  return newInstance

oldDocument = {
  a: 1,
  b: 2,
  id: 'f23b58e2-2e0d-fae6-d683-f6c1c33293cc',
  _rid: 'dF0DAMkaDQCaCAAAAAAAAA==',
  _ts: 1435525097,
  _self: 'dbs/dF0DAA==/colls/dF0DAMkaDQA=/docs/dF0DAMkaDQCaCAAAAAAAAA==/',
  _etag: '"00002300-0000-0000-0000-55905fe90000"',
  _attachments: 'attachments/'
}
document = utils.clone(oldDocument)
document.a = 100
document.b = 200

config =
  databaseID: 'test-stored-procedure'
  collectionID: 'test-stored-procedure'
  oldDocument: oldDocument
  document: document
  debug: false

documentDBUtils(config, (err, response) ->
  if err
    throw err
  console.log(response.stats)
  console.log(response.document)
)