-- Counter cycle example

return function(sources)
  local clickPlus = Subject.create()
  local clickMinus = Subject.create()

  local buttonPlus = of(View('+'))
    :map(withOnClick(clickPlus))

  local buttonMinus = of(View('-'))
    :map(withOnClick(clickMinus))

  local counterValue = clickPlus:map(always('inc'))
    :merge(clickMinus:map(always('dec')))
    :startWith('init')
    :scan(toReducer(handleActions({
      inc=always(add(1)),
      dec=always(add(-1)),
    })), 0)

  local ui = counterValue
    :map(compose(View, String))
    :combineLatest(buttonPlus, buttonMinus, function(v, plus, minus)
      return vertical(plus, v, minus)
    end)

  return {
    ui=ui,
    stop=counterValue:filter(either(equals(42), equals(-42))):delay(100)
  }
end
