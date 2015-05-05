exports.hello = function() {
  return getContext().getResponse().setBody('Hello world!');
}
