path = require('path')

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

insertMixins = (sproc, minify = false) ->
# TODO: Minify resulting string if specified
  switch typeof(sproc)
    when 'function'
      sprocString = sproc.toString()
    when 'string'
      sprocString = sproc

  keyString = "= require("
  keyIndex = sprocString.indexOf(keyString)
  if keyIndex >= 0
    sprocLines = sprocString.split('\n')
    i = 0
    currentLine = sprocLines[i]
    while currentLine.indexOf(keyString) < 0
      i++
      currentLine = sprocLines[i]

    keyIndex = currentLine.indexOf(keyString)
    variableString = currentLine.substr(0, keyIndex).trim()
    toRequireString = currentLine.substr(keyIndex + keyString.length + 1)
    toRequireString = toRequireString.substr(0, toRequireString.indexOf("'"))
    functionToInsert = require(toRequireString)
    spacesToIndent = startingSpacesCount(currentLine)
    if typeof(functionToInsert) is 'function'
      functionToInsertString = indent(variableString + " = " + functionToInsert.toString() + ';\n', spacesToIndent)
    else
      functionToInsertString = indent(variableString + " = {\n", spacesToIndent)
      stringsToInsert = []
      for key, value of functionToInsert
        stringsToInsert.push(indent(key + ": " + value.toString(), spacesToIndent + 2))
      functionToInsertString += stringsToInsert.join(',\n') + '\n' + indent('};', spacesToIndent)

    sprocLines[i] = functionToInsertString
    sprocString = sprocLines.join('\n')
    insertMixins(sprocString, minify)
  else
    if minify
      console.log('Minify not implemented yet')

    return sprocString

module.exports = (sprocFile) ->
  sprocFunction = require(sprocFile)
  id = path.basename(sprocFile, '.coffee')
  body = insertMixins(sprocFunction.toString())
  return {id, body}  # TODO: Update docs