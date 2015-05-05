// Generated by CoffeeScript 1.9.2
(function() {
  var DocumentClient, documentDBUtils, utils;

  DocumentClient = require("documentdb").DocumentClient;

  utils = {};

  utils.clone = function(obj) {
    var flags, key, newInstance;
    if ((obj == null) || typeof obj !== 'object') {
      return obj;
    }
    if (obj instanceof Date) {
      return new Date(obj.getTime());
    }
    if (obj instanceof RegExp) {
      flags = '';
      if (obj.global != null) {
        flags += 'g';
      }
      if (obj.ignoreCase != null) {
        flags += 'i';
      }
      if (obj.multiline != null) {
        flags += 'm';
      }
      if (obj.sticky != null) {
        flags += 'y';
      }
      return new RegExp(obj.source, flags);
    }
    newInstance = new obj.constructor();
    for (key in obj) {
      newInstance[key] = utils.clone(obj[key]);
    }
    return newInstance;
  };


  /**
   * Main function. You can pretty much do everything by calling this with the desired configuration.
   * @param {object} userConfig Your configuration
   */

  documentDBUtils = function(userConfig, callback) {
    var callCallback, config, debug, delay, deleteAndUpsertStoredProcedure, deleteOrExecuteStoredProcedure, executeStoredProcedure, executionRoundTrips, executionStartTick, getCollectionLink, getDatabaseLink, getStoredProcedureFromID, masterKey, options, processError, processResponse, startTick, timeLostToThrottling, trySomething, tryStoredProcedure, upsertStoredProcedure, urlConnection;
    options = {
      client: "If you've already instantiated the DocumentClient pass it in with this.",
      auth: 'Allow for full configuration of auth per DocumentClient API.',
      masterKey: 'Will pull from DOCUMENT_DB_KEY environment variable if not specified.',
      urlConnection: 'Will pull from DOCUMENT_DB_URL environment variable if not specified.',
      database: "If you've already fetched it, use this.",
      databaseLink: "Alternatively, use the self link.",
      databaseID: 'Readable ID.',
      collection: "If you've already fetched it, use this.",
      collectionLink: "Alternatively, use the self link.",
      collectionID: 'Readable ID.',
      storedProcedure: "If you've already fetched it, use this.",
      storedProcedureLink: "Alternatively, use the self link.",
      storedProcedureID: 'Readable ID.',
      storedProcedureJS: 'The JavaScript or its toString()',
      memo: 'Object containing parameters and initial memo values for stored procedure. Must send at least {} to trigger execution.',
      debug: 'Default: false. Set to true if you want progress messages.'
    };
    config = utils.clone(userConfig);
    config.debug = config.debug || false;
    executionRoundTrips = 0;
    startTick = new Date().getTime();
    executionStartTick = null;
    timeLostToThrottling = 0;
    debug = function(message, content) {
      if (config.debug) {
        console.log(message);
        if (content != null) {
          console.dir(content);
          return console.log();
        }
      }
    };
    if (config.client == null) {
      if (config.urlConnection == null) {
        urlConnection = process.env.DOCUMENT_DB_URL;
        if (urlConnection != null) {
          config.urlConnection = urlConnection;
        } else {
          callCallback('Missing urlConnection.');
        }
      }
      if (config.auth == null) {
        masterKey = process.env.DOCUMENT_DB_KEY;
        if (masterKey != null) {
          config.auth = {
            masterKey: masterKey
          };
        } else {
          callCallback('Missing auth or masterKey.');
        }
      }
      config.client = new DocumentClient(config.urlConnection, config.auth);
    }
    trySomething = function() {
      debug('trySomething()');
      if ((config.collectionLink != null) || (config.storedProcedureLink != null)) {
        if (tryStoredProcedure()) {

        } else {
          return callCallback('No stored procedure, trigger, UDF or document operations specified.');
        }
      } else {
        return getCollectionLink();
      }
    };
    tryStoredProcedure = function() {
      debug('tryStoredProcedure()');
      if (config.storedProcedureJS != null) {
        upsertStoredProcedure();
        return true;
      } else if (config.storedProcedureLink != null) {
        debug("storedProcedureLink", config.storedProcedureLink);
        deleteOrExecuteStoredProcedure();
        return true;
      } else if (config.storedProcedure != null) {
        config.storedProcedureLink = config.storedProcedure._self;
        debug("storedProcedure", config.storedProcedure);
        executeStoredProcedure();
        return true;
      } else if (config.storedProcedureID != null) {
        debug("storedProcedureID", config.storedProcedureID);
        getStoredProcedureFromID();
        return true;
      } else {
        return false;
      }
    };
    delay = function(ms, func) {
      return setTimeout(func, ms);
    };
    processError = function(err, header, toRetryIf429, nextIfNot429) {
      var retryAfter;
      if (nextIfNot429 == null) {
        nextIfNot429 = null;
      }
      debug('processError()');
      if (err.code === 429) {
        retryAfter = Number(header['x-ms-retry-after-ms']);
        timeLostToThrottling += retryAfter;
        debug("Throttled. Retrying after delay of " + retryAfter + "ms");
        return delay(retryAfter, toRetryIf429);
      } else if (nextIfNot429 != null) {
        return nextIfNot429();
      } else {
        return callCallback(err);
      }
    };
    getStoredProcedureFromID = function() {
      debug('getStoredProcedureFromID()');
      debug('collectionLink', config.collectionLink);
      return documentDBUtils.fetchStoredProcedure(config.client, config.collectionLink, config.storedProcedureID, function(err, response, header) {
        if (err != null) {
          return processError(err, header, getStoredProcedureFromID, upsertStoredProcedure);
        } else {
          debug("response from call to fetchStoredProcedure in getStoredProcedureFromID", response);
          config.storedProcedure = response;
          config.storedProcedureLink = response._self;
          return deleteOrExecuteStoredProcedure();
        }
      });
    };
    upsertStoredProcedure = function() {
      debug('upsertStoredProcedure()');
      if (config.storedProcedureID == null) {
        callCallback('Missing storedProcedureID');
      }
      if (config.storedProcedureJS == null) {
        callCallback('Missing storedProcedureJS');
      }
      return documentDBUtils.upsertStoredProcedure(config.client, config.collectionLink, config.storedProcedureID, config.storedProcedureJS, function(err, response, header) {
        if (err != null) {
          return processError(err, header, upsertStoredProcedure);
        } else {
          config.storedProcedure = response;
          config.storedProcedureLink = response._self;
          return executeStoredProcedure();
        }
      });
    };
    deleteOrExecuteStoredProcedure = function() {
      debug('deleteOrExecuteStoredProcedure()');
      if (config.memo != null) {
        if (executionStartTick == null) {
          executionStartTick = new Date().getTime();
        }
        return config.client.executeStoredProcedure(config.storedProcedureLink, config.memo, processResponse);
      } else {
        return config.client.deleteStoredProcedure(config.storedProcedureLink, function(err, response, header) {
          if (err != null) {
            return processError(err, header, deleteOrExecuteStoredProcedure);
          } else {
            debug('Stored Procedure Deleted');
            return callCallback(null);
          }
        });
      }
    };
    executeStoredProcedure = function() {
      debug('executeStoredProcedure()');
      if (config.memo != null) {
        if (executionStartTick == null) {
          executionStartTick = new Date().getTime();
        }
        return config.client.executeStoredProcedure(config.storedProcedureLink, config.memo, processResponse);
      } else {
        return callCallback(null);
      }
    };
    processResponse = function(err, response, header) {
      debug('processResponse()');
      debug('err', err);
      debug('response', response);
      debug('header', header);
      if (err != null) {
        return processError(err, header, executeStoredProcedure);
      } else {
        executionRoundTrips++;
        config.memo = response;
        if (response.continuation != null) {
          if (response.stillResources) {
            return executeStoredProcedure();
          } else {
            return deleteAndUpsertStoredProcedure();
          }
        } else {
          return callCallback(null);
        }
      }
    };
    deleteAndUpsertStoredProcedure = function() {
      var ref;
      debug('Got out of resources messages on this stored procedure. Deleting and upserting.');
      config.storedProcedureJS = config.storedProcedureJS || ((ref = config.storedProcedure) != null ? ref.body : void 0);
      if (config.storedProcedureJS != null) {
        return config.client.deleteStoredProcedure(config.storedProcedureLink, function(err, response, header) {
          if (err != null) {
            return processError(err, header, deleteAndUpsertStoredProcedure);
          } else {
            delete config.storedProcedure;
            delete config.storedProcedureLink;
            return upsertStoredProcedure();
          }
        });
      } else {
        return callCallback('Need storedProcedureJS to overcome resource constraint.');
      }
    };
    getCollectionLink = function() {
      debug('getCollectionLink()');
      if (config.collectionLink != null) {
        debug("collectionLink", config.collectionLink);
        return trySomething();
      } else if (config.collection != null) {
        debug("collection", config.collection);
        config.collectionLink = config.collection._self;
        return trySomething();
      } else if (config.collectionID != null) {
        debug("collectionID", config.collectionID);
        if (config.databaseLink != null) {
          return documentDBUtils.getOrCreateCollection(config.client, config.databaseLink, config.collectionID, function(err, response, header) {
            if (err != null) {
              return processError(err, header, getCollectionLink);
            } else {
              debug('response from call to getOrCreateCollection in getCollectionLink', response);
              config.collection = response;
              config.collectionLink = response._self;
              return trySomething();
            }
          });
        } else {
          return getDatabaseLink();
        }
      } else {
        return callCallback('Missing collection information.');
      }
    };
    getDatabaseLink = function() {
      debug('getDatabaseLink()');
      if (config.databaseLink != null) {
        return trySomething();
      } else if (config.database != null) {
        config.databaseLink = config.database._self;
        return trySomething();
      } else if (config.databaseID != null) {
        debug('calling');
        return documentDBUtils.getOrCreateDatabase(config.client, config.databaseID, function(err, response, header) {
          if (err != null) {
            return processError(err, header, getDatabaseLink);
          } else {
            debug('response to call to getOrCreateDatabase in getDatabaseLink', response);
            config.database = response;
            config.databaseLink = response._self;
            return trySomething();
          }
        });
      } else {
        return callCallback('Missing database information.');
      }
    };
    callCallback = function(err) {
      var endTick, stats;
      endTick = new Date().getTime();
      stats = {};
      debug("\n");
      if (executionStartTick != null) {
        stats.executionRoundTrips = executionRoundTrips;
        stats.setupTime = executionStartTick - startTick;
        stats.executionTime = endTick - executionStartTick;
        stats.timeLostToThrottling = timeLostToThrottling;
        debug("Execution round trips (not counting setup or throttling errors): " + stats.executionRoundTrips);
        debug("Setup time: " + stats.setupTime + "ms");
        debug("Execution time: " + stats.executionTime + "ms");
        debug("Time lost to throttling: " + stats.timeLostToThrottling + "ms");
      }
      stats.totalTime = endTick - startTick;
      debug("Total time: " + stats.totalTime + "ms");
      config.stats = stats;
      return callback(err, config);
    };
    return trySomething();
  };


  /**
   * If it exists, this will fetch the database. If it does not exist, it will create the database.
   * @param {Client} client
   * @param {string} databaseID
   * @param {callback} callback
   */

  documentDBUtils.getOrCreateDatabase = function(client, databaseID, callback) {
    var querySpec;
    querySpec = {
      query: "SELECT * FROM root r WHERE r.id=@id",
      parameters: [
        {
          name: "@id",
          value: databaseID
        }
      ]
    };
    return client.queryDatabases(querySpec).toArray(function(err, results) {
      var databaseSpec;
      if (err) {
        return callback(err);
      } else {
        if (results.length === 0) {
          databaseSpec = {
            id: databaseID
          };
          return client.createDatabase(databaseSpec, function(err, created) {
            if (err) {
              return callback(err);
            } else {
              return callback(null, created);
            }
          });
        } else {
          return callback(null, results[0]);
        }
      }
    });
  };

  documentDBUtils.getOrCreateCollection = function(client, databaseLink, collectionID, callback) {
    var querySpec;
    querySpec = {
      query: "SELECT * FROM root r WHERE r.id=@id",
      parameters: [
        {
          name: "@id",
          value: collectionID
        }
      ]
    };
    return client.queryCollections(databaseLink, querySpec).toArray(function(err, results) {
      var collectionSpec, requestOptions;
      if (err) {
        return callback(err);
      } else {
        if (results.length === 0) {
          collectionSpec = {
            id: collectionID
          };
          requestOptions = {
            offerType: "S1"
          };
          return client.createCollection(databaseLink, collectionSpec, requestOptions, function(err, created) {
            if (err) {
              return callback(err);
            } else {
              return callback(null, created);
            }
          });
        } else {
          return callback(null, results[0]);
        }
      }
    });
  };

  documentDBUtils.upsertStoredProcedure = function(client, collectionLink, storedProcID, storedProc, callback) {
    var querySpec;
    querySpec = {
      query: "SELECT * FROM root r WHERE r.id=@id",
      parameters: [
        {
          name: "@id",
          value: storedProcID
        }
      ]
    };
    return client.queryStoredProcedures(collectionLink, querySpec).toArray(function(err, results) {
      var sprocLink, storedProcSpec;
      if (err) {
        return callback(err);
      } else {
        storedProcSpec = {
          id: storedProcID,
          body: storedProc
        };
        if (results.length === 0) {
          return client.createStoredProcedure(collectionLink, storedProcSpec, function(err, created) {
            if (err) {
              return callback(err);
            } else {
              return callback(null, created);
            }
          });
        } else {
          sprocLink = results[0]._self;
          return client.replaceStoredProcedure(sprocLink, storedProcSpec, function(err, replaced) {
            if (err) {
              return callback(err);
            } else {
              return callback(null, replaced);
            }
          });
        }
      }
    });
  };

  documentDBUtils.fetchStoredProcedure = function(client, collectionLink, storedProcID, callback) {
    var querySpec;
    querySpec = {
      query: "SELECT * FROM root r WHERE r.id=@id",
      parameters: [
        {
          name: "@id",
          value: storedProcID
        }
      ]
    };
    return client.queryStoredProcedures(collectionLink, querySpec).toArray(function(err, results) {
      if (err) {
        return callback(err);
      } else if (results.length === 0) {
        return callback("Could not find stored procedure " + storedProcID + ".");
      } else {
        return callback(null, results[0]);
      }
    });
  };

  exports.documentDBUtils = documentDBUtils;

}).call(this);

//# sourceMappingURL=documentDBUtils.js.map
