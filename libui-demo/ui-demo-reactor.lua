local colors = require('colors')
local runUI = import('ui/run')
local event = require('event')
local c = require('component')
local gpu = c.gpu
local os = require('os')

local cb = function(fn, ...)
  local args = pack(...)
  return function()
    return fn(unpack(args))
  end
end

local beep = c.computer.beep

local reactor = c.br_reactor

local reactorIsEnabled = reactor.getActive()

local enableReactor = function()
  if reactorIsEnabled then return; end

  reactor.setActive(true)
  reactorIsEnabled = true
  beep(440, 0.1)
  beep(440, 0.1)
end

local disableReactor = function()
  if not reactorIsEnabled then return; end

  reactor.setActive(false)
  reactorIsEnabled = false
  beep(500, 0.2)
end

------------------------------------------------------------------------------------------------
local w1 = 15
local w2 = 6
local w3 = 30
local totalW = w1 + w2 + w3

local minBuffer = 10
local maxBuffer = 95

------------------------------------------------------------------------------------------------

local createHorizontalBar = function(color)
  return pipe(
    function(n) return string.rep(' ', n) end,
    Raw,
    withBackgroundColor(color)
  )
end

local RedBar = createHorizontalBar('red')
local GreenBar = createHorizontalBar('green')

local Gauge = pipe(
  ui(function(width, perc)
    local ratio = perc / 100
    local completed = math.floor(width * ratio)
    local rest = width - completed
    return {
      content={
        {GreenBar(completed), RedBar(rest)}
      }
    }
  end)
)

------------------------------------------------------------------------------------------------

local Header = pipe(
  centerString(totalW + 2),
  Raw,
  withBackgroundColor('gray')
)

local Border = pipe(
  function(n) return string.rep(' ', n) end,
  Raw,
  withBackgroundColor('gray')
)

local Separator = Header('')

------------------------------------------------------------------------------------------------

local Button = function(str, bgcolor, onClick, w)
  w = w or totalW
  return applyTo(str)(
    centerString(w),
    Raw,
    withBackgroundColor(bgcolor),
    withClick(onClick or '')
  )
end

------------------------------------------------------------------------------------------------

local ReactorApp = ui(function(state)
  local rate = state.rate
  local buffer = state.buffer
  local carburant = state.carburant
  local auto = state.auto

  local enabledButton = Button('Active (cliquer pour arreter)', 'green', 'stopAuto')
  local disabledButton = Button('Inactive (cliquer pour demarrer)', 'red', 'startAuto')

  return {
    content={
      {Header('Reacteur')},
      {Border(1), rightPad(w1, 'Buffer interne:'), leftPad(w2, math.floor(buffer)..'% '), Gauge(w3, buffer), Border(1)},
      {Separator},
      {Border(1), rightPad(w1, 'Carburant:'), leftPad(w2, math.floor(carburant)..'% '), Gauge(w3, carburant), Border(1)},
      {Separator},
      {Border(1), rightPad(w1, 'Generation:'), leftPad(w2, math.floor(rate)..' '), rightPad(w3, 'rf/tick'), Border(1)},
      {Separator},
      {Border(1), ternary(auto, enabledButton, disabledButton), Border(1)},
      {Separator}
    }
  }
end)

local App = ui(function(state)
  return {
    content={
      { ReactorApp(state.reactor) }
    }
  }
end)

------------------------------------------------------------------------------------------------

local initialState = 0

local counterUpdater = withInitialState(initialState,
  handleActions({
    tick=always(inc),
    increment=function(e)
      if e.type == 1 then return add(10) end
      return add(1)
    end,
    decrement=function(e)
      if e.type == 1 then return add(-10) end
      return add(-1)
    end
  })
)

local reactorAutoUpdater = withInitialState(true,
  handleActions({
    startAuto=always(always(true)),
    stopAuto=always(always(false))
  })
)

local updateRate = function() return always(reactor.getEnergyProducedLastTick()) end
local reactorRateUpdater = withInitialState(0.0,
  handleActions({
    tick=updateRate,
    ['@init']=updateRate
  })
)

local updateCarburant = function() return always((reactor.getFuelAmount() / reactor.getFuelAmountMax()) * 100) end
local reactorCarburantUpdater = withInitialState(0,
  handleActions({
    tick=updateCarburant,
    ['@init']=updateCarburant
  })
)

local updateBuffer = function() return always((reactor.getEnergyStored() / reactor.getEnergyCapacity()) * 100) end
local reactorBufferUpdater = withInitialState(0,
  handleActions({
    tick=updateBuffer,
    ['@init']=updateBuffer
  })
)

local rootUpdater = combineUpdaters({
  reactor={
    auto=reactorAutoUpdater,
    rate=reactorRateUpdater,
    buffer=reactorBufferUpdater,
    carburant=reactorCarburantUpdater
  }
})

--------------------------------------------------------
local initHandler = captureAction('@init', function(prevState, state)
  if state.reactor.auto and state.reactor.buffer < maxBuffer then
    enableReactor()
  else
    disableReactor()
  end
end)

local terminatedHandler = captureEvent('interrupted', function()
  disableReactor()
end)

local tickHandler = captureAction('tick', function(prevState, state)
  local prevBuffer = prevState.reactor.buffer
  local newBuffer = state.reactor.buffer
  local auto = state.reactor.auto

  if auto and prevBuffer >= minBuffer and newBuffer < minBuffer  then
    enableReactor()
  end

  if auto and prevBuffer < maxBuffer and newBuffer >= maxBuffer then
    disableReactor()
  end
end)

local startAutoHandler = captureAction('startAuto', function(prevState, state)
  if state.reactor.buffer < maxBuffer then
    enableReactor()
  end
end)

local stopAutoHandler = captureAction('stopAuto', function(prevState, state)
  disableReactor()
end)

local mainHandler = pipeHandlers(
  initHandler,
  terminatedHandler,
  tickHandler,
  startAutoHandler,
  stopAutoHandler
)
--------------------------------------------------------

local rootView = App
local rootReducer = toReducer(rootUpdater)
local rootHandler = mainHandler

local intervalId = setInterval(function()
  dispatch('tick')
end, 5000)

local ok, err = pcall(runUI, rootView, rootReducer, rootHandler)
if not ok then printErr(err) end

clearInterval(intervalId)