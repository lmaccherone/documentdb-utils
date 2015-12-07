path = require('path')
fs = require('fs')
expandSource = require(path.join(__dirname, 'expandSource'))
{getLinkArray} = require(path.join(__dirname, 'link'))
async = require('async')

loadSourceToOneCollection = (spec, callback) ->  # spec: {collectionLink, source, client}
  if spec.type is 'sprocs'
    spec.client.upsertStoredProcedure(spec.collectionLink, spec.source, callback)
  else if spec.type is 'UDFs'
    spec.client.upsertUserDefinedFunction(spec.collectionLink, spec.source, callback)

loadSourceFromFile = (spec, callback) ->  # spec: {fullFilePath, client, collectionLinks}
  source = expandSource(spec.fullFilePath)
  {client, type} = spec
  specs = ({collectionLink, source, client, type} for collectionLink in spec.collectionLinks)
  async.each(specs, loadSourceToOneCollection, callback)

loadScripts = (spec, callback) ->
  {sourceDirectory, client, collectionLinks} = spec
  sourceFiles = fs.readdirSync(sourceDirectory)
  sourceNames = (path.basename(sourceFile, '.coffee') for sourceFile in sourceFiles)  # TODO: Make loadScripts work with .js files also
  sourceLinks = getLinkArray(collectionLinks, sourceNames)
  specs = []
  type = spec.type
  for sourceFile in sourceFiles
    fullFilePath = path.join(sourceDirectory, sourceFile)
    specs.push({fullFilePath, client, collectionLinks, type})
  async.each(specs, loadSourceFromFile, (err) ->
    callback(err, sourceLinks)
  )

module.exports =
  loadSprocs: (spec, callback) ->
    spec.type = 'sprocs'
    return loadScripts(spec, callback)

  loadUDFs: (spec, callback) ->
    spec.type = 'UDFs'
    return loadScripts(spec, callback)

