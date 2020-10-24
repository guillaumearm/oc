local runUI = import('ui/run')
local c = require('component')

------------------------------------------------------------------------------------------------

local beep = c.computer.beep

------------------------------------------------------------------------------------------------

local maxHeight = 20
local headerHeight = 1
local buttonScrollHeight = 1
local listHeight = maxHeight - (buttonScrollHeight * 2 + headerHeight)
local listWidth = 30

local maxWidth = listWidth * 2

------------------------------------------------------------------------------------------------

local RefreshButton = pipe(
  defaultTo('[ default button text ]'),
  Raw,
  withBackgroundColor('gray'),
  withClick('refresh')
)

local createButtonApi = function(name, text)
  name = name or 'button'
  text = text or 'BUTTON TEXT'

  local clickedAction = 'button-clicked/' .. name
  local releasedAction = 'button-released/' .. name

  local updater = withInitialState(false, handleActions({
    [clickedAction]=function() return always(true) end,
    [releasedAction]=function() return always(false) end
  }))

  local View = function(state)
    return applyTo(text)(pipe(
      Raw,
      ternary(state, withBackgroundColor('white'), identity),
      ternary(state, withColor('black'), identity),
      -- withBackgroundColor('red'),
      -- withColor('black'),
      withClick(ternary(state, noop, function()
        dispatch(clickedAction)
        setTimeout(function()
          dispatch(releasedAction)
        end, 100)
      end))
    ))
  end


  return {
    updater=updater,
    View=View,
    actions={
      clickedAction=clickedAction,
      releasedAction=releasedAction
    }
  }
end

local buttonApi = createButtonApi('button-refresh', 'Refresh')

local ExitButton = function(x)
  return pipe(
    defaultTo('X'),
    Raw,
    withBackgroundColor('red'),
    withColor('black'),
    withClick(stopUI)
  )(x)
end

local HeaderBar =  function(props)
  props = props or {}
  return pipe(
    defaultTo('  DEFAULT HEADER TITLE  '),
    centerStringWith('-', maxWidth - props.buttonLength),
    Raw
  )(props.title)
end

local Header = function(headerTitle, refreshButtonState)
  local buttons = horizontal(ExitButton(), buttonApi.View(refreshButtonState))
  return horizontal(buttons, HeaderBar({ title=headerTitle, buttonLength=buttons.width }));
end

local Button = ui(function(n, actionToDispatch)
  actionToDispatch = actionToDispatch or 'noop'
  local text = String(n)
  return {
    onClick=function(e)
      return actionToDispatch, e
    end,
    style={ color='silver' },
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
      { Header(' Here is the Header title ', state.refreshButton) },
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
  },
  refreshButton=buttonApi.updater
})

--------------------------------------------------------
local initHandler = captureAction('@init', function(prevState, state)
  beep()
end)

local incHandler = captureAction('increment', function() end)
local decHandler = captureAction('decrement', function() end)
local refreshHandler = captureAction('refresh', function() beep(); beep(); end)
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
  resetHandler,
  refreshHandler
)
--------------------------------------------------------

local rootView = App
local rootHandler = mainHandler

local intervalId = setInterval(function()
  dispatch('tick')
end, 5000)

local ok, err = pcall(runUI, rootView, rootUpdater, rootHandler)
if not ok then printErr(err) end

clearInterval(intervalId)