local component = require('component')
local runCycle = require('cycle')

local mainCycle = function()
  local initialComponents = component.list() or {}
  local initialSelectedAddr = firstKey(initialComponents) or nil

  local componentAdded_ = fromEvent('component_added')
  local componentRemoved_ = fromEvent('component_removed')

  local components_ = merge(componentAdded_, componentRemoved_)
    :scanActions({
      ['component_added']=function(addr, type)
        return setProp(addr, type)
      end,
      ['component_removed']=function(addr)
        return removeProp(addr)
      end
    }, initialComponents)
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

  local selectedComponentProxy_ = combineLatest(of(initialSelectedAddr):concat(onClickComponent_), components_)
    :map(function(addr, components)
      if not addr or not components[addr] then
        return nil
      end
      return component.proxy(addr)
    end)

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