return function()
  local ui = interval(100):map(compose(
    View,
    prepend('Hello World: '),
    String
  ))

  return {
    ui=ui,
    stop=of(true):delay(2500)
  }
end
