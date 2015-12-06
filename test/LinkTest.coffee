path = require('path')

{getLink, getDocLink, getAttachmentLink, getLinkArray} = require('../')

exports.linkTest =

  basic: (test) ->
    l = getLink('I', 'A', 1)
    test.equal(l, "dbs/I/colls/A/sprocs/1")

    l2 = getLink(1, {users: 'myUser'})
    test.equal(l2, "dbs/1/users/myUser")

    l3 = getLink('dev-test-database', 1, 'createVariedDocuments')
    test.equal(l3, "dbs/dev-test-database/colls/1/sprocs/createVariedDocuments")

    l4 = getLink('dev-test-database')
    test.equal(l4, "dbs/dev-test-database")

    collectionLink = getLink('dev-test-database', 1)
    test.equal(collectionLink, 'dbs/dev-test-database/colls/1')

    sprocLink = getLink(collectionLink, 'createVariedDocuments')
    test.equal(sprocLink, 'dbs/dev-test-database/colls/1/sprocs/createVariedDocuments')

    docLink = getDocLink(collectionLink, 'myDoc')
    test.equal(docLink, 'dbs/dev-test-database/colls/1/docs/myDoc')

    docLink = getAttachmentLink('a', '1', 'myDoc', 'myAttachment')
    test.equal(docLink, 'dbs/a/colls/1/docs/myDoc/attachments/myAttachment')

    test.done()

  links: (test) ->
    # Assumes that the first parameter is dbs, second is colls, and third is sprocs. Chose sprocs over docs because it's
    # more common to call the same sproc in several collections than it is to look for a doc with the same id in several collections
    links = getLinkArray(['db1', 'db2'], ['col1', 'col2', 'col3'])
    collectionLinks = [
      'dbs/db1/colls/col1',
      'dbs/db1/colls/col2',
      'dbs/db1/colls/col3',
      'dbs/db2/colls/col1',
      'dbs/db2/colls/col2',
      'dbs/db2/colls/col3'
    ]
    test.deepEqual(links, collectionLinks)

    # The defaults of dbs, colls, sprocs also work if any level is a string
    links = getLinkArray(['myDB', 'myDB2'])
    expected = [
      'dbs/myDB',
      'dbs/myDB2'
    ]
    test.deepEqual(links, expected)

    # The defaults of dbs, colls, sprocs also work if any level is a string
    links = getLinkArray('myDB', ['col1', 'col2'], 'mySproc')
    expected = [
      'dbs/myDB/colls/col1/sprocs/mySproc',
      'dbs/myDB/colls/col2/sprocs/mySproc'
    ]
    test.deepEqual(links, expected)

    # If you only have one for either the first or second list and you forget to put it in an array, that's fine
    links = getLinkArray('db1', ['col1', 'col2', 'col3'])
    collectionLinks = [
      'dbs/db1/colls/col1',
      'dbs/db1/colls/col2',
      'dbs/db1/colls/col3'
    ]
    test.deepEqual(links, collectionLinks)

    # You can override the default prefixes of dbs, colls, sprocs by specifying the prefix as the key to an object
    links = getLinkArray(['db1', 'db2'], {users: ['Joe', 'Jen']})
    expected = [
      'dbs/db1/users/Joe',
      'dbs/db1/users/Jen',
      'dbs/db2/users/Joe',
      'dbs/db2/users/Jen'
    ]
    test.deepEqual(links, expected)

    # The value of an object with a non-default prefix can also be a string
    links = getLinkArray(['db1', 'db2'], {users: 'Joe'})
    expected = [
      'dbs/db1/users/Joe',
      'dbs/db2/users/Joe'
    ]
    test.deepEqual(links, expected)

    # You can also use it to combine more than 2 levels. Here's a four level example
    links = getLinkArray(['db1', 'db2'], ['col1', 'col2'], {docs: ['a', 'b']}, {attachments: [1, 2]})
    expected = [
      'dbs/db1/colls/col1/docs/a/attachments/1',
      'dbs/db1/colls/col1/docs/a/attachments/2',
      'dbs/db1/colls/col1/docs/b/attachments/1',
      'dbs/db1/colls/col1/docs/b/attachments/2',
      'dbs/db1/colls/col2/docs/a/attachments/1',
      'dbs/db1/colls/col2/docs/a/attachments/2',
      'dbs/db1/colls/col2/docs/b/attachments/1',
      'dbs/db1/colls/col2/docs/b/attachments/2',
      'dbs/db2/colls/col1/docs/a/attachments/1',
      'dbs/db2/colls/col1/docs/a/attachments/2',
      'dbs/db2/colls/col1/docs/b/attachments/1',
      'dbs/db2/colls/col1/docs/b/attachments/2',
      'dbs/db2/colls/col2/docs/a/attachments/1',
      'dbs/db2/colls/col2/docs/a/attachments/2',
      'dbs/db2/colls/col2/docs/b/attachments/1',
      'dbs/db2/colls/col2/docs/b/attachments/2'
    ]
    test.deepEqual(links, expected)

    # Let's say you already have an expanded list of links and you want to tack something on. This works including using defaults.
    # BTW, this is the most useful mode for getLinkArray. I very commonly have a list of collections and I want to call the same
    # stored procedure in each
    collectionLinks = [
      'dbs/db1/colls/col1',
      'dbs/db1/colls/col2',
      'dbs/db1/colls/col3'
    ]
    sprocLinks = getLinkArray(collectionLinks, 'mySproc')
    expected = [
      'dbs/db1/colls/col1/sprocs/mySproc',
      'dbs/db1/colls/col2/sprocs/mySproc',
      'dbs/db1/colls/col3/sprocs/mySproc'
    ]
    test.deepEqual(sprocLinks, expected)

    links = getLinkArray(['dev-test-database'], [1, 2])
    expected = [
      'dbs/dev-test-database/colls/1',
      'dbs/dev-test-database/colls/2'
    ]
    test.deepEqual(links, expected)

    test.done()