count = (memo) ->

  collection = getContext().getCollection()

  maxRowCountPerExececution = 100000
  rowCountForThisExecution = 0
  maxExecutionTime = 5000 * 0.9
  executionStartTime = new Date().getTime()

  unless memo?
    memo = {}
  unless memo.count?
    memo.count = 0
  unless memo.continuation?
    memo.continuation = null

  memo.stillTime = true
  memo.stillResources = true
  memo.underMaxRowCount = true

  query = (responseOptions) ->
    memo.stillTime = (new Date().getTime() - executionStartTime) < maxExecutionTime
    memo.underMaxRowCount = rowCountForThisExecution < maxRowCountPerExececution

    if memo.underMaxRowCount and memo.stillTime and memo.stillResources
      responseOptions =
        continuation: memo.continuation
        pageSize: 1000

      if memo.filterQuery?
        memo.stillResources = collection.queryDocuments(collection.getSelfLink(), memo.filterQuery, responseOptions, onReadDocuments)
      else
        memo.stillResources = collection.readDocuments(collection.getSelfLink(), responseOptions, onReadDocuments)

    setBody()

  onReadDocuments = (err, docFeed, responseOptions) ->
    if err
      throw err

    count = docFeed.length
    memo.count += count
    rowCountForThisExecution += count
    if responseOptions.continuation?
      memo.continuation = responseOptions.continuation
      query()
    else
      memo.continuation = null
      setBody()

  setBody = () ->
    getContext().getResponse().setBody(memo)

  query()

exports.count = count