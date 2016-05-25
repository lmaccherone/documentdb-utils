path = require('path')
_ = require('lodash')

spaces = (n) ->
  a = new Array(n - 1)
  return a.join(' ')

startingSpacesCount = (line) ->
  spaceCount = 0
  for char in line
    if char is ' '
      spaceCount++
  return spaceCount

indent = (s, n) ->
  outputLines = []
  lines = s.split('\n')
  for line in lines
    if line.trim().length > 0
      outputLines.push(spaces(n) + line)
    else
      outputLines.push(line)
  return outputLines.join('\n')

insertMixins = (source, minify = false) ->
# TODO: Minify resulting string if specified
  switch typeof(source)
    when 'function'
      sourceString = source.toString()
    when 'string'
      sourceString = source

  keyString = "= require("
  keyIndex = sourceString.indexOf(keyString)
  if keyIndex >= 0
    sourceLines = sourceString.split('\n')
    i = 0
    currentLine = sourceLines[i]
    while currentLine.indexOf(keyString) < 0
      i++
      currentLine = sourceLines[i]

    keyIndex = currentLine.indexOf(keyString)
    variableString = currentLine.substr(0, keyIndex).trim()
    toRequireString = currentLine.substr(keyIndex + keyString.length + 1)
    afterRequireIndex = toRequireString.indexOf("').")
    if afterRequireIndex >= 0
      afterRequireString = toRequireString.substr(afterRequireIndex + 3)
      afterRequireString = afterRequireString.substr(0, afterRequireString.length - 1)
      afterRequireArray = afterRequireString.split('.')
    toRequireString = toRequireString.substr(0, toRequireString.indexOf("'"))
    functionToInsert = require(toRequireString)
    while afterRequireArray?.length > 0
      nextReference = afterRequireArray.shift()
      functionToInsert = functionToInsert[nextReference]
    spacesToIndent = startingSpacesCount(currentLine)
    if _.isFunction(functionToInsert)
      functionToInsertString = indent(variableString + " = " + functionToInsert.toString() + ';\n', spacesToIndent)
    else if _.isString(functionToInsert) or _.isBoolean(functionToInsert) or _.isNull(functionToInsert) or _.isNumber(functionToInsert)
      functionToInsertString = indent(variableString + " = " + JSON.stringify(functionToInsert) + ';\n', spacesToIndent)
    else if _.isPlainObject(functionToInsert)
      functionToInsertString = indent(variableString + " = {\n", spacesToIndent)
      stringsToInsert = []
      for key, value of functionToInsert
        if _.isFunction(value)
          stringsToInsert.push(indent(key + ": " + value.toString(), spacesToIndent + 2))
        else if _.isString(value) or _.isBoolean(value) or _.isNull(value) or _.isNumber(value)
          stringsToInsert.push(indent(key + ": " + JSON.stringify(value), spacesToIndent + 2))
        else
          throw new Error("#{typeof(value)} is not a supported type for expandScript")
      functionToInsertString += stringsToInsert.join(',\n') + '\n' + indent('};', spacesToIndent)
    else
      throw new Error("#{typeof(functionToInsert)} is not a supported type for expandScript")

    sourceLines[i] = functionToInsertString
    sourceString = sourceLines.join('\n')
    insertMixins(sourceString, minify)
  else
    if minify
      console.log('Minify not implemented yet')

    return sourceString

module.exports = (sourceFile) ->
  sourceFunction = require(sourceFile)
  id = path.basename(sourceFile, '.coffee')
  body = insertMixins(sourceFunction.toString())
  return {id, body}  # TODO: Update docs