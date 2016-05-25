# documentdb-utils #

Copyright (c) 2015, Lawrence S. Maccherone, Jr.

_Drop-in replacement + extensions for DocumentDB node.js client with auto-retry on 429 errors plus a lot more_

By providing functionality like automatic retries on 429 errors among other things, documentdb-utils makes it much easier to use Microsoft Azure DocumentDB from node.js.

Note, versions prior to 0.4.0 had a very different interface exposed as the function documentDBUtils(). That has now been removed in favor of this drop-in replacement + extensions approach.


## Source code ##

* [Source Repository](https://github.com/lmaccherone/documentdb-utils)


## Features ##

### Drop-in enhanced functionality ###

* All methods and functionality of the Microsoft Azure node.js client with the exact same signature so you can drop this into your code and get an instantaneos upgrade.

* Automatically handles 429 throttling responses by retrying after the delay specified by the prior operation.

* Sproc execution continuation. Automatically deals with early termination of stored procedures for exceeding resources. Just follow a simple pattern (memoization like that used in a reduce function) for writing your stored procedures. The state will be shipped back to the calling side and the stored procedure will be called again picking back up right where it left off. I want to upgrade this to serialize a sproc execution continuation in a document or attachment so we don't have to ship the state back and forth. The state for a call to documentdb-lumenize/cube can get pretty large.

### Extended functionality ###

* All `query<entity>s` methods now accept MongoDB-like queries which are atuomatically converted to SQL by [sql-from-mongo](https://www.npmjs.com/package/sql-from-mongo). You can still send in strings or objects with parameters as before, but it senses that the query is a MongoDB like query and acts accordingly. It's much easier to compose queries like `{value: 1}` than `SELECT * FROM c WHERE value = 1`, IMHO.

* `<old-method>Array(..., callback)` as short-hand for `.toArray()` calls. Example:  `readDocumentsArray(collectionLink, callback)`. This alone makes it easier to use higher order async functions, but I'm not done yet.

* `<old-method>Multi(linkArray, ..., callback)` and `<old-method>ArrayMulti(linkArray, ..., callback)` as automatic fan-out to multiple collections, sprocs, etc. for each method whose first parameter is a link. If you want to run the same query against multiple collections or call a sproc by the same name in different collections, you can now do that with one line. The results are automatically aggregated into a single callback response. Example: `executeStoredProcedureMulti(arrayOfCollecitonLinks, 'countDocuments', callback)`.

* `<old-method>AsyncJSIterator(item, callback)` wrapper of methods to enable use of async.js's higher order functions like map, filter, etc. This is used internally to provide the multi-link capability but you can use it yourself to compose your own. See test code for examples.

* Aggregated stats on the number of round trips, request unit costs, retries, time lost to retries as well as total execution time for operations.

### The kitchen sink ###

* link and link array generator. Example: `getLinkArray('myDB', [1, 2], 'mySproc')` results in `['dbs/myDB/colls/1/sprocs/mySproc', 'dbs/myDB/colls/2/sprocs/mySproc']`

* expandScript functionality allows you to "require" npm modules from within your stored procedures as well as DRY for utility functions in your sprocs

* loadSprocs/loadUDFs automatically expands and loads every sproc/UDF in a directory to a list of collections

* countDocuments, createSpecificDocuments, createVariedDocuments, deleteSomeDocuments, updateSomeDocuments sprocs to use as-is or as a starting point for your own sprocs

* getUnderscore mixin for sprocs which returns an object that implements the [underscore.js](http://underscorejs.org) API (couldn't get lodash to work). Yes, this works inside of sprocs.

* getAsync mixin for sprocs which returns an object that implements the [async.js](https://github.com/caolan/async) API. Again, you can use this from sprocs.

* [lodash](https://lodash.com) and [async.js](https://github.com/caolan/async) exported as _ and async respectively

* [sql-from-mongo](https://www.npmjs.com/package/sql-from-mongo) exported as sqlFromMongo

* documentdb.Base.generateGuidId exported and aliased as getGUID in addition to generateGuidId


## Install ##

`npm install -save documentdb-utils`


## Usage ##

If you put your urlConnection and masterkey in DOCUMENT_DB_URL and DOCUMENT_DB_KEY environment variables (recommended), you can simply `new WrappedClient()` with no parameters.

    {WrappedClient} = require('documentdb-utils')
    client = new WrappedClient()
    
If you want to use environment variables for the first two parameters but specify a connectionPolicy and/or consistencyLevel, then simply pass in null for the first two parameters.

    {WrappedClient} = require('documentdb-utils')
    client = new WrappedClient(null, null, connectionPolicy, consistencyLevel)
    
You can also pass in the same parameters as the Azure client (urlConnection, auth, connectionPolicy, consistencyLevel) with the last two being optional.

    {WrappedClient} = require('documentdb-utils')
    client = new WrappedClient(urlConnection, auth, connectionPolicy, consistencyLevel)

Alternatively, if you've already created your own instance of the Azure DocumentClient, you can pass that in as the only parameter. Be sure to set your connectionPolicy, and consistencyLevel on the original client.

    {WrappedClient} = require('documentdb-utils')
    {DocumentClient} = require('documentdb')
    _client = new DocumentClient(urlConnection, auth)
    client = new WrappedClient(_client)
    
Now, you can use the same methods you would on DocumentClient except they are upgraded to have automatic 429 error delay/retry functionality. Further, there are some methods that are added that make it easier to use DocumentDB especially when you have multiple partitions.

### A Stored Procedure Example ###

Let's say you wrote this little stored procedure and saved it in hello.coffee.

    module.exports = () ->
      getContext().getResponse().setBody('Hello world!')
      
or if you prefer JavaScript saved in hello.js.

    module.exports = function () {
      getContext().getResponse().setBody('Hello world!');
    }
   
Now let's write some CoffeeScript to send and execute this on two different collections:

    hello = require('../sprocs/hello')

    collectionLinks = getLinkArray('db1', ['coll1', 'coll2'])
    sprocSpec = {id: 'hello', body: hello}
    wrappedClient.upsertStoredProcedureMulti(collectionLinks, sprocSpec, (err, result, stats) ->
      sprocLinks = getLinkArray(collectionLinks, 'hello')
      wrappedClient.executeStoredProcedureMulti(sprocLinks, (err, result, stats) ->
        console.log(result)  # The output of the executions as an array
        console.log(stats)  # Cumulative RUs, round trips, and other stats
      )
    )
    
And in JavaScript:

    var collectionLinks, hello, sprocSpec;
    
    hello = require('../sprocs/hello');
    
    collectionLinks = getLinkArray('db1', ['coll1', 'coll2']);
    sprocSpec = {id: 'hello', body: hello};
    wrappedClient.upsertStoredProcedureMulti(collectionLinks, sprocSpec, function(err, result, stats) {
      var sprocLinks;
      sprocLinks = getLinkArray(collectionLinks, 'hello');
      return wrappedClient.executeStoredProcedureMulti(sprocLinks, function(err, result, stats) {
        console.log(result);
        return console.log(stats);
      });
    });
    
Look in the test directory for more examples including wrapped methods that are tailor-made for use with async.js.

### getLink, getDocLink, getAttachmentLink, and getLinkArray ###

In the example above we used getLinkArray to create an array of two collection links. We then used that in another call to getLinkArray to create an array of two sproc links. However, it can do a lot more than that.

Example                                           | Output
------------------------------------------------- | ---------------------------------------
`getLink('myDB')`                                 | `"dbs/myDB"`
`getLink('I', 'A', 1)`                            | `"dbs/I/colls/A/sprocs/1"`
`getLink(1, {users: 'myUser'})`                   | `"dbs/1/users/myUser"`
`collLink = getLink('myDB', 'myColl')`<br>`sprocLink = getLink(collLink, 'mySproc')` | `"dbs/myDB/colls/myColl"`<br>`"dbs/myDB/colls/myColl/sprocs/mySproc"`
`getDocLink(collLink, 'myDoc')`                   | `"dbs/myDB/colls/myColl/docs/myDoc"`
`getAttachmentLink('I', 'A', '1', 'myAtt')`       | `"dbs/I/colls/A/docs/1/attachments/myAtt"`
`getLinkArray(['db1', 'db2'], ['col1', 'col2'])`  | `[`<br>`"dbs/db1/colls/col1",`<br>`"dbs/db1/colls/col2",`<br>`"dbs/db2/colls/col1",`<br>`"dbs/db2/colls/col2"`<br>`]`
`dbLinks = getLinkArray(['db1', 'db2'])`<br>`collLinks = getLinkArray(dbLinks, 'myColl')` | `[`<br>`"dbs/db1/colls/myColl",`<br>`"dbs/db1/colls/myColl"`<br>`]`
`getLinkArray(['db1', 'db2'], {users: 'Joe'})`    | `[`<br>`"dbs/db1/users/Joe",`<br>`"dbs/db2/users/Joe"`<br>`]`

I think you get the idea but there are a bunch of other combinations. Note the default for getLink and getLinkArray is dbs/colls/sprocs. The default for getDocLink and getAttachmentsLink is dbs/colls/docs/attachments. You can get multiple document and attachment links by using the `{docs: 'myDoc'}` parameter format in a getLinkArray call but I use GUIDs almost all the time so I never have the same id in multiple collections.

### Support for require() in server-side scripts ###

Let's say you have this CoffeeScript source code in file `sprocToExpand.coffee`

    module.exports = () ->
      x = 1
    
      mixinToInsert = require('../test-examples/mixinToInsert')
      mixinToInsert2 = require('../test-examples/mixinToInsert2')
    
      y = 2
    
This is in `mixinToInsert.coffee`:

    module.exports = () ->
      return 3
      
This is in `mixinToInsert2.coffee`:

    f1 = () ->
      mixinToInsert3 = require('../test-examples/mixinToInsert3')
      return 300
    
    f2 = (x) ->
      return x * 2
    
    module.exports = {f1, f2}
    
And last, this is in `mixinToInsert3.coffee`

    module.exports = () ->
      return 3000

The expandScript function will take the above and produce:

    function () {
        var mixinToInsert, mixinToInsert2, x, y;
        x = 1;
        mixinToInsert = function () {
            return 3;
        };
    
        mixinToInsert2 = {
            f1: function () {
                var mixinToInsert3;
                mixinToInsert3 = function () {
                    return 3000;
                };
        
                return 300;
            },
            f2: function (x) {
                return x * 2;
            }
        };
        return y = 2;
    }
    
A few things to keep in mind when trying to use expandScript:

1. The require must be on its own line.
2. It doesn't support the miriad different ways you can specify packages and requires. It only accepts two forms: a) `myVar = require('myPackage')` or b) `myVar = require('myPackage').some.lower.reference`. If you use the first form, it will import everything so if you just want one function of a library, use the second form.
3. The mixins can be written in either JavaScript or CoffeeScript but the main file must in CoffeeScript. This is something I could fix, but I didn't have the need personally so I didn't bother. The work around is to create a small CoffeeScript stub but put the bulk of your code in JavaScript that you `require()` from within your CoffeeScript stub. 

Many npm packages work out of the box, but others need some cleanup before they'll work. It's just doing string manipulation after all. However, it does give you an oportunity to modularlize your code and use some npm packages in your sprocs and UDFs.

### Using async.js and underscore.js inside of sprocs ###

I've included mixins for these popular JavaScript utility packages that you can `require()` and use when writing sprocs. See the test directory for examples. Normally I run lodash instead of underscore but I couldn't get it to run in a sproc after a bit of trying. Maybe next time.

### Convenient dependencies exposed in the package ###

I use `lodash` (exposed as `_`), `async`, `sqlFromMongo`, and `generateGuidId` (aliased also as `getGUID`) in my own code all the time and they are dependencies of documentdb-utils so I've exported them for your convenience. It will save you the effort of `npm install`ing them and help avoid having multiple versions of the same depencies in your project.
    
### Example sprocs, UDFs, and mixins ###

I've included a number of example sprocs, UDFs, and mixins that you can use as-is or as starting points for your own. See the next section down for tips on writing sprocs that work well with the continuation functionality of WrappedClient.executeStoredProcedure.

## Pattern for writing stored procedures ##

**The key to a general pattern for writing restartable stored procedures is to write them as if you were writing a reduce() function.**

Note, if you follow this pattern, the upgraded `executeStoredProcedure()` automatically deals with early termination of stored procedures for exceeding resources. Just follow this simple pattern. The state will be shipped back to the calling side and the stored procedure will be called again picking back up right where it left off.

Pehaps the most common use of stored procedures is to aggregate or transform data. It's very easy to think of these as "reduce" operations just like Array.reduce() or the reduce implementations in underscore, async.js, or just about any other library with aggregation functionality. It stretches the "reduce" metaphore a bit, but the pattern itself is perfectly usefull even for stored procedures that write data.

So:

1. Only accept one parameter -- a JavaScript Object. Let's name it `memo`. Put any parameters for your sproc in that Object (e.g. `{parameter1: "my Value", parameter2: 100}
1. Support an empty or missing `memo` on the initial call.
1. Store any variable that represents the current running state of the stored procedure into the `memo` object.
1. Store the `continuation` field returned by readDocuments and queryDocuments into `memo.continuation`. If you are doing only creates, updates, and deletes or even a set of readDocument() calls within your sproc and you want it to pause and resume for some reason, then set `continuation` manually (value doesn't matter).
1. Keep track of the boolean value returned from the last collection operation (read, query, create, upsert, etc.) and use it to determine whether or not it's time to return. My pattern is to store this in memo.stillQueueing and that used to be a requirement of documentdb-utils, but it no longer is.
1. For read/query operations avoid the use of pageSize = -1 (unlimited) especially if you have to perform some expensive aggregation operation on whatever is returned from a read. I use 1,000 as my pageSize, but you could play with this to get optimal performance. It seems to work OK with any pageSize below 10,000. Note, if the aggregation operation you perform on the data returned from a read is trivial, you may be able to get away with using pageSize = -1. If you really want optimal performance, you may want to try this.
1. Optionally store any internal visibility (debugging, timings, etc.) into the `memo` object.
1. Call `getContext().getResponse().setBody(memo)` regulary, particularly right after you kick off a collection operation (readDocuments, createDocument, etc.).
1. If `false` is returned from the most recent call to a collection operation, don't issue any more async calls. Rather, perform any aggregations and wrap up the stored procedure quickly.

Here is an example of a stored procedure that counts all the documents in a collection with an option to filter based upon provided filterQuery field in the initial memo. The source for this is included in this repository.

    count = (memo) ->
    
      collection = getContext().getCollection()
    
      unless memo?
        memo = {}
      unless memo.count?
        memo.count = 0
      unless memo.continuation?
        memo.continuation = null
    
      memo.stillQueueing = true
    
      query = (responseOptions) ->
    
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
        if options.continuation?
          memo.continuation = options.continuation
          query()
        else
          memo.continuation = null
          setBody()
    
      setBody = () ->
        getContext().getResponse().setBody(memo)
    
      query()
    
    exports.count = count


## Changelog ##

* 0.7.2 - 2015-05-25 - Sprocs can now use mixins like this `myVar = require('some_package').some.other.reference`
* 0.7.1 - 2015-12-12 - Moved sql-from-mongo to dependencies from dev-dependencies
* 0.7.0 - 2015-12-10 - Added support for mongo-like queries in WrappedClient
* 0.6.0 - 2015-12-10 - **WARNING - Slightly backward breaking because it adds parameters to callbacks. Shouldn't effect drop-in replacement of DocumentClient** Upgraded stats and bug fixes for WrappedClient
* 0.5.1 - 2015-12-09 - Documentation edits
* 0.5.0 - 2015-12-08 - **WARNING - Slightly backward breaking on API for loadScripts** Updated docs
* 0.4.6 - 2015-12-07 - Added async.js and underscore.js as mixins for sprocs
* 0.4.5 - 2015-12-07 - expandScript now works with primatives
* 0.4.4 - 2015-12-07 - Fix for udfs not being compiled, however, loadSprocs/loadUDFs still won't work with .js files
* 0.4.3 - 2015-12-07 - Added loadUDFs and refactored loadSprocs
* 0.4.2 - 2015-12-06 - Various cleanup
* 0.4.1 - 2015-12-06 - Fixed `cake compile` and `cake clean` so the .js files are uploaded to npm
* 0.4.0 - 2015-12-05 - **WARNING - Major backward breaking changes** 
  Since documentdb-utils was introduced, DocumentDB has added id-based links, upserts, and maxItemCount = -1. The lack of these
  features were 3 of the 4 primary motivations for the creation of documentdb-utils. The only remaining big motivator is
  authomatic retries upon 429 errors. However, I now believe that the best way to provide that is by wrapping the appropriate methods
  of the Azure-provided DocumentDB node.js API. This new approach makes documentdb-utils much easier to
  utilize since it has the same API as the Azure-provided one. You can now add documentdb-utils in one place
  and not modify the rest of your code. Previously, documentdb-utils had a monolithic single function API that looked
  very different from the Azure-provided one. Also, it now supports every method of the Azure-provided API, whereas previously,
  documentdb-utils only supported stored procedures and single-document operations. Nearly every line of code in this package has been rewritten to accomplish 
  this transformation. Further, I've built a number of other useful utilities including enabling 
  code reuse for stored procedures by allowing you to `require()` other bits of code or even appropriate npm modules 
  directly in your sprocs as well as automatic loading of all stored procedures in a given directory. This additional utility was
  implemented as part of other projects but it's generally useful so it's now been moved here. 
* 0.3.4 - 2015-07-14 - Finally got rid of the delete/recreate hack when just terminated for out of time. Still deletes/recreates if get 403 blacklist message 
* 0.3.3 - 2015-07-12 - Will delete and recreate sprocs that have been blacklisted
* 0.3.2 - 2015-07-12 - Returns total RUs in stats
* 0.3.1 - 2015-07-09 - Upgraded to latest version of documentdb API
* 0.3.0 - 2015-07-01 - **WARNING - Backward breaking change** Restored the hack where it
  deletes and upserts sprocs whenever they receive a false from a collection operation. 
  To use this functionality, you need to pattern your sprocs such that they return a 
  `stillQueueing` field in the body. This is just the last recorded value returned from 
  a collection operation. It's backward breaking because the key field is now 
  `stillQueueing` whereas it was previously `stillQueueingOperations`.
* 0.2.5 - 2015-06-30 - Another bug fix
* 0.2.4 - 2015-06-30 - Bug fix
* 0.2.3 - 2015-06-30 - Restored the delete, upsert, and retry logic but this time only if you 
        get a 403 error and message indicating blacklisting
* 0.2.2 - 2015-06-30 - Revert to blacklisting hack because the bug doesn't seem to be fixed
* 0.2.1 - 2015-06-30 - Handle 408 error by retrying just like 429
* 0.2.0 - 2015-06-28 - Added repository link (meant to go 0.2 in prior version)
* 0.1.3 - 2015-06-27 - Added document operations. Removed blacklist hack.
* 0.1.2 - 2015-05-11 - Changed entry point to work via npm
* 0.1.1 - 2015-05-04 - Fixed `cake publish`
* 0.1.0 - 2015-05-03 - Initial release


## To-do (pull requests desired) ##

### Documentation ###

Because Microsoft uses JSDoc for its library, I've decided to use it also. that said, I don't yet have any documentation generation in place. That's pretty high on my list to do myself but it's also a good candidate for pull requests if anyone wants to help. Use this approach to document the CoffeeScript.

```
###*
# Sets the language and redraws the UI.
# @param {object} data Object with `language` property
# @param {string} data.language Language code
###
handleLanguageSet: (data) ->
```

outputs

```
/**
 * Sets the language and redraws the UI.
 * @param {object} data Object with `language` property
 * @param {string} data.language Language code
 */
handleLanguageSet: function(data) {}
```

### Tests ###

I use the relatively simplistic documentdb-mock for writing automated tests for my own stored procedures and I regularly exercise documentDBUtils in the course of running those stored procedures. I also have done extensive exploratory testing on DocumentDB's behavior using documentDBUtils... even finding some edge cases in DocumentDB's behavior. :-) However, you cannot run DoucmentDB locally and I don't have the patience to fully mock it out so there are currently less than full test coverage.


## MIT License ##

Copyright (c) 2015, 2016 Lawrence S. Maccherone, Jr.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
and associated documentation files (the "Software"), to deal in the Software without 
restriction, including without limitation the rights to use, copy, modify, merge, publish, 
distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the 
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or 
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.





