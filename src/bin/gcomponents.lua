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

  local selectedComponentProxy_ = combineLatest(
    of(initialSelectedAddr):concat(onClickComponent_),
    components_
  )
    :map(function(addr, components)
      if not addr or not components[addr] then
        return nil
      end
      return component.proxy(addr)
    end)
    :shareReplay(1)

  local selectedAddr_ = selectedComponentProxy_
    :map(function(p)
      if p then return p.address end
      return nil
    end)

  local componentsView_ = combineLatest(components_, selectedAddr_)
    :map(function(components, selectedAddr)
      return mapIndexed(function(name, addr)
        local shortAddr = take(3, addr)
        local styleEnhancer = selectedAddr == addr and withColor('yellow') or identity

        return applyTo(View(name .. ' (' .. shortAddr .. ')' ))(
          withClick(function() onClickComponent_(addr) end),
          styleEnhancer
        )
      end, components)
    end)
    :map(values)
    :unpack()
    :map(vertical)
    :shareReplay(1)


  local ui = combineLatest(componentsView_, selectedComponentProxy_)
    :map(function(view, proxy)
      local proxyView = proxy and View(proxy.type) or View('[no selected component]')
      return horizontal(view, proxyView)
    end)

  return {
    ui=ui
  }
end

runCycle(mainCycle, {}, true, true):unsubscribe()