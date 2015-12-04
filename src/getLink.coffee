path = require('path')
getLinkArray = require(path.join(__dirname, 'getLinkArray'))

module.exports = (parameters...) ->
  links = getLinkArray(parameters...)
  if links.length > 1
    throw new Error("getLink was called with parameters that cause it to come back with more than one link")
  else if links.length < 1
    return undefined
  else
    return links[0]
