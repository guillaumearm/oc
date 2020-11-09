-- Counter cycle example

local runCycle = require('cycle')
local Button = require('cycle/Button')
local InputText = require('cycle/InputText')
local ListScroll = require('cycle/ListScroll')

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

  return ui:shareReplay(1)
end

local function mainCycle()
  local addCounter = Subject.create()
  local removeCounter = Subject.create()

  local buttonAddCounter = of(View('add'))
    :map(withScopedClick(addCounter))
    :map(withColor('yellow'))
    :map(withBgColor('red'))

  local buttonRemoveCounter = of(View('delete'))
    :map(withScopedClick(removeCounter))
    :map(withColor('blue'))
    :map(withBgColor('red'))

  local counters = addCounter:mapTo('add')
    :merge(removeCounter:mapTo('remove'))
    :startWith('init')
    :scanActions({
      add=function() return append(Counter(0)) end,
      remove=function() return dropLast(1)  end
    }, {Counter(0), Counter(0), Counter(0)}):shareReplay(1)

  local onScrollCounters = Subject.create()
  local scrollableCounters = ListScroll(counters, of(2), onScrollCounters);

  local countersView = scrollableCounters:switchMap(function(cs)
    if isEmpty(cs) then
      return of(vertical('', '', ''))
    end
    return combineLatest(unpack(cs)):map(horizontal)
  end)
    :map(withBgColor('red'))
    :map(withScroll(onScrollCounters))

  local setInput = Subject.create()

  local inputFirstName, onSubmitFirstName = InputText(setInput)
  local labeledInputFirstName = inputFirstName:map(function(x)
    return horizontal(View('First Name: '), x)
  end)

  local inputLastName, onSubmitLastName = InputText(setInput)
  local labeledInputLastName = inputLastName:map(function(x)
    return horizontal(View('Last Name: '), x)
  end)

  local cleanInputFx = merge(onSubmitFirstName, onSubmitLastName):mapFx(cb(setInput, ''))

  local ui = combineLatest(
    labeledInputFirstName,
    labeledInputLastName,
    buttonAddCounter,
    buttonRemoveCounter,
    countersView
  )
    :map(vertical)
    :map(withBgColor('orange'))
    :map(withClick(cb(beep)))

  return {
    ui=ui,
    fx=cleanInputFx
  }
end

runCycle(mainCycle, {}, true, true):unsubscribe()