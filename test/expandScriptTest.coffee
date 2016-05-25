path = require('path')
expandScript = require(path.join(__dirname, '..', 'src', 'expandScript'))

exports.expandScriptTest =

  expandScriptTest: (test) ->

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

    result = expandScript(path.join('..', 'test-examples', 'sprocToExpand'))
    test.equal(result.body, expected)
    test.equal(result.id, 'sprocToExpand')

    test.done()


  expandPrimativesTest: (test) ->
    expected = '''
      function () {
          var x, y;
          x = {
            number: 1,
            string: "hello",
            booleanTrue: true,
            booleanFalse: false,
            specialNull: null,
            specialNaN: null,
            f: function () {
                  return "hello";
                }
          };
          y = 1;

        }
    '''

    result = expandScript(path.join('..', 'test-examples', 'primativeToExpand'))
    test.equal(result.body, expected)
    test.equal(result.id, 'primativeToExpand')

    test.done()

  referenceElementsTest: (test) ->
    expected = '''
      function () {
          var a, f, f1, f2;
          f = function () {
                return "hello";
              };

          f1 = function () {
                var mixinToInsert3, z;
                mixinToInsert3 = function () {
                    var z;
                    z = 3000;
                    return z;
                  };

                z = 300;
                return z;
              };

          f2 = function (x) {
                return x * 2;
              };

          a = "something";

        }
    '''
    result = expandScript(path.join('..', 'test-examples', 'referenceElementToExpand'))
    test.equal(result.body, expected)
    test.equal(result.id, 'referenceElementToExpand')

    test.done()