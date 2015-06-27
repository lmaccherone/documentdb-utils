generateData = (memo) ->

  unless memo?.remaining?
    throw new Error('generateData must be called with an object containing a `remaining` field.')
  unless memo.totalCount?
    memo.totalCount = 0
  memo.countForThisRun = 0

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

  collection = getContext().getCollection()
  collectionLink = collection.getSelfLink()

  queued = true
  while memo.remaining > 0 and queued
    row = {}
    for key in keys
      row[key] = getRandomValue(possibleValues[key])
    getContext().getResponse().setBody(memo)
    queued = collection.createDocument(collectionLink, row)
    if queued
      memo.remaining--
      memo.countForThisRun++
      memo.totalCount++

  getContext().getResponse().setBody(memo)
  return memo

exports.generateData = generateData
