path = require('path')
fs = require('fs')
expandSproc = require(path.join(__dirname, 'expandSproc'))
{getLinkArray} = require(path.join(__dirname, 'link'))
async = require('async')

loadSprocToOneCollection = (spec, callback) ->  # spec: {collectionLink, sproc, client}
  spec.client.upsertStoredProcedure(spec.collectionLink, spec.sproc, callback)

loadSprocFromFile = (spec, callback) ->  # spec: {fullFilePath, client, collectionLinks}
  sproc = expandSproc(spec.fullFilePath)
  client = spec.client
  specs = ({collectionLink, sproc, client} for collectionLink in spec.collectionLinks)
  async.each(specs, loadSprocToOneCollection, callback)

module.exports = (spec, callback) ->
  {sprocDirectory, client, collectionLinks} = spec
  sprocFiles = fs.readdirSync(sprocDirectory)
  sprocNames = (path.basename(sprocFile, '.coffee') for sprocFile in sprocFiles)
  sprocLinks = getLinkArray(collectionLinks, sprocNames)
  specs = []
  for sprocFile in sprocFiles
    fullFilePath = path.join(sprocDirectory, sprocFile)
    specs.push({fullFilePath, client, collectionLinks})
  async.each(specs, loadSprocFromFile, (err) ->
    callback(err, sprocLinks)
  )

