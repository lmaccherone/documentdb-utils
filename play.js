// Generated by CoffeeScript 1.9.2
(function() {
  var first, injected2, second;

  Function.prototype.injected1 = injected2;

  first = function() {
    return injected1();
  };

  injected2 = function() {
    return console.log('nope');
  };

  second = function() {
    return {
      injected1: function() {
        return console.log('Well I will be');
      }
    };
  };

  first();

}).call(this);

//# sourceMappingURL=play.js.map
