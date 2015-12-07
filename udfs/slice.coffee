# Use in query like: `SELECT c.id, udf.slice(c.someArrayField, 0, 1) as someArrayField FROM c`

module.exports = (array, begin, end) ->
  return array.slice(begin, end)