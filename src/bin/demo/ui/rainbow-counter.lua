local c = require('component')

local beep = c.computer.beep

------------------------------------------------------------------------------------------------

local button = ui(function(n, color, onClick)
  local text = String(n)
  return {
    onClick=onClick,
    style={ color=color or 0x00BE00 },
    content={
      {string.rep('-', length(text) + 8)},
      {'--- ', text, ' ---'},
      {string.rep('-', length(text) + 8)}
    }
  }
end);

local page = ui(function(n)
  return {
    content={
      {button(n, 'magenta', cb(beep, 200)), button(n, 'blue', cb(beep, 440)), button(n, 'green', cb(beep, 880))},
      {button('-', 'white', always('decrement')), button(n, 'lightblue'), button('+', 'orange', always('increment'))},
      {button(n, 'yellow'), button(n, 'lime'), button(n, 'pink')},
      {button(n, 'gray'), button(n, 'silver'), button(n, 'cyan')},
      {button(n, 'purple'), button(n, 'brown'), button(n, 'red')},
      {button(n, 'white', cb(beep, 880 * 2))}
    }
  }
end)

local doublePage = ui(function(n)
  return {
    content={
      {page(n)},
      {page(n)}
    }
  }
end)

------------------------------------------------------------------------------------------------

local initialState = 0

local counterUpdater = withInitialState(initialState,
  handleActions({
    tick=always(inc),
    increment=function(_)
      return add(1)
    end,
    decrement=function(_)
      return add(-1)
    end
  })
)

local App = doublePage
local mainUpdater = counterUpdater
local mainHandler = nil

return {
  view=App,
  updater=mainUpdater,
  handler=mainHandler
}