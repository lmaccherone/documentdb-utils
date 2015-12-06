_ = require('lodash')
async = require('async')
{DocumentClient} = require('documentdb')

delay = (ms, func) ->
  setTimeout(func, ms)

WrappedQueryIterator = class
  constructor: (@_iterator, @defaultRetries) ->
    for methodName, _method of @_iterator
      if methodName in ['executeNext', 'forEach', 'nextItem']
        this[methodName] = wrapCallbackMethod(@_iterator, _method, @defaultRetries)
      else if methodName is 'toArray'
        this[methodName] = wrapToArray(this)
      else
        this[methodName] = wrapSimpleMethod(@_iterator, _method)

wrapQueryIteratorMethod = (_client, _method, defaultRetries) ->
  f = (parameters...) ->
    _iterator = _method.call(_client, parameters...)
    return new WrappedQueryIterator(_iterator, defaultRetries)
  return f

wrapQueryIteratorMethodForArray = (_client, _method, defaultRetries) ->
  f = (parameters...) ->
    callback = parameters.pop()
    _iterator = _method.call(_client, parameters...)
    iterator = new WrappedQueryIterator(_iterator, defaultRetries)
    return iterator.toArray(callback)
  return f

wrapToArray = (iterator) ->
  f = (callback) ->
    all = []
    pages = 0
    innerF = () ->
      iterator.executeNext((err, response, headers, retries) ->
        if err?
          callback(err, response, headers, pages)
        else
          pages++
          all = all.concat(response)
          if iterator.hasMoreResults()
            innerF()
          else
            callback(err, all, headers, pages)
      )
    return innerF()
  return f

wrapSimpleMethod = (that, _method) ->
  f = (parameters...) ->
    return _method.call(that, parameters...)
  return f

wrapToCreateAsyncJSIterator = (that, _method) ->
  f = (item, callback) ->
    return _method.call(that, item..., (err, response, headers, other) ->
      callback(err, {response, headers, other})
    )
  return f

wrapMultiMethod = (that, asyncJSIterator) ->
  f = (parameters...) ->
    callback = parameters.pop()
    linkArray = parameters.shift()
    unless _.isArray(linkArray)
      linkArray = [linkArray]
    items = ([link].concat(parameters) for link in linkArray)
    return async.map(items, asyncJSIterator, (err, results) ->
      concatenatedResults = []
      stats = {roundTripCount: 0, itemCount: 0, requestUnitCharges: 0}
      for result in results
        if _.isArray(result.response)
          concatenatedResults = concatenatedResults.concat(result.response)
        else
          concatenatedResults.push(result.response)
        headers = result.headers
        stats.roundTripCount += result.other
        stats.itemCount += Number(headers['x-ms-item-count'])
        stats.requestUnitCharges += Number(headers['x-ms-request-charge'])
      if _.isNaN(stats.roundTripCount)
        delete stats.roundTripCount
      if _.isNaN(stats.itemCount)
        delete stats.itemCount
      callback(err, concatenatedResults, stats)
    )
  return f

wrapCallbackMethod = (that, _method, defaultRetries) ->
  retries = 0
  f = (parameters...) ->
    callback = parameters.pop()
    innerF = (retriesLeft = defaultRetries, parameters...) ->
      return _method.call(that, parameters..., (err, response, headers) ->
        if err?
          if err.code in [429, 449] and retriesLeft > 0
            retryAfter = headers['x-ms-retry-after-ms'] or 1
            retryAfter = Number(retryAfter)
            retries++
            delay(retryAfter, () ->
              innerF(retriesLeft - 1, parameters...)
            )
            return
          else
            callback(err, response, headers, retries)
        else
          callback(err, response, headers, retries)
      )
    return innerF(null, parameters...)
  return f

wrapExecuteStoredProcedure = (_client, _method, defaultRetries) ->
  f = (parameters...) ->
    callback = parameters.pop()
    innerF = (retriesLeft = defaultRetries, parameters...) ->
      return _method.call(_client, parameters..., (err, response, headers) ->
        if err?
          if err.code in [429, 449] and retriesLeft > 0
            retryAfter = headers['x-ms-retry-after-ms'] or 1
            retryAfter = Number(retryAfter)
            delay(retryAfter, () ->
              innerF(retriesLeft - 1, parameters...)
            )
            return
          else
            callback(err, response, headers)
        else
          if response.continuation?
            parameters[1] = response
            innerF(null, parameters...)
          else
            callback(err, response, headers)
      )
    return innerF(null, parameters...)
  return f

module.exports = class WrappedClient
  constructor: (@urlConnection, @auth, @connectionPolicy, @consistencyLevel) ->
    if @urlConnection instanceof DocumentClient
      @_client = @urlConnection
    else
      @urlConnection = @urlConnection or process.env.DOCUMENT_DB_URL
      masterKey = process.env.DOCUMENT_DB_KEY
      @auth = @auth or {masterKey}
      @_client = new DocumentClient(@urlConnection, @auth, @connectionPolicy, @consistencyLevel)

    @defaultRetries = 3
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
        this[methodName] = wrapExecuteStoredProcedure(@_client, _method, @defaultRetries)
      else if lastParameterIsCallback
        this[methodName] = wrapCallbackMethod(@_client, _method, @defaultRetries)
      else if hasArrayVersion
        this[methodName] = wrapQueryIteratorMethod(@_client, _method, @defaultRetries)
        this[methodName + 'Array'] = wrapQueryIteratorMethodForArray(@_client, _method, @defaultRetries)

      else  # When I checked, these were all functions that had neither callbacks nor returned QueryIterator. They appear to be utility functions.
        # do nothing

      if firstParameterIsLink
        if hasArrayVersion
          methodNameToWrap = methodName + 'Array'
        else
          methodNameToWrap = methodName

        asyncJSMethod = wrapToCreateAsyncJSIterator(this, this[methodNameToWrap])
        this[methodNameToWrap + 'AsyncJSIterator'] = asyncJSMethod
        this[methodNameToWrap + 'Multi'] = wrapMultiMethod(this, asyncJSMethod)


