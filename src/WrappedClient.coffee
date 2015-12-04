_ = require('lodash')

delay = (ms, func) ->
  setTimeout(func, ms)

wrapQueryIteratorMethodForAll = (_client, _method) ->
  f = (parameters...) ->
    iterator = _method.call(_client, parameters...)
    return iterator
  return f

WrappedQueryIterator = class
  constructor: (@_iterator, @defaultRetries) ->
    for methodName, _method of @_iterator
      if methodName in ['executeNext']
        this[methodName] = wrapCallbackMethod(@_iterator, _method, @defaultRetries)
      else
        this[methodName] = wrapSimpleMethod(@_iterator, _method)

wrapQueryIteratorMethod = (_client, _method, defaultRetries) ->
  f = (parameters...) ->
    _iterator = _method.call(_client, parameters...)
    return new WrappedQueryIterator(_iterator, defaultRetries)
  return f

wrapSimpleMethod = (that, _method) ->
  f = (parameters...) ->
    return _method.call(that, parameters...)
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
            console.log('Got 429')
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
  constructor: (@_client, @defaultRetries) ->
    unless @defaultRetries?
      @defaultRetries = 3
    for methodName, _method of @_client
      if typeof _method isnt 'function'
        continue
      else if methodName is 'executeStoredProcedure'
        this[methodName] = wrapExecuteStoredProcedure(@_client, _method, @defaultRetries)
      else if _.startsWith(methodName, 'create') or  # These all have a callback parameter
              _.startsWith(methodName, 'delete') or
              _.startsWith(methodName, 'execute') or
              _.startsWith(methodName, 'replace') or
              _.startsWith(methodName, 'update') or
              _.startsWith(methodName, 'upsert') or
              methodName is 'getDatabaseAccount' or
              methodName is 'queryFeed' or
              _.startsWith(methodName, 'read') and not _.endsWith(methodName, 's') or
              methodName in ['get', 'post', 'put', 'head', 'delete']
        this[methodName] = wrapCallbackMethod(@_client, _method, @defaultRetries)
      else if _.startsWith(methodName, 'query') or  # These all return a QueryIterator
              _.startsWith(methodName, 'read') and _.endsWith(methodName, 's')
        this[methodName] = wrapQueryIteratorMethod(@_client, _method, @defaultRetries)
        this[methodName + 'All'] = wrapQueryIteratorMethodForAll(@_client, _method, @defaultRetries)
      else  # When I checked, these were all functions that had neither callbacks or returned QueryIterator. They appear to be utility functions.
        # do nothing

