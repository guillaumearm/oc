return function(sources)
  local hello = of('Hello World!')
  local onStop = sources.stop:map(always("Bye!"))

  return {
    print=hello:concat(interval(100):merge(onStop)),
    stop=of(true):delay(2500)
  }
end
