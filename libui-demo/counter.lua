local runUI = import('ui/run')
local c = require('component')

------------------------------------------------------------------------------------------------

local beep = c.computer.beep

------------------------------------------------------------------------------------------------

local Button = ui(function(n, actionToDispatch)
  actionToDispatch = actionToDispatch or 'noop'
  local text = String(n)
  return {
    onClick=function(e)
      dispatch(actionToDispatch, e)
    end,
    style={ color=0x00BE00 },
    content={
      {string.rep('-', length(text) + 8)},
      {'--- ', text, ' ---'},
      {string.rep('-', length(text) + 8)}
    }
  }
end);

------------------------------------------------------------------------------------------------

local CounterApp = ui(function(state)
  return {
    content={
      {Button('+', 'increment'), Button(state), Button('-', 'decrement')},
      {Button('reset', 'reset')}
    }
  }
end)

local App = ui(function(state)
  return {
    content={
      { CounterApp(state.counter.value) }
    }
  }
end)

------------------------------------------------------------------------------------------------

local counterUpdater = withInitialState(0,
  handleActions({
    reset=always(always(0)),
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

local rootUpdater = combineUpdaters({
  counter={
    value=counterUpdater
  }
})

--------------------------------------------------------
local initHandler = captureAction('@init', function(prevState, state)
  beep()
end)

local incHandler = captureAction('increment', function() beep() end)
local decHandler = captureAction('decrement', function() beep() end)
local resetHandler = captureAction('reset', function() beep() end)
local terminatedHandler = captureEvent('interrupted', function() beep() end)

local tickHandler = captureAction('tick', function(prevState, state)
 -- do something here
end)


local mainHandler = pipeHandlers(
  initHandler,
  terminatedHandler,
  tickHandler,
  incHandler,
  decHandler,
  resetHandler
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