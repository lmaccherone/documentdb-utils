path = require('path')
fs = require('fs')
expandSproc = require(path.join(__dirname, 'expandSproc'))
async = require('async')

loadSprocToOneCollection = (spec, callback) ->  # spec: {collectionLink, sproc, client}
  console.log("Loaded sproc: #{spec.sproc.id} to collection: #{spec.collectionLink}")
  spec.client.upsertStoredProcedure(spec.collectionLink, spec.sproc, callback)

loadSprocFromFile = (spec, callback) ->  # spec: {fullFilePath, client, collectionLinks}
  sproc = expandSproc(spec.fullFilePath)
  client = spec.client
  specs = ({collectionLink, sproc, client} for collectionLink in spec.collectionLinks)
  async.each(specs, loadSprocToOneCollection, callback)

module.exports = (spec, callback) ->
  {sprocDirectory, client, collectionLinks} = spec
  sprocLinks = {}
  sprocFiles = fs.readdirSync(sprocDirectory)
  specs = []
  for sprocFile in sprocFiles
    fullFilePath = path.join(sprocDirectory, sprocFile)
    specs.push({fullFilePath, client, collectionLinks})
  async.each(specs, loadSprocFromFile, callback)

