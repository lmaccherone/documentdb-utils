exports.hello = () ->
  getContext().getResponse().setBody('Hello world!')