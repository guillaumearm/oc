local c = require('component')

------------------------------------------------------------------------------------------------

local beep = c.computer.beep

local beepbeep = function()
  beep()
  beep()
end

------------------------------------------------------------------------------------------------

local maxHeight = 20
local headerHeight = 1
local buttonScrollHeight = 1
local listHeight = maxHeight - (buttonScrollHeight * 2 + headerHeight)
local listWidth = 30

local maxWidth = listWidth * 2

------------------------------------------------------------------------------------------------

local createButtonComponent = function(name, text)
  name = name or 'button'
  text = text or 'BUTTON TEXT'

  local clickedAction = 'button-clicked/' .. name
  local releasedAction = 'button-released/' .. name

  local updater = withInitialState(false, handleActions({
    [clickedAction]=function() return always(true) end,
    [releasedAction]=function() return always(false) end
  }))

  local View = function(state)
    return applyTo(Raw(text))(pipe(
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

local buttonComponent = createButtonComponent('button-refresh', 'Refresh')

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
  local buttons = horizontal(ExitButton(), buttonComponent.View(refreshButtonState))
  return horizontal(buttons, HeaderBar({ title=headerTitle, buttonLength=buttons.width }));
end


------------------------------------------------------------------------------------------------

local App = ui(function(state)
  return {
    content={
      { Header(' Here is the Header title ', state.refreshButton) },
    }
  }
end)

------------------------------------------------------------------------------------------------


local rootUpdater = combineUpdaters({
  refreshButton=buttonComponent.updater,
  fxs=handleActions({
    ['@init']=justFx(cb(beep)),
    ['@stop']=justFx(cb(beepbeep)),
  }), -- is it working ?
})

-----------------------------------------------------

local component = {
  view=App,
  updater=rootUpdater
}

return component
