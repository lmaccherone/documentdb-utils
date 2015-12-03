module.exports = (spec, segments...) ->
  # This supports two calling patterns new Link('database-id', 'collection-id', 'document-id') or new Link({dbs: 'database-id', colls: 'colleciton-id', sprocs: 'sproc-id'}
  if segments.length > 0 or typeof(spec) is 'string'
    segments.unshift(spec)  # puts the first parameter in the list
    # assume default of [dbs, colls, docs]
    spec = {dbs: segments[0]}
    if segments[1]?
      spec.colls = segments[1]
      if segments[2]?
        spec.docs = segments[2]
  parts = []
  for type, id of spec
    parts.push(type)
    parts.push(id)
  return parts.join('/')
