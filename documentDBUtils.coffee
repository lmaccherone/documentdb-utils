# getOrCreateDatabase and getOrCreateCollection were originally adapted from:
# http://azure.microsoft.com/en-us/documentation/articles/documentdb-nodejs-application/
# Other functionality here is my own.

# !TODO: Need to paramaterize offerType and other options in here
# !TODO: Write a stored procedure that will get all context(SPs, UDFs, and Triggers) of a collection

DocumentClient = require("documentdb").DocumentClient

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

###*
# Main function. You can pretty much do everything by calling this with the desired configuration.
# @param {object} userConfig Your configuration

###
documentDBUtils = (userConfig, callback) ->
  options =
    client: "If you've already instantiated the DocumentClient pass it in with this."
    auth: 'Allow for full configuration of auth per DocumentClient API.'
    masterKey: 'Will pull from DOCUMENT_DB_KEY environment variable if not specified.'
    urlConnection: 'Will pull from DOCUMENT_DB_URL environment variable if not specified.'

    database: "If you've already fetched it, use this."
    databaseLink: "Alternatively, use the self link."
    databaseID: 'Readable ID.'

    collection: "If you've already fetched it, use this."
    collectionLink: "Alternatively, use the self link."
    collectionID: 'Readable ID.'

    storedProcedure: "If you've already fetched it, use this."
    storedProcedureLink: "Alternatively, use the self link."
    storedProcedureID: 'Readable ID.'
    storedProcedureJS: 'The JavaScript or its toString()'
    memo: 'Object containing parameters and initial memo values for stored procedure. Must send at least {} to trigger execution.'  # Note, in CS {}? is true, null? and undefined? are false

    debug: 'Default: false. Set to true if you want progress messages.'

    # !TODO: Add UDFs and Triggers
    # !TODO: Add create, update, replace, delete documents. How to tell the difference between update and replace

  config = utils.clone(userConfig)
  config.debug = config.debug or false

  executionRoundTrips = 0
  startTick = new Date().getTime()
  executionStartTick = null
  timeLostToThrottling = 0

  debug = (message, content) ->
    if config.debug
      console.log(message)
      if content?
        console.dir(content)
        console.log()

  # Get client
  unless config.client?
    unless config.urlConnection?
      urlConnection = process.env.DOCUMENT_DB_URL
      if urlConnection?
        config.urlConnection = urlConnection
      else
        callCallback('Missing urlConnection.')
    unless config.auth?
      masterKey = process.env.DOCUMENT_DB_KEY
      if masterKey?
        config.auth =
          masterKey: masterKey
      else
        callCallback('Missing auth or masterKey.')
    config.client = new DocumentClient(config.urlConnection, config.auth)

  trySomething = () ->
    debug('trySomething()')

    if config.collectionLink? or config.storedProcedureLink?  # !TODO: Add or triggerLink? and udfLink?
      if tryStoredProcedure()
        # do nothing but verbose
  #    else if tryUDF()
  #      # verbose
  #    else if tryTrigger()
  #      # verbose
  #    else if tryDocumentOperations()
  #      # verbose
      else
        callCallback('No stored procedure, trigger, UDF or document operations specified.')
    else
      getCollectionLink()

  tryStoredProcedure = () ->
    debug('tryStoredProcedure()')
    if config.storedProcedureJS?
      upsertStoredProcedure()
      return true
    else if config.storedProcedureLink?
      debug("storedProcedureLink", config.storedProcedureLink)
      deleteOrExecuteStoredProcedure()
      return true
    else if config.storedProcedure?
      config.storedProcedureLink = config.storedProcedure._self
      debug("storedProcedure", config.storedProcedure)
      executeStoredProcedure()
      return true
    else if config.storedProcedureID?
      debug("storedProcedureID", config.storedProcedureID)
      getStoredProcedureFromID()
      return true
    else
      return false

  delay = (ms, func) ->
    setTimeout(func, ms)

  processError = (err, header, toRetryIf429, nextIfNot429 = null) ->
    debug('processError()')
    if err.code is 429
      retryAfter = Number(header['x-ms-retry-after-ms'])
      timeLostToThrottling += retryAfter
      debug("Throttled. Retrying after delay of #{retryAfter}ms")
      delay(retryAfter, toRetryIf429)
    else if nextIfNot429?
      nextIfNot429()
    else
      callCallback(err)

  getStoredProcedureFromID = () ->
    debug('getStoredProcedureFromID()')
    debug('collectionLink', config.collectionLink)
    documentDBUtils.fetchStoredProcedure(config.client, config.collectionLink, config.storedProcedureID, (err, response, header) ->
      if err?
        processError(err, header, getStoredProcedureFromID, upsertStoredProcedure)
      else
        debug("response from call to fetchStoredProcedure in getStoredProcedureFromID", response)
        config.storedProcedure = response
        config.storedProcedureLink = response._self
        deleteOrExecuteStoredProcedure()
    )

  upsertStoredProcedure = () ->
    debug('upsertStoredProcedure()')
    unless config.storedProcedureID?
      callCallback('Missing storedProcedureID')
    unless config.storedProcedureJS?
      callCallback('Missing storedProcedureJS')
    documentDBUtils.upsertStoredProcedure(config.client, config.collectionLink, config.storedProcedureID, config.storedProcedureJS, (err, response, header) ->
      if err?
        processError(err, header, upsertStoredProcedure)
      else
        config.storedProcedure = response
        config.storedProcedureLink = response._self
        executeStoredProcedure()
    )

  deleteOrExecuteStoredProcedure = () ->
    debug('deleteOrExecuteStoredProcedure()')
    if config.memo?
      unless executionStartTick?
        executionStartTick = new Date().getTime()
      config.client.executeStoredProcedure(config.storedProcedureLink, config.memo, processResponse)
    else
      config.client.deleteStoredProcedure(config.storedProcedureLink, (err, response, header) ->
        if err?
          processError(err, header, deleteOrExecuteStoredProcedure)
        else
          debug('Stored Procedure Deleted')
          callCallback(null)
      )

  executeStoredProcedure = () ->
    debug('executeStoredProcedure()')
    if config.memo?
      unless executionStartTick?
        executionStartTick = new Date().getTime()
      config.client.executeStoredProcedure(config.storedProcedureLink, config.memo, processResponse)
    else
      callCallback(null)

  processResponse = (err, response, header) ->
    debug('processResponse()')
    debug('err', err)
    debug('response', response)
    debug('header', header)
    if err?
      processError(err, header, executeStoredProcedure)
    else
      executionRoundTrips++
      config.memo = response
      if response.continuation?

        if response.stillResources
          executeStoredProcedure()
        else
          deleteAndUpsertStoredProcedure()
      else
        callCallback(null)

  deleteAndUpsertStoredProcedure = () ->
    # This is a total hack to overcome the fact that when you get an out of resources (false) response when you
    # do any operations on a collection from inside of your stored procedure. According to this:
    #   http://stackoverflow.com/questions/29978925/documentdb-stored-procedure-blocked
    # this might be a bug. If it gets fixed, we can remove this hack.
    debug('Got out of resources messages on this stored procedure. Deleting and upserting.')
    config.storedProcedureJS = config.storedProcedureJS or config.storedProcedure?.body
    if config.storedProcedureJS?
      config.client.deleteStoredProcedure(config.storedProcedureLink, (err, response, header) ->
        if err?
          processError(err, header, deleteAndUpsertStoredProcedure)
        else
          delete config.storedProcedure
          delete config.storedProcedureLink
          upsertStoredProcedure()
      )
    else
      callCallback('Need storedProcedureJS to overcome resource constraint.')  # !TODO: We could actually fetch it if it's missing here

  getCollectionLink = () ->
    debug('getCollectionLink()')
    if config.collectionLink?
      debug("collectionLink", config.collectionLink)
      trySomething()
    else if config.collection?
      debug("collection", config.collection)
      config.collectionLink = config.collection._self
      trySomething()
    else if config.collectionID?
      debug("collectionID", config.collectionID)
      if config.databaseLink?
        documentDBUtils.getOrCreateCollection(config.client, config.databaseLink, config.collectionID, (err, response, header) ->
          if err?
            processError(err, header, getCollectionLink)
          else
            debug('response from call to getOrCreateCollection in getCollectionLink', response)
            config.collection = response
            config.collectionLink = response._self
            trySomething()
        )
      else
        getDatabaseLink()
    else
      callCallback('Missing collection information.')

  getDatabaseLink = () ->
    debug('getDatabaseLink()')
    if config.databaseLink?
      trySomething()
    else if config.database?
      config.databaseLink = config.database._self
      trySomething()
    else if config.databaseID?
      debug('calling')
      documentDBUtils.getOrCreateDatabase(config.client, config.databaseID, (err, response, header) ->
        if err?
          processError(err, header, getDatabaseLink)
        else
          debug('response to call to getOrCreateDatabase in getDatabaseLink', response)
          config.database = response
          config.databaseLink = response._self
          trySomething()
      )
    else
      callCallback('Missing database information.')

  callCallback = (err) ->
    endTick = new Date().getTime()
    stats = {}
    debug("\n")
    if executionStartTick?
      stats.executionRoundTrips = executionRoundTrips
      stats.setupTime = executionStartTick - startTick
      stats.executionTime = endTick - executionStartTick
      stats.timeLostToThrottling = timeLostToThrottling
      debug("Execution round trips (not counting setup or throttling errors): #{stats.executionRoundTrips}")
      debug("Setup time: #{stats.setupTime}ms")
      debug("Execution time: #{stats.executionTime}ms")
      debug("Time lost to throttling: #{stats.timeLostToThrottling}ms")
    stats.totalTime = endTick - startTick
    debug("Total time: #{stats.totalTime}ms")
    config.stats = stats
    callback(err, config)

  trySomething()

