return function(sources)
  return {
    ui=interval(100):map(String):map(Raw),
    uiClear=sources.stop,
    stop=of(true):delay(2500)
  }
end
