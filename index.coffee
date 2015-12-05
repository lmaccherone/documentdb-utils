# TODO: Add all the other functions to index.coffee
path = require('path')

link = require(path.join(__dirname, 'src', 'link'))

module.exports =
  WrappedClient: require(path.join(__dirname, 'src', 'WrappedClient'))
  getLink: link.getLink
  getDocLink: link.getDocLink
  getAttachmentLink: link.getAttachmentLink
  getLinkArray: link.getLinkArray
  loadSprocs: require(path.join(__dirname, 'src', 'loadSprocs'))

