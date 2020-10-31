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

local mainUpdater = combineUpdaters({
  counter={
    value=counterUpdater
  }
})

--------------------------------------------------------
local initHandler = captureAction('@init', function(_, _)
  beep()
end)

local resetHandler = captureAction('reset', function() beep() end)
local terminatedHandler = captureAction('@stop', function() beep(); beep() end)


local mainHandler = pipeHandlers(
  initHandler,
  terminatedHandler,
  resetHandler
)
--------------------------------------------------------

return {
  view=App,
  updater=mainUpdater,
  hander=mainHandler
}