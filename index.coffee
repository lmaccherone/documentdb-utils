path = require('path')

documentdb = require('documentdb')

link = require(path.join(__dirname, 'src', 'link'))
loadScripts = require(path.join(__dirname, 'src', 'loadScripts'))

module.exports =
  WrappedClient: require(path.join(__dirname, 'src', 'WrappedClient'))
  getLink: link.getLink
  getDocLink: link.getDocLink
  getAttachmentLink: link.getAttachmentLink
  getLinkArray: link.getLinkArray
  expandScript: require(path.join(__dirname, 'src', 'expandScript'))
  loadSprocs: loadScripts.loadSprocs
  loadUDFs: loadScripts.loadUDFs
  _: require('lodash')
  async: require('async')
  sqlFromMongo: require('sql-from-mongo').sqlFromMongo
  getGUID: documentdb.Base.generateGuidId
  generateGuidId: documentdb.Base.generateGuidId
