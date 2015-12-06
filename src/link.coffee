path = require('path')
_ = require('lodash')

DEFAULT_PREFIXES = ['dbs', 'colls', 'sprocs']

combineTwoLevels = (prefixArray, valuesArray) ->
  if prefixArray.length is 1
    return valuesArray[0]
  if prefixArray.length is 0
    return undefined

  links = []
  firstPrefix = prefixArray.shift()
  firstArray = valuesArray.shift()
  if _.isString(firstArray)
    firstArray = [firstArray]
  secondPrefix = prefixArray.shift()
  secondArray = valuesArray.shift()
  if _.isString(secondArray)
    secondArray = [secondArray]
  for f in firstArray
    for s in secondArray
      if firstPrefix?
        links.push(firstPrefix + '/' + f + '/' + secondPrefix + '/' + s)
      else
        links.push(f + '/' + secondPrefix + '/' + s)

  if prefixArray.length > 0
    valuesArray.unshift(links)
    prefixArray.unshift(null)
    return combineTwoLevels(prefixArray, valuesArray)
  else
    return links


getLinkArray = (parameters...) ->
  if parameters[parameters.length - 1][0] is 'dbs'
    defaultPrefixes = parameters.pop()
  else
    defaultPrefixes = _.cloneDeep(DEFAULT_PREFIXES)
  prefixArray = []
  valuesArray = []
  defaultStillValid = true
  if parameters.length is 1
    list = parameters[0]
    if not _.isArray(list)
      list = [list]
    return ('dbs/' + value for value in list)
  else
    for parameter, i in parameters
      if _.isPlainObject(parameter)
        keys = _.keys(parameter)
        if keys.length > 1
          throw new Error("Parameters of type object must only have one key/value pair.")
        defaultStillValid = false
        prefixArray.push(keys[0])
        valuesArray.push(_.values(parameter)[0])
      else
        if _.isString(parameter)
          parameter = [parameter]
        if defaultStillValid
          firstValue = parameter[0] or parameter
          firstValue = firstValue.toString()
          if firstValue.indexOf('/') < 0
            prefixArray.push(defaultPrefixes.shift())
          else
            segments = firstValue.split('/')
            while defaultPrefixes[0] in segments
              defaultPrefixes.shift()
            prefixArray.push(null)
          if _.isString(parameter)
            valuesArray.push([parameter])
          else if _.isNumber(parameter)
            valuesArray.push([parameter.toString()])
          else if _.isArray(parameter)
            valuesArray.push(parameter)
          else
            throw new Error("Parameters for getLinkArray() must be of type string, number, array, or object")
        else
          throw new Error('Cannot use default prefixes after non-default prefixes have been used')

    return combineTwoLevels(prefixArray, valuesArray)

getLink = (parameters...) ->
  links = getLinkArray(parameters...)
  if links.length > 1
    throw new Error("getLink was called with parameters that cause it to come back with more than one link")
  else if links.length < 1
    return undefined
  else
    return links[0]

getDocOrAttachmentLink = (parameters...) ->
  defaultPrefixes = ['dbs', 'colls', 'docs', 'attachments']
  links = getLinkArray(parameters..., defaultPrefixes)
  if links.length > 1
    throw new Error("getLink was called with parameters that cause it to come back with more than one link")
  else if links.length < 1
    return undefined
  else
    return links[0]

module.exports = {getDocLink: getDocOrAttachmentLink, getAttachmentLink: getDocOrAttachmentLink, getLink, getLinkArray}
