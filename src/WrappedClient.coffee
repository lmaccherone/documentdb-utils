_ = require('lodash')
async = require('async')
{DocumentClient} = require('documentdb')

delay = (ms, func) ->
  setTimeout(func, ms)

RETRY_ERROR_CODES = [429, 449, 503]
MAC_SIGNATURE_STRING = "The MAC signature found"

isRetryError = (err) ->
 return err.code in RETRY_ERROR_CODES or (err.code is 401 and err.body.indexOf(MAC_SIGNATURE_STRING) >= 0)

WrappedQueryIterator = class
  constructor: (@_iterator, retriesAllowed) ->
    for methodName, _method of @_iterator
      if methodName in ['executeNext', 'forEach', 'nextItem']
        this[methodName] = wrapCallbackMethod(@_iterator, _method, retriesAllowed)
      else if methodName is 'toArray'
        this[methodName] = wrapToArray(this)
      else
        this[methodName] = wrapSimpleMethod(@_iterator, _method)

wrapQueryIteratorMethod = (_client, _method, retriesAllowed) ->
  f = (parameters...) ->
    _iterator = _method.call(_client, parameters...)
    return new WrappedQueryIterator(_iterator, retriesAllowed)
  return f

wrapQueryIteratorMethodForArray = (_client, _method, retriesAllowed) ->
  f = (parameters...) ->
    callback = parameters.pop()
    _iterator = _method.call(_client, parameters...)
    iterator = new WrappedQueryIterator(_iterator, retriesAllowed)
    return iterator.toArray(callback)
  return f

wrapToArray = (iterator) ->
  f = (callback) ->
    all = []
    stats = {roundTripCount: 0, retries: 0, requestUnitCharges: 0, totalDelay: 0, totalTime: 0}
    innerF = () ->
      iterator.executeNext((err, response, headers, roundTripCount, retries, totalDelay, totalTime) ->
        if err?
          callback(err, response, headers, retries)
        else
          stats.roundTripCount++
          stats.retries += retries
          stats.requestUnitCharges += Number(headers['x-ms-request-charge']) or 0
          stats.totalDelay += totalDelay
          stats.totalTime += totalTime
          all = all.concat(response)
          if iterator.hasMoreResults()
            innerF()
          else
            callback(err, all, stats)
      )
    return innerF()
  return f

wrapSimpleMethod = (that, _method) ->
  f = (parameters...) ->
    return _method.call(that, parameters...)
  return f

wrapToCreateAsyncJSIterator = (that, _method) ->
  f = (item, callback) ->
    return _method.call(that, item..., (err, response, headers, roundTripCount, retries, totalDelay, totalTime) ->
      callback(err, {response, headers, roundTripCount, retries, totalDelay, totalTime})
    )
  return f

wrapToCreateArrayAsyncJSIterator = (that, _method) ->
  f = (item, callback) ->
    return _method.call(that, item..., (err, all, stats) ->
      callback(err, all, stats)
    )
  return f

reduceResults = (memo, result) ->
  unless memo?
    memo = {}
  for key, value of result
    if _.isArray(value)
      if memo[key]?
        memo[key] = memo[key].concat(value)
      else
        memo[key] = value
    else if _.isNumber(value)
      if memo[key]?
        memo[key] += value
      else
        memo[key] = value
    else if _.isPlainObject(value)
      if memo[key]?
        memo[key].push(value)
      else
        memo[key] = [value]
  return memo

wrapMultiMethod = (that, asyncJSIterator) ->
  f = (parameters...) ->
    callback = parameters.pop()
    linkArray = parameters.shift()
    unless _.isArray(linkArray)
      linkArray = [linkArray]
    items = ([link].concat(parameters) for link in linkArray)
    return async.map(items, asyncJSIterator, (err, results) ->
      accumulatedResults = {}
      for result in results
        accumulatedResults = reduceResults(accumulatedResults, result)
      callback(err, accumulatedResults)
    )
  return f

