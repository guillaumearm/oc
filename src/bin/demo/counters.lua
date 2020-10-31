-- Counter cycle example

local runCycle = require('cycle')

local beep = require('component').computer.beep

local Counter = function(initialValue)
  initialValue = initialValue or 0

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
      dec=always(add(-1)),
    }, initialValue)

  local counterValueView = counterValue:map(compose(View, String))

  local ui = combineLatest(buttonPlus, counterValueView, buttonMinus):map(vertical)

  return ui:map(withClick(cb(beep))):shareReplay(1)
end

local function mainCycle()
  local addCounter = Subject.create()
  local removeCounter = Subject.create()

  local buttonAddCounter = of(View('add'))
    :map(withOnClick(addCounter))
    :map(withColor('yellow'))
    :map(withBgColor('red'))

  local buttonRemoveCounter = of(View('deletet'))
    :map(withOnClick(removeCounter))
    :map(withColor('blue'))
    :map(withBgColor('red'))

  local counters = addCounter:mapTo('add')
    :merge(removeCounter:mapTo('remove'))
    :startWith('init')
    :scanActions({
      add=function() return append(Counter(0)) end,
      remove=function() return dropLast(1)  end
    }, {Counter(0), Counter(0), Counter(0)})

  local countersView = counters:switchMap(function(cs)
    if isEmpty(cs) then
      return of(vertical('', '', ''))
    end
    return combineLatest(unpack(cs)):map(horizontal)
  end):map(withBgColor('red'))

  local ui = combineLatest(buttonAddCounter, buttonRemoveCounter, countersView)
    :map(vertical)
    :map(withBgColor('orange'))

  return {
    ui=ui
  }
end

runCycle(mainCycle, {}, true, true):unsubscribe()