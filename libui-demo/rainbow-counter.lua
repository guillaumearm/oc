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

local truc = button

local page = ui(function(n)
  return {
    content={
      {truc(n, 'magenta', cb(beep, 200)), truc(n, 'blue', cb(beep, 440)), truc(n, 'green', cb(beep, 880))},
      {truc('-', 'white', click('decrement')), truc(n, 'lightblue'), truc('+', 'orange', click('increment'))},
      {truc(n, 'yellow'), truc(n, 'lime'), truc(n, 'pink')},
      {truc(n, 'gray'), truc(n, 'silver'), truc(n, 'cyan')},
      {truc(n, 'purple'), truc(n, 'brown'), truc(n, 'red')},
      {truc(n, 'white', cb(beep, 880 * 2))}
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

local rootView = doublePage
local rootHandler = nil

local intervalId = setInterval(function()
  dispatch('tick')
end, 1000)

local ok, err = pcall(runUI, rootView, counterUpdater, rootHandler)
if not ok then printErr(err) end

clearInterval(intervalId)