
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

local ProgressBar = ui(function(n)
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


return function()
  local App = ProgressBar
  local mainUpdater = counterUpdater

  local intervalId = nil

  local initHandler = captureAction('@init', function()
    intervalId = setInterval(function()
      dispatch('tick')
    end, 1000)
  end)

  local stopHandler = captureAction('@stop', function()
    if intervalId ~= nil then
      clearInterval(intervalId)
    end
  end)

  local mainHandler = pipeHandlers(initHandler, stopHandler)

  return {
    view=App,
    updater=mainUpdater,
    handler=mainHandler
  }
end
