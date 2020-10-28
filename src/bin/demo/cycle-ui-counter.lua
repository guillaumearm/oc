-- Counter cycle example

return function(sources)
  local initialValue = sources.initialValue or 0

  local clickPlus = Subject.create()
  local clickMinus = Subject.create()

  local buttonPlus = of(View('+'))
    :map(withOnClick(clickPlus))

  local buttonMinus = of(View('-'))
    :map(withOnClick(clickMinus))

  local counterValue = clickPlus:map(always('inc'))
    :merge(clickMinus:map(always('dec')))
    :startWith('init')
    :scanActions({
      inc=always(add(1)),
      dev=always(add(1)),
    }, initialValue)

  local counterValueView = counterValue:map(compose(View, String))

  local ui = combineLatest(buttonPlus, counterValueView, buttonMinus)
    :map(vertical)

  return {
    ui=ui,
    stop=counterValue:filter(either(equals(42), equals(-42))):delay(100)
  }
end
