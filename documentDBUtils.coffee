# getOrCreateDatabase and getOrCreateCollection were originally adapted from:
# http://azure.microsoft.com/en-us/documentation/articles/documentdb-nodejs-application/
# Other functionality here is my own.

# !TODO: I already parameterized offerType for collection creation, but need to add other requestOptions for triggers, sessions, etc. see: http://dl.windowsazure.com/documentDB/nodedocs/global.html#RequestOptions
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

    offerType: 'offerType to use when creating a new collection'

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
  totalRequestCharges = 0

  debug = (message, content) ->
    if config.debug
      console.log(message)
      if content?
        console.dir(content)
        console.log()

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
    stats.totalRequestCharges = totalRequestCharges
    debug("Total request charges: #{stats.totalRequestCharges} RUs")
    config.stats = stats
    callback(err, config)

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

    if config.collectionLink? or config.storedProcedureLink?  # !TODO: Add "or triggerLink? or udfLink?"
      if tryStoredProcedure()
        # do nothing but verbose
  #    else if tryUDF()
  #      # verbose
  #    else if tryTrigger()
  #      # verbose
      else if config.document? and !config.oldDocument? and !config.documentLink?
        createDocument()
      else
        callCallback('No stored procedure or document create operation specified.')
    else if config.documentLink? or config.oldDocument?
      if !config.documentLink? and !config.oldDocument and config.document?
        createDocument()
      else if config.documentLink? and !config.oldDocument and !config.document?
        readDocument()
      else if config.documentLink? and config.oldDocument and config.document?
        updateDocument()
      else if !config.documentLink? and config.oldDocument and config.document?
        updateDocument()
      else if config.oldDocument and !config.document?
        deleteDocument()  # Needs to get documentLink from oldDocument if missing
    else if config.document? and config.collectionLink?
      createDocument()
    else
      getCollectionLink()

  tryStoredProcedure = () ->
    debug('tryStoredProcedure()')
    if config.storedProcedureJS?
      tryUpsertStoredProcedure()
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
      retryAfterHeader = header['x-ms-retry-after-ms'] or 1
      retryAfter = Number(retryAfterHeader)
      timeLostToThrottling += retryAfter
      debug("Throttled. Retrying after delay of #{retryAfter}ms")
      delay(retryAfter, toRetryIf429)
    else if nextIfNot429?
      nextIfNot429()
    else
      callCallback(err)

  createDocument = () ->
    debug('createDocument()')
    config.client.createDocument(config.collectionLink, config.document, (err, response, header) ->
      if header?['x-ms-request-charge']?
        totalRequestCharges += Number(header['x-ms-request-charge'])
      if err?
        processError(err, header, createDocument)
      else
        config.document = response
        callCallback(null)
    )

  readDocument = () ->
    debug('readDocument()')
    debug('documentLink', config.documentLink)
    config.client.readDocument(config.documentLink, (err, response, header) ->
      if header?['x-ms-request-charge']?
        totalRequestCharges += Number(header['x-ms-request-charge'])
      if err?
        processError(err, header, readDocument)
      else
        config.document = response
        callCallback(null)
    )

  updateDocument = () ->
    debug('updateDocument()')
    # !TODO: Need to pull old fields from oldDocument before calling replaceDocument
    replaceDocument()

  replaceDocument = () ->
    debug('replaceDocument()')
    unless config.documentLink?
      config.documentLink = config.oldDocument._self
    if config.oldDocument?._self? and (config.documentLink isnt config.oldDocument._self)
      throw new Error("documentLink and oldDocument._self don't match")
    unless config.document.id?
      config.document.id = config.oldDocument.id
    if config.oldDocument.id? and (config.document.id isnt config.oldDocument.id)
      throw new Error("IDs don't match between document and oldDocument")
    if config.oldDocument?._etag?
      etag = config.oldDocument._etag
      replaceOptions = {etag, "if-match": etag}  # There is no indication in the docs that the DocumentDB node.js client supports etag/if-match optimistic concurrency but I'm including just in case
    console.log('config.document', config.document)
    config.client.replaceDocument(config.documentLink, config.document, replaceOptions, (err, response, header) ->
      if header?['x-ms-request-charge']?
        totalRequestCharges += Number(header['x-ms-request-charge'])
      if err?
        processError(err, header, replaceDocument)
      else
        config.document = response
        callCallback(null)
    )

  deleteDocument = () ->
    debug('deleteDocument()')
    unless config.documentLink?
      config.documentLink = config.oldDocument._self
    debug('documentLink', config.documentLink)
    if config.oldDocument?._etag?
      etag = config.oldDocument._etag
      deleteOptions = {etag, "if-match": etag}  # There is no indication in the docs that the DocumentDB node.js client supports etag/if-match optimistic concurrency but I'm including just in case
    config.client.deleteDocument(config.documentLink, deleteOptions, (err, response, header) ->
      if header?['x-ms-request-charge']?
        totalRequestCharges += Number(header['x-ms-request-charge'])
      if err?
        processError(err, header, readDocument)
      else
        config.document = response
        callCallback(null)
    )

  getStoredProcedureFromID = () ->
    debug('getStoredProcedureFromID()')
    debug('collectionLink', config.collectionLink)
    documentDBUtils.fetchStoredProcedure(config.client, config.collectionLink, config.storedProcedureID, (err, response, header) ->
      if header?['x-ms-request-charge']?
        totalRequestCharges += Number(header['x-ms-request-charge'])
      if err?
        processError(err, header, getStoredProcedureFromID, tryUpsertStoredProcedure)
      else
        debug("response from call to fetchStoredProcedure in getStoredProcedureFromID", response)
        config.storedProcedure = response
        config.storedProcedureLink = response._self
        deleteOrExecuteStoredProcedure()
    )

  tryUpsertStoredProcedure = () ->
    debug('tryUpsertStoredProcedure()')
    unless config.storedProcedureID?
      callCallback('Missing storedProcedureID')
    unless config.storedProcedureJS?
      callCallback('Missing storedProcedureJS')
    documentDBUtils.upsertStoredProcedure(config.client, config.collectionLink, config.storedProcedureID, config.storedProcedureJS, (err, response, header) ->
      if header?['x-ms-request-charge']?
        totalRequestCharges += Number(header['x-ms-request-charge'])
      if err?
        processError(err, header, tryUpsertStoredProcedure)
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
      config.client.executeStoredProcedure(config.storedProcedureLink, config.memo, processSPResponse)
    else
      config.client.deleteStoredProcedure(config.storedProcedureLink, (err, response, header) ->
        if header?['x-ms-request-charge']?
          totalRequestCharges += Number(header['x-ms-request-charge'])
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
      config.client.executeStoredProcedure(config.storedProcedureLink, config.memo, processSPResponse)
    else
      callCallback(null)

  processSPResponse = (err, response, header) ->
    debug('processSPResponse()')
    debug('err', err)
    debug('response', response)
    debug('header', header)
    if header?['x-ms-request-charge']?
      totalRequestCharges += Number(header['x-ms-request-charge'])
    if err?
      processError(err, header, executeStoredProcedure)
    else
      executionRoundTrips++
      config.memo = response
      if config.memo.stillQueueing is false  # This is different from !memo.stillQueueing because memo.stillQueueing may be missing
        deleteAndUpsertStoredProcedure()
      else if config.memo.continuation?
        executeStoredProcedure()
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
        if header?['x-ms-request-charge']?
          totalRequestCharges += Number(header['x-ms-request-charge'])
        if err?
          processError(err, header, deleteAndUpsertStoredProcedure)
        else
          delete config.storedProcedure
          delete config.storedProcedureLink
          tryUpsertStoredProcedure()
      )
    else
      # !TODO: Never tested the code below which fetches the storedProcedure before retrying the deleteAndUpsert
      documentDBUtils.fetchStoredProcedure(config.client, config.collectionLink, config.storedProcedureID, (err, response, header) ->
        if header?['x-ms-request-charge']?
          totalRequestCharges += Number(header['x-ms-request-charge'])
        if err?
          processError(err, header, deleteAndUpsertStoredProcedure)
        else
          config.storedProcedure = response
          config.storedProcedureLink = response._self
          config.storedProcedureJS = response.body
          deleteAndUpsertStoredProcedure()
      )

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
          if header?['x-ms-request-charge']?
            totalRequestCharges += Number(header['x-ms-request-charge'])
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
        if header?['x-ms-request-charge']?
          totalRequestCharges += Number(header['x-ms-request-charge'])
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

documentDBUtils.upsertStoredProcedure = (client, collectionLink, storedProcedureID, storedProcedureJS, callback) ->
  querySpec =
    query: "SELECT * FROM root r WHERE r.id=@id"
    parameters: [{name: "@id", value: storedProcedureID}]

  client.queryStoredProcedures(collectionLink, querySpec).toArray((err, results) ->
    if err
      callback(err)
    else
      storedProcedureSpec = {id: storedProcedureID, body: storedProcedureJS}
      if results.length is 0
        client.createStoredProcedure(collectionLink, storedProcedureSpec, (err, created) ->
          if err
            callback(err)
          else
            callback(null, created)
        )
      else
        storedProcedureLink = results[0]._self
        client.replaceStoredProcedure(storedProcedureLink, storedProcedureSpec, (err, replaced) ->
          if err
            callback(err)
          else
            callback(null, replaced)
        )
  )

documentDBUtils.fetchStoredProcedure = (client, collectionLink, storedProcedureID, callback) ->
  querySpec =
    query: "SELECT * FROM root r WHERE r.id=@id"
    parameters: [{name: "@id", value: storedProcedureID}]

  client.queryStoredProcedures(collectionLink, querySpec).toArray((err, results) ->
    if err
      callback(err)
    else if results.length is 0
      callback("Could not find stored procedure #{storedProcedureID}.")
    else
      callback(null, results[0])
  )


module.exports = documentDBUtils