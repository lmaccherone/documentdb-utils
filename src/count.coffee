count = (memo) ->

  collection = getContext().getCollection()

  unless memo?
    memo = {}
  unless memo.count?
    memo.count = 0
  unless memo.continuation?
    memo.continuation = null

  stillQueuingOperations = true

  query = () ->

    if stillQueuingOperations
      responseOptions =
        continuation: memo.continuation
        pageSize: 1000

      if memo.filterQuery?
        stillQueuingOperations = collection.queryDocuments(collection.getSelfLink(), memo.filterQuery, responseOptions, onReadDocuments)
      else
        stillQueuingOperations = collection.readDocuments(collection.getSelfLink(), responseOptions, onReadDocuments)

    setBody()

  onReadDocuments = (err, resources, options) ->
    if err
      throw err

    count = resources.length
    memo.count += count
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

exports.count = count