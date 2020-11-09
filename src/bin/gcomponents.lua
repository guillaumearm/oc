local component = require('component')
local runCycle = require('cycle')

local mainCycle = function()
  local componentAdded_ = fromEvent('component_added')
  local componentRemoved_ = fromEvent('component_removed')

  local components_ = merge(componentAdded_, componentRemoved_)
    :map(function() return component.list() end)
    :startWith(component.list())
    :map(mapIndexed(function(name, addr)
      local shortAddr = take(3, addr)
      return View(name .. '(' .. shortAddr .. ')' )
    end))
    :map(values)
    :unpack()
    :map(vertical)
    :shareReplay(1)

  return {
    ui=components_
  }
end

runCycle(mainCycle, {}, true, true):unsubscribe()
