class DocumentDBMock
  constructor: (@storedProcedure) ->
    if @storedProcedure
      @storedProcedure.__set__('getContext', @getContext)
    @lastBody = null
    @lastOptions = null
    @lastEntityLink = null
    @lastQueryFilter = null
    @lastRow = null
    @rows = []
    @nextError = null
    @nextResources = []
    @nextOptions = {}
    @nextCollectionOperationQueued = true
    @errorList = null
    @resourcesList = null
    @optionsList = null
    @collectionOperationQueuedList = null

  _shiftNext: () ->
    if @errorList? and @errorList.length > 0
      @nextError = @errorList.shift()
    if @resourcesList? and @resourcesList.length > 0
      @nextResources = @resourcesList.shift()
    if @optionsList? and @optionsList.length > 0
      @nextOptions = @optionsList.shift()

  _shiftNextCollectionOperationQueued: () ->
    if @collectionOperationQueuedList? and @collectionOperationQueuedList.length > 0
      @nextCollectionOperationQueued = @collectionOperationQueuedList.shift()

  getContext: () =>
    getResponse: () =>
      setBody: (body) =>
        @lastBody = body

    getCollection: () =>
      readDocument: (@lastEntityLink, @lastOptions, callback) =>
        @_shiftNextCollectionOperationQueued()
        if @nextCollectionOperationQueued
          @_shiftNext()
          callback(@nextError, @nextResources, @nextOptions)
        return @nextCollectionOperationQueued

      queryDocuments: (@lastEntityLink, @lastQueryFilter, @lastOptions, callback) =>
        @_shiftNextCollectionOperationQueued()
        if @nextCollectionOperationQueued
          @_shiftNext()
          callback(@nextError, @nextResources, @nextOptions)
        return @nextCollectionOperationQueued

      readDocuments: (@lastEntityLink, @lastOptions, callback) =>
        @_shiftNextCollectionOperationQueued()
        if @nextCollectionOperationQueued
          @_shiftNext()
          callback(@nextError, @nextResources, @nextOptions)
        return @nextCollectionOperationQueued

      getSelfLink: () =>
        return 'mocked-self-link'

      createDocument: (@lastEntityLink, @lastRow, @lastOptions, callback) =>
        @_shiftNextCollectionOperationQueued()
        if @nextCollectionOperationQueued
          @rows.push(@lastRow)
          if callback?
            @_shiftNext()
            callback(@nextError, @nextResources, @nextOptions)
        return @nextCollectionOperationQueued

      replaceDocument: (@lastEntityLink, @lastRow, @lastOptions, callback) =>
        unless @lastRow?.id?
          throw new Error("The input content is invalid because the required property, id, is missing.")
        @_shiftNextCollectionOperationQueued()
        if @nextCollectionOperationQueued
          @rows.push(@lastRow)
          if callback?
            @_shiftNext()
            callback(@nextError, @nextResources, @nextOptions)
        return @nextCollectionOperationQueued

module.exports = DocumentDBMock