###*
# If it exists, this will fetch the database. If it does not exist, it will create the database.
# @param {Client} client
# @param {string} databaseID
# @param {callback} callback
###
documentDBUtils.getOrCreateDatabase = (client, databaseID, callback) ->
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

documentDBUtils.getOrCreateCollection = (client, databaseLink, collectionID, callback) ->
  querySpec =
    query: "SELECT * FROM root r WHERE r.id=@id"
    parameters: [{name: "@id", value: collectionID}]

  client.queryCollections(databaseLink, querySpec).toArray((err, results) ->
    if err
      callback(err)
    else
      if results.length is 0
        collectionSpec = id: collectionID
        requestOptions = offerType: "S1"
        client.createCollection(databaseLink, collectionSpec, requestOptions, (err, created) ->
          if err
            callback(err)
          else
            callback(null, created)
        )
      else
        callback(null, results[0])
  )

documentDBUtils.upsertStoredProcedure = (client, collectionLink, storedProcID, storedProc, callback) ->  # !TODO: Upgrade to use fetchStoredProcedure
  querySpec =
    query: "SELECT * FROM root r WHERE r.id=@id"
    parameters: [{name: "@id", value: storedProcID}]

  client.queryStoredProcedures(collectionLink, querySpec).toArray((err, results) ->
    if err
      callback(err)
    else
      storedProcSpec = {id: storedProcID, body: storedProc}
      if results.length is 0
        client.createStoredProcedure(collectionLink, storedProcSpec, (err, created) ->
          if err
            callback(err)
          else
            callback(null, created)
        )
      else
        sprocLink = results[0]._self
        client.replaceStoredProcedure(sprocLink, storedProcSpec, (err, replaced) ->
          if err
            callback(err)
          else
            callback(null, replaced)
        )
  )

documentDBUtils.fetchStoredProcedure = (client, collectionLink, storedProcID, callback) ->
  querySpec =
    query: "SELECT * FROM root r WHERE r.id=@id"
    parameters: [{name: "@id", value: storedProcID}]

  client.queryStoredProcedures(collectionLink, querySpec).toArray((err, results) ->
    if err
      callback(err)
    else if results.length is 0
      callback("Could not find stored procedure #{storedProcID}.")
    else
      callback(null, results[0])
  )


exports.documentDBUtils = documentDBUtils