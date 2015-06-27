Function.prototype.injected1 = injected2

first = () ->
  injected1()

injected2 = () ->
  console.log('nope')

second = () ->
  injected1: () ->
    console.log('Well I will be')

first()