return function(sources)
  local ui = interval(100):map(pipe(
    String,
    prepend('Hello World: '),
    Raw
  ))

  return {
    ui=ui,
    stop=of(true):delay(2500)
  }
end