wrapCallbackMethod = (that, _method, retriesAllowed) ->
  f = (parameters...) ->
    startTime = new Date()
    roundTripCount = 0
    retries = 0
    totalDelay = 0
    callback = parameters.pop()
    innerF = (parameters...) ->
      return _method.call(that, parameters..., (err, response, headers) ->
        roundTripCount++
        if err?
          if isRetryError(err) and retries <= retriesAllowed
            retryAfter = headers['x-ms-retry-after-ms'] or 0
            retryAfter = Number(retryAfter)
            retries++
            totalDelay += retryAfter
            delay(retryAfter, () ->
              innerF(parameters...)
            )
            return
          else
            callback(err, response, headers, roundTripCount, retries, totalDelay, new Date() - startTime)
        else
          callback(err, response, headers, roundTripCount, retries, totalDelay, new Date() - startTime)
      )
    return innerF(parameters...)
  return f

wrapExecuteStoredProcedure = (that, _method, retriesAllowed) ->
  f = (parameters...) ->
    startTime = new Date()
    roundTripCount = 0
    retries = 0
    totalDelay = 0
    callback = parameters.pop()
    innerF = (parameters...) ->
      return _method.call(that, parameters..., (err, response, headers) ->
        roundTripCount++
        if err?
          if isRetryError(err) and retries <= retriesAllowed
            retryAfter = headers['x-ms-retry-after-ms'] or 0
            retryAfter = Number(retryAfter)
            retries++
            totalDelay += retryAfter
            delay(retryAfter, () ->
              innerF(parameters...)
            )
            return
          else
            callback(err, response, headers, roundTripCount, retries, totalDelay, new Date() - startTime)
        else
          if response.continuation?
            parameters[1] = response
            innerF(parameters...)
          else
            callback(err, response, headers, roundTripCount, retries, totalDelay, new Date() - startTime)
      )
    return innerF(parameters...)
  return f

module.exports = class WrappedClient
  constructor: (@urlConnection, @auth, @connectionPolicy, @consistencyLevel) ->
    if @urlConnection?.readDocuments? and @urlConnection?.queryDocuments?
      @_client = @urlConnection
    else
      @urlConnection = @urlConnection or process.env.DOCUMENT_DB_URL
      masterKey = process.env.DOCUMENT_DB_KEY
      @auth = @auth or {masterKey}
      @_client = new DocumentClient(@urlConnection, @auth, @connectionPolicy, @consistencyLevel)

    @retriesAllowed = 3
    for methodName, _method of @_client
      if typeof _method isnt 'function'
        continue

      hasArrayVersion = _.startsWith(methodName, 'query') or
                        _.startsWith(methodName, 'read') and _.endsWith(methodName, 's')
      methodSpec = _method.toString().split('\n')[0]
      indexOfLeftParen = methodSpec.indexOf('(')
      indexOfRightParen = methodSpec.indexOf(')')
      parameterListString = methodSpec.substr(indexOfLeftParen + 1, indexOfRightParen - indexOfLeftParen - 1)
      parameterList = parameterListString.split(', ')

      firstParameterIsLink = _.endsWith(parameterList[0], 'Link')
      lastParameterIsCallback = parameterList[parameterList.length - 1] is 'callback'

      if methodName is 'executeStoredProcedure'
        this[methodName] = wrapExecuteStoredProcedure(@_client, _method, @retriesAllowed)
      else if lastParameterIsCallback
        this[methodName] = wrapCallbackMethod(@_client, _method, @retriesAllowed)
      else if hasArrayVersion
        this[methodName] = wrapQueryIteratorMethod(@_client, _method, @retriesAllowed)
        this[methodName + 'Array'] = wrapQueryIteratorMethodForArray(@_client, _method, @retriesAllowed)  # TODO: Maybe we should replace _method with this[methodName]. Need tests to confirm.

      else  # When I checked, these were all functions that had neither callbacks nor returned QueryIterator. They appear to be utility functions.
        # do nothing

      if firstParameterIsLink
        if hasArrayVersion
          methodNameToWrap = methodName + 'Array'
          asyncJSMethod = wrapToCreateArrayAsyncJSIterator(this, this[methodNameToWrap])
        else
          methodNameToWrap = methodName
          asyncJSMethod = wrapToCreateAsyncJSIterator(this, this[methodNameToWrap])
        this[methodNameToWrap + 'AsyncJSIterator'] = asyncJSMethod
        this[methodNameToWrap + 'Multi'] = wrapMultiMethod(this, asyncJSMethod)


