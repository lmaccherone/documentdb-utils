# TODO: Write tests for createSpecificDocuments sproc

module.exports = (memo) ->

  unless memo?.documents?
    throw new Error('generateData must be called with an object containing a `documents` field.')
  unless memo.totalCount?
    memo.totalCount = 0
  memo.countForThisRun = 0

  collection = getContext().getCollection()
  collectionLink = collection.getSelfLink()
  memo.stillQueueing = true

  createDocument = () ->
    if memo.documents.length > 0 and memo.stillQueueing
      row = memo.documents.pop()
      getContext().getResponse().setBody(memo)
      memo.stillQueueing = collection.createDocument(collectionLink, row, (error, resource, options) ->
        if error?
          throw new Error(error)
        else if memo.stillQueueing
          memo.countForThisRun++
          memo.totalCount++
          createDocument()
        else
          memo.documents.push(row)
          memo.continuation = "value does not matter"
          getContext().getResponse().setBody(memo)
      )
    else
      memo.continuation = null
      getContext().getResponse().setBody(memo)

  createDocument()
