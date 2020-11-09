local component = require('component')
local runCycle = require('cycle')



local mainCycle = function()
  local initialComponents = component.list()
  local initialSelectedAddr = firstKey(initialComponents) or nil

  local componentAdded_ = fromEvent('component_added')
  local componentRemoved_ = fromEvent('component_removed')

  local components_ = merge(componentAdded_, componentRemoved_)
    :map(function() return component.list() end)
    :startWith(initialComponents)
    :shareReplay(1)

  local onClickComponent_ = Subject.create()

  local componentsView_ = components_
    :map(mapIndexed(function(name, addr)
      local shortAddr = take(3, addr)
      return applyTo(View(name .. ' (' .. shortAddr .. ')' ))(
        withClick(function() onClickComponent_(addr) end)
      )
    end))
    :map(values)
    :unpack()
    :map(vertical)
    :shareReplay(1)

  local selectedComponentProxy_ = of(initialSelectedAddr)
    :concat(onClickComponent_)
    :map(function(addr)
      if not addr then
        return nil
      end
      return component.proxy(addr)
    end)
    :shareReplay(1)

  local selectedComponent_ = selectedComponentProxy_
    :map(function(proxy)
      if not proxy then
        return View('[no selected component]')
      end
      return View(proxy.type)
    end)

  local ui = combineLatest(componentsView_, selectedComponent_):map(horizontal)

  return {
    ui=ui
  }
end

runCycle(mainCycle, {}, true, true):unsubscribe()
