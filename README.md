# documentDBUtils #

Copyright (c) 2015, Lawrence S. Maccherone, Jr.

_Easy-of-use and enterprise-class robustness wrapper for Azure's DocumentDB API_

The node.js client for Microsoft Azure DocumentDB is a thin wrapper around the REST API. That's fine but it means that you need to deal with all the complications of throttling retries, the restoring and continuation of stored procedures that have reached their resource limits, etc. Also, every operation requires that you have the link to the database, collection, stored procedure, etc. You currently have to fetch the links yourself by first querying for them using the human readable IDs further complicating your already mind-boggling-hard-to-write async code.

In summary, documentDBUtils takes care of all of this for you and makes it much easier to use Microsoft Azure DocumentDB from node.js.


## Source code ##

* [Source Repository](https://github.com/lmaccherone/documentdb-utils)


## Features ##

### Working ###

* All Stored Procedure operations

* All single-document operations (except Attachments) 

* Use the human readable IDs to perform operations rather than needing to pre-fetch the database, collection, or entity links.

* Automatically handles 429 throttling responses by delaying the specified amount of time and retrying.

* Automatically deals with early termination of stored procedures for exceeding resources. Just follow a simple pattern (memoization like that used in a reduce function) for writing your stored procedures. The state will be shipped back to the calling side and the stored procedure will be called again picking back up right where it left off.

* Full traceability while executing by setting debug=true.

* Stats on setup time, stored procedure execution time, time lost to throttling, number of stored procedure continuations were required, etc.

### Unimplemented ###

* Triggers, UDFs, and Attachments.

* Queries and bulk document reads.

* Delete Databases or Collections. We automatically create them if they are referenced, but we have no funtionality for deleting them.


## Install ##

`npm install -save documentdb-utils`


## Usage ##

### A Stored Procedure Example ###

Let's say you wrote this little stored procedure and saved it in hello.coffee.

    exports.hello = () ->
      getContext().getResponse().setBody('Hello world!')
      
or if you prefer JavaScript saved in hello.js.

    exports.hello = function () {
      getContext().getResponse().setBody('Hello world!');
    }
   
Now let's write some CoffeeScript (or equivalent JavaScript) to send and execute this on the server:

    documentDBUtils = require('documentdb-utils')
  
    {hello} = require('./hello')
  
    config =
      databaseID: 'test-stored-procedure'
      collectionID: 'test-stored-procedure'
      storedProcedureID: 'hello'
      storedProcedureJS: hello
      memo: {}
  
    processResponse = (err, response) ->
      if err?
        throw err
      console.log(response.memo)
    
    documentDBUtils(config, processResponse)
  
Execute with something like: `coffee tryHello.coffee`. You should see `Hello world!` as your output.

Note, that we did not include any authorization information or connection strings in our config. That's because it will pull from these two environment variables:

* DOCUMENT_DB_URL - The URL for the DocumentDB
* DOCUMENT_DB_KEY - The API key

Alternatively, you can provide `config.urlConnection` and `config.auth.masterKey` or any other valid `config.auth` as specified by the DocumentDB API.
  
Also, note that the response includes information about the execution. Add `console.log(response.stats)` to the end of your processResponse function to see timings for setup, execution, and lost to throttling as well as the number of round-trips to to stored procedure yields, etc.

Additionally, the response comes back with the links (and full objects) for whatever it needed to fetch to do its job. For this example, it will have `database`, `databaseLink`, `collection`, `collectionLink`, `storedProcedure`, and `storedProcedureLink` fields added to it. You can cache these to speed up subsequent work. For instance, the code below will create the stored procedure and execute (just as we did above) but use the returning storedProcedureLink to execute it a second time, much faster:

    documentDBUtils = require('documentdb-utils')
    
    {hello} = require('./hello')
    
    config =
      databaseID: 'test-stored-procedure'
      collectionID: 'test-stored-procedure'
      storedProcedureID: 'hello'
      storedProcedureJS: hello
      memo: {}
    
    processResponse = (err, response) ->
      if err?
        throw err
      console.log('First execution including sending stored procedure to DocumentDB')
      console.log(response.memo)
      console.log(response.stats)
      
      config2 =
        storedProcedureLink: response.storedProcedureLink
        memo: {}
      documentDBUtils(config2, (err, response) ->
        if err
          throw err
        console.log('\nSecond execution')
        console.log(response.memo)
        console.log(response.stats)
      )
    
    documentDBUtils(config, processResponse)

And here is its output.

    First execution including sending stored procedure to DocumentDB
    Hello world!
    { executionRoundTrips: 1,
      setupTime: 1184,
      executionTime: 304,
      timeLostToThrottling: 0,
      totalTime: 1488 }
    
    Second execution
    Hello world!
    { executionRoundTrips: 1,
      setupTime: 0,
      executionTime: 404,
      timeLostToThrottling: 0,
      totalTime: 404 }
    
Notice how documentDBUtils figures out what you want to do by what you send to it. Here's a table of what operations are performed based upon what you send to it.

| ...ID, ...Link or full entity | storedProcedureJS | memo | Operation          |
| :---------------------------: | :---------------: | :--: | :----------------: |
| Yes                           | Yes               | Yes  | Upsert and Execute |
| Yes                           | No                | Yes  | Execute            |
| Yes                           | Yes               | No   | Upsert             |
| Yes                           | No                | No   | Delete             |

### Document Operations ###

Document operations work pretty much the same way. Give it the right fields in the config object and documentDBUtils figures out what to do with it. The following table determines which document operations are performed with a given set of config fields:

| documentLink | oldDocument | document | Operation |
| :----------: | :---------: | :------: | :-------: |
| No           | No          | Yes      | Create    |
| Yes          | No          | No       | Read      |
| Yes          | Yes         | Yes      | Update*   |
| No           | Yes         | Yes      | Update*   |
| Yes          | No          | Yes      | Replace   |
| Yes          | Yes         | No       | Delete    |
| No           | Yes         | No       | Delete    |

For Delete, we don't actually need the entire oldDocument. We simply need the _etag field. If you do not supply the documentLink seperately, we will pull both the documentLink and the needed _etag fields from the oldDocument.

\* Note, at this time, Update and Replace are actually full replace operations. It's my intent to upgrade it so that on update operations, if you provide only a partial list of fields, it will pull the remaining fields from the oldDocument and be a true update operation. The replace operation will still be triggerable by not supplying an oldDocument. 


## Pattern for writing stored procedures ##

**The key to a general pattern for writing restartable stored procedures is to write them as if you were writing a reduce() function.**

Note, if you follow this pattern, documentDBUtils automatically deals with early termination of stored procedures for exceeding resources. Just follow this simple pattern. The state will be shipped back to the calling side and the stored procedure will be called again picking back up right where it left off.

Pehaps the most common use of stored procedures is to aggregate or transform data. It's very easy to think of these as "reduce" operations just like Array.reduce() or the reduce implementations in underscore, async.js, or just about any other library with aggregation functionality. It stretches the "reduce" metaphore a bit, but the pattern itself is perfectly usefull even for stored procedures that write data.

So:

1. Only accept one parameter -- a JavaScript Object. Let's name it `memo`.
1. Support an empty or missing `memo` on the initial call.
1. Store any variable that represents the current running state of the stored procedure into the `memo` object.
1. Store the `continuation` field returned by readDocuments and queryDocuments into `memo.continuation`.
1. Optionally store any internal visibility (debugging, timings, etc.) into the `memo` object.
1. Call `getContext().getResponse().setBody(memo)` regulary, particularly right after you kick off a collection operation (readDocuments, createDocument, etc.).
1. If `false` is returned from the last prior call to an async operation, don't issue any more async calls. Rather, wrap up the stored procedure quickly. Note, it's unclear to me that the call that returned false is guaranteed to finish, so I've resorted to writing my stored procedures so they will restart correctly whether they fail or not. That said, I have not experienced a case where the last call failed to complete.
1. Optionally, wrap up early when the stored procedure exceeds other constraints. My super-duper count example below implements both maxRowCount and maxExecutionTime constraints.

Here is an example of a stored procedure that counts all the documents in a collection with an option to filter based upon provided filterQuery field in the initial memo. The source for this is included in this repository.

    count = (memo) ->
    
      collection = getContext().getCollection()
    
      unless memo?
        memo = {}
      unless memo.count?
        memo.count = 0
      unless memo.continuation?
        memo.continuation = null
    
      stillQueuingOperations = true
    
      query = (responseOptions) ->
    
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
    
    exports.count = count


## Changelog ##

* 0.2.3 - 2015-06-30 - Restored the delete, upsert, and retry logic but this time only if you get a 403 error and message indicating blacklisting
* 0.2.2 - 2015-06-30 - Revert to blacklisting hack because the bug doesn't seem to be fixed
* 0.2.1 - 2015-06-30 - Handle 408 error by retrying just like 429
* 0.2.0 - 2015-06-28 - Added repository link (meant to go 0.2 in prior version)
* 0.1.3 - 2015-06-27 - Added document operations. Removed blacklist hack.
* 0.1.2 - 2015-05-11 - Changed entry point to work via npm
* 0.1.1 - 2015-05-04 - Fixed `cake publish`
* 0.1.0 - 2015-05-03 - Initial release


## Contributing to documentDBUtils ##

### Triggers, UDFs, Queries, and Attachments ###

As of 2015-05-03, documentDBUtils only supports stored procedures and single-document operations. If you need them, add them and submit a pull request.

### Delete Databases or Collections ###

Should be easy.

### Explicitly specify an operation ###

I realize that this design decision of automatically choosing an operation based upon which config.fields are provided might be controversial. If we added an optional "operation" field, then we could check to confirm that they provided the right config fields for that operation.

### What about promises? ###

Promises make the writing of waterfall pattern async much easier. However, I find that they make the writing of complicated ascyn patterns like retries and branching based upon the results of a response much harder. So, I have chosen not to use promises in the implementation of documentDBUtils.

That said, since all of the complex async code is encapsulated inside of documentDBUtils, I want to implement a promises wrapper for documentDBUtils. I would gladly accept a pull-request for this.

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

I use the relatively simplistic documentdb-mock for writing automated tests for my own stored procedures and I regularly exercise documentDBUtils in the course of running those stored procedures. I also have done extensive exploratory testing on DocumentDB's behavior using documentDBUtils... even finding some edge cases in DocumentDB's behavior. :-) However, you cannot run DoucmentDB locally and I don't have the patience to fully mock it out so there are currently no automated tests.

### Command line support ###

At the very least it would be nice to provide a "binary" (really just CoffeeScript that starts with #!) that does the count of a collection with optional command-line parameter for filterQuery.

However, it might also be nice to create a full CLI that would allow you to specify JavaScript (or even CoffeeScript) files that get pushed to stored procedures and executed. We'd have to support all of the same parameters. Then again, this might be unused functionality.


## MIT License ##

Copyright (c) 2015 Lawrence S. Maccherone, Jr.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated 
documentation files (the "Software"), to deal in the Software without restriction, including without limitation 
the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and 
to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED 
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF 
CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS 
IN THE SOFTWARE.





