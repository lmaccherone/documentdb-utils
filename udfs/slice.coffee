# Use in query like: `SELECT c.id, udf.slice(c.someArrayField, 0, 1) as someArrayField FROM c`

module.exports = (array, begin, end) ->
  return array.slice(begin, end)


# TODO: Add functions from underscore/lodash. Maybe we can include underscore as a mixin and extract individual UDFs out of it
###
This could be valuable
  where
  findWhere
  contains
  pluck
  max
  min
  sortBy (string form)
  groupBy
  shuffle
  sample
  toArray
  size (for objects because .length works for arrays)
  first
  initial
  last
  rest
  compact
  flatten
  without
  union
  intersection
  difference
  unique
  zip
  unzip
  object
  indexOf
  lastIndexOf
  sortedIndex (without iteree)
  findIndex
  findLastIndex
  range
  keys
  allkeys
  values
  pairs
  invert
  ...


Consider these where the predicate or iteree is optional
  every
  some
###

# TODO: Add functions from String, Array, etc. like Array.slice() example above

# TODO: Add docs that explain that every UDF herein can also be a mixin for a sproc or another UDF.