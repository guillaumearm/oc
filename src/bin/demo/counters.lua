-- Counter cycle example

local runCycle = require('cycle')
local Button = require('cycle/Button')

local beep = require('component').computer.beep

local InputText = function(setText)
  setText = setText or NEVER
  local textState = of('initial'):merge(setText)

  local ui = textState:map(rightPad(20), View)
    -- return {
    --   ui=ui,
    -- }
    return ui
end

local Counter = function(initialValue)
  initialValue = initialValue or 0

  local clickPlus = Subject.create()
  local clickMinus = Subject.create()

  local buttonPlus = Button('+', clickPlus)
  local buttonMinus = Button('-', clickMinus)

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

  local buttonRemoveCounter = of(View('delete'))
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

  local inputText = InputText()

  local ui = combineLatest(inputText, buttonAddCounter, buttonRemoveCounter, countersView)
    :map(vertical)
    :map(withBgColor('orange'))

  return {
    ui=ui
  }
end

runCycle(mainCycle, {}, true, true):unsubscribe()