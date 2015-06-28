updateSomeDocuments = (memo) ->

  possibleValues =
    ProjectHierarchy: [
      [1, 2, 3],
      [1, 2, 4],
      [1, 2],
      [5],
      [5, 6]
    ],
    Priority: [1, 2, 3, 4]
    Severity: [1, 2, 3, 4]
    Points: [null, 0.5, 1, 2, 3, 5, 8, 13]
    State: ['Backlog', 'Ready', 'In Progress', 'In Testing', 'Accepted', 'Shipped']

  getIndex = (length) ->
    return Math.floor(Math.random() * length)

  getRandomValue = (possibleValues) ->
    index = getIndex(possibleValues.length)
    return possibleValues[index]

  keys = (key for key, value of possibleValues)

  getRandomRow = () ->
    row = {}
    for key in keys
      row[key] = getRandomValue(possibleValues[key])
    return row

  collection = getContext().getCollection()

  unless memo?
    memo = {}
  unless memo.transactions?
    memo.transactions = []

  stillQueuingOperations = true

  query = () ->
    if stillQueuingOperations
      responseOptions =
        pageSize: memo.remaining
      setBody()
      stillQueuingOperations = collection.readDocuments(collection.getSelfLink(), responseOptions, onReadDocuments)

  onReadDocuments = (err, resources, options) ->
    if err
      throw err

    if resources.length isnt memo.remaining
      throw new Error("Expected memo.remaining (#{memo.remaining}) and the number of rows returned (#{resources.length}) to match. They don't.")

    # generate 5 new documents and update them
    queued = true
    while memo.remaining > 0 and queued
      oldDocument = resources[memo.remaining - 1]
      documentLink = oldDocument._self
      etag = oldDocument._etag
      options = {etag}  # Sending the etag per best practice, but not handling it if there is conflict.
      newDocument = getRandomRow()
      newDocument.id = oldDocument.id
      getContext().getResponse().setBody(memo)
      queued = collection.replaceDocument(documentLink, newDocument, options)
      if queued
        memo.transactions.push({oldDocument, newDocument})
        memo.remaining--

  setBody = () ->
    getContext().getResponse().setBody(memo)

  query()
  return memo

exports.updateSomeDocuments = updateSomeDocuments