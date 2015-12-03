path = require('path')
expandSproc = require(path.join(__dirname, '..', 'src', 'expandSproc'))

exports.expandSprocTest =

  expandSprocTest: (test) ->

    expected = '''
      function () {
          var mixinToInsert, mixinToInsert2, x, y;
          x = 1;
          mixinToInsert = function () {
              var z;
              z = 3;
              return z;
            };

          mixinToInsert2 = {
            f1: function () {
                var mixinToInsert3, z;
                mixinToInsert3 = function () {
                    var z;
                    z = 3000;
                    return z;
                  };

                z = 300;
                return z;
              },
            f2: function (x) {
                return x * 2;
              }
          };
          return y = 2;
        }
    '''

    result = expandSproc(path.join('..', 'test-examples', 'sprocToExpand'))
    test.equal(result.body, expected)
    test.equal(result.id, 'sprocToExpand')

    test.done()