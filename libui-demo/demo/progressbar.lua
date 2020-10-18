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
    local completed = math.ceil(width * ratio)
    local rest = width - completed
    return {
      content={
        {GreenBar(completed), RedBar(rest)}
      }
    }
  end)
)

local ReactorApp = ui(function(n)
  return {
    content={
      {Gauge(20, n)}
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

local rootView = ReactorApp
local rootReducer = toReducer(counterUpdater)
local routHandler = nil

local intervalId = setInterval(function()
  dispatch('tick')
end, 1000)

local ok, err = pcall(runUI, rootView, rootReducer, rootHandler)
if not ok then printErr(err) end

clearInterval(intervalId)