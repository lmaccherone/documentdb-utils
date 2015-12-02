module.exports = (memo) ->

  collection = getContext().getCollection()

  unless memo?
    memo = {}
  unless memo.count?
    memo.count = 0
  unless memo.continuation?
    memo.continuation = null
  unless memo.example?
    memo.example = null

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

    count = resources.length
    memo.count += count
    memo.example = resources[0]
    if options.continuation?
      memo.continuation = options.continuation
      query()
    else
      memo.continuation = null
      setBody()

  setBody = () ->
    getContext().getResponse().setBody(memo)

  query()
  return memo
