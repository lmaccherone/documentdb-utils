module.exports = (memo) ->

  collection = getContext().getCollection()

  unless memo?
    memo = {}
  unless memo.result?
    memo.result = {}
  unless memo.continuation?
    memo.continuation = null

  memo.stillQueueing = true

  query = () ->

    if memo.stillQueueing
      responseOptions =
        continuation: memo.continuation
        pageSize: 1000

      if memo.filterQuery?
        memo.stillQueueing = collection.queryDocuments(collection.getSelfLink(), memo.filterQuery, responseOptions, onReadDocuments)
      else
        memo.stillQueueing = collection.readDocuments(collection.getSelfLink(), responseOptions, onReadDocuments)

    setBody()

  onReadDocuments = (err, resources, options) ->
    if err
      throw err

    for row in resources
      lastRowForThisId = memo.result[row.UserId]
      if not lastRowForThisId? or row.DateCreated > lastRowForThisId.DateCreated
        memo.result[row.UserId] = row

    if options.continuation?
      memo.continuation = options.continuation
      query()
    else
      memo.continuation = null
      setBody()
      return memo

  setBody = () ->
    getContext().getResponse().setBody(memo)

  query()
