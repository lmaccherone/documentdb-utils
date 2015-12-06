# TODO: Add all the other functions to index.coffee
path = require('path')

link = require(path.join(__dirname, 'src', 'link'))
documentdb = require('documentdb')

module.exports =
  WrappedClient: require(path.join(__dirname, 'src', 'WrappedClient'))
  getLink: link.getLink
  getDocLink: link.getDocLink
  getAttachmentLink: link.getAttachmentLink
  getLinkArray: link.getLinkArray
  loadSprocs: require(path.join(__dirname, 'src', 'loadSprocs'))
  _: require('lodash')
  async: require('async')
  sqlFromMongo: require('sql-from-mongo').sqlFromMongo
  getGUID: documentdb.Base.generateGuidId
  generateGuidId: documentdb.Base.generateGuidId