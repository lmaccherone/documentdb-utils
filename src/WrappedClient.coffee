_ = require('lodash')

delay = (ms, func) ->
  setTimeout(func, ms)

wrapQueryIteratorMethodForAll = (_client, _method) ->
  f = (parameters...) ->
    iterator = _method.call(_client, parameters...)
    return iterator
  return f

wrapQueryIteratorMethod = (_client, _method) ->
  f = (parameters...) ->
    iterator = _method.call(_client, parameters...)
    return iterator
  return f

wrapCallbackMethod = (_client, _method) ->
  f = (parameters...) ->
    callback = parameters.pop()
    firstResponse = null
    innerF = (retriesLeft = 3, parameters...) ->
      return _method.call(_client, parameters..., (err, response, headers) ->
        if response? and not firstResponse?
          firstResponse = response
        if err?
          if err.code in [429, 449] and retriesLeft > 0
            retryAfter = headers['x-ms-retry-after-ms'] or 1
            delay(retryAfter, () ->
              console.log('retrying')
              innerF(retriesLeft - 1, parameters...)
            )
            return
          else
            callback(err, response or firstResponse, headers)
        else
          callback(err, response, headers)
      )
    return innerF(null, parameters...)
  return f

module.exports = class WrappedClient
  constructor: (@_se, @_client) ->
    for methodName, _method of @_client
      if typeof _method isnt 'function'
        # do nothing
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
        this[methodName] = wrapCallbackMethod(@_client, _method)
      else if _.startsWith(methodName, 'query') or  # These all return a QueryIterator
              _.startsWith(methodName, 'read') and _.endsWith(methodName, 's')
        this[methodName] = wrapQueryIteratorMethod(@_client, _method)
        this[methodName + 'All'] = wrapQueryIteratorMethodForAll(@_client, _method)
      else  # When I checked, these were all functions that had neither callbacks or returned QueryIterator. They appear to be utility functions.
        # do nothing

