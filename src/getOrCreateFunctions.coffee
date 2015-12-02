# getOrCreateDatabase and getOrCreateCollection were originally adapted from:
# http://azure.microsoft.com/en-us/documentation/articles/documentdb-nodejs-application/
# Other functionality here is my own.



utils = {}
utils.clone = (obj) ->
  if not obj? or typeof(obj) isnt 'object'
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


###*
# If it exists, this will fetch the database. If it does not exist, it will create the database.
# @param {Client} client
# @param {string} databaseID
# @param {callback} callback
###
module.exports.getOrCreateDatabase = (client, databaseID, callback) ->
  querySpec =
    query: "SELECT * FROM root r WHERE r.id=@id"
    parameters: [{name: "@id", value: databaseID}]

  client.queryDatabases(querySpec).toArray((err, results) ->
    if err
      callback(err)
    else
      if results.length is 0
        databaseSpec = id: databaseID
        client.createDatabase(databaseSpec, (err, created) ->
          if err
            callback(err)
          else
            callback(null, created)
        )
      else
        callback(null, results[0])
  )

module.exports.getOrCreateCollection = (client, databaseLink, collectionID, callback) ->
  querySpec =
    query: "SELECT * FROM root r WHERE r.id=@id"
    parameters: [{name: "@id", value: collectionID}]

  client.queryCollections(databaseLink, querySpec).toArray((err, results) ->
    if err
      callback(err)
    else
      if results.length is 0
        collectionSpec = id: collectionID
        offerType = config.offerType or "S1"
        requestOptions = {offerType}
        client.createCollection(databaseLink, collectionSpec, requestOptions, (err, created) ->
          if err
            callback(err)
          else
            callback(null, created)
        )
      else
        callback(null, results[0])
  )






module.exports = documentDBUtils