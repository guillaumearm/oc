local c = require('component')
local event = require('event')
local shell = require('shell')
local logger = require('log')('lib/cycle')

local Rx = require('rx')

-------------------------------------------------------------------------------
---- Cycles drivers
-------------------------------------------------------------------------------
-- just used to consume streams
local noopDriver = function(sink) return sink:subscribe(noop) end

-- basic print driver for debug
-- TODO store printed values if ui is rendered
local printDriver = function(sink) return sink:subscribe(print) end

-- in-memory state driver
local stateDriver = function(sink)
  return sink:shareReplay(1)
end

local actionDriver = function(sink)
  return sink:share()
end

local fxDriver = function(sink)
  return sink:subscribe(callFx)
end

-- used to give the ability to a cycle to close itself
local createStopDriver = function()
  local storedStopSubscription = Rx.Subscription.create(noop)

  local setStopSubscription = function(sub)
    storedStopSubscription = sub
  end

  local getStopSubscription = function()
    return storedStopSubscription
  end

  return function(sink)
    return sink:subscribe(function()
      getStopSubscription():unsubscribe()
    end), sink
  end, getStopSubscription, setStopSubscription
end

local createUiDrivers = function(getStopSubscription)
  local function isInteracted(e, handleName)
    return function(h)
      return Boolean(h[handleName]) and e.x >= h.x
        and e.x < h.x + h.width
        and e.y >= h.y
        and e.y < h.y + h.height
    end
  end

  local function isNotInteracted(e, handleName)
    return complement(isInteracted(e, handleName))
  end

  local gpu = c.gpu

  local previousRenderedElement = nil
  local originalScreenWidth, originalScreenHeight = gpu.getResolution()

  local domNewHandlers = {}

  local paint = require('ui/render')(nil, nil, nil, nil, function(elem, x, y, width, height)
    table.insert(domNewHandlers, {
      onClick=elem.onClick,
      onClickOutside=elem.onClickOutside,
      onScroll=elem.onScroll,
      x=x,
      y=y,
      width=width,
      height=height
    })
  end)

  local domHandlers = domNewHandlers
  domNewHandlers = {}

  local render = function(element, ...)
    local prev = previousRenderedElement
    if not prev or prev.width ~= element.width or prev.height ~= element.height then
      gpu.setResolution(element.width, element.height)
    end

    paint(element, ...)

    domHandlers = domNewHandlers
    domNewHandlers = {}
  end

  local resetScreen = function()
    if previousRenderedElement then
      gpu.setResolution(originalScreenWidth, originalScreenHeight)
      paint(nil)
      shell.execute('clear')
    end
  end

  local renderObserver = Rx.Observer.create(
    logger.wrap(function(element) -- onNext
      if previousRenderedElement ~= element then
        render(element)
        previousRenderedElement = element
      end
    end),
    function(err) -- onError
      getStopSubscription():unsubscribe();
      printErr(err)
    end
  )

  local uiDriver = function(sink)
    local renderSub = sink:subscribe(renderObserver)

    local touchSub = fromEvent('touch'):subscribe(function(...)
      local _, id, x, y, type, user = ...

      local clickEvent = { id=id, x=x, y=y, type=type, user=user }

      -- detect regular clicks
      local foundClicks = reverse(filter(isInteracted(clickEvent, 'onClick'), domHandlers))

      local propagationStopped = false
      local function stopPropagation()
        propagationStopped = true
      end

      forEach(function(foundClick)
        if propagationStopped then
          return false
        end

        if isCallable(foundClick.onClick) then
          local relativeClickPosition = {
            x=clickEvent.x - foundClick.x + 1,
            y=clickEvent.y - foundClick.y + 1
          }
          foundClick.onClick(assign(clickEvent, relativeClickPosition, { stopPropagation=stopPropagation }))
        end
      end, foundClicks)

      -- detect outside clicks
      local filteredHandlers = filter(isNotInteracted(clickEvent, 'onClickOutside'), domHandlers)

      forEach(function(h)
        if isCallable(h.onClickOutside) then
          h.onClickOutside(clickEvent)
        end
      end, filteredHandlers)
    end)

    local scrollSub = fromEvent('scroll'):subscribe(function(...)
      local _, id, x, y, type, user = ...

      local scrollEvent = { id=id, x=x, y=y, type=type, user=user }

       -- detect scroll events
       local foundScrolls = reverse(filter(isInteracted(scrollEvent, 'onScroll'), domHandlers))

       local propagationStopped = false
       local function stopPropagation()
         propagationStopped = true
       end

       forEach(function(foundScroll)
         if propagationStopped then
           return false
         end

         if isCallable(foundScroll.onScroll) then
           local relativeScrollPosition = {
             x=scrollEvent.x - foundScroll.x + 1,
             y=scrollEvent.y - foundScroll.y + 1
           }
           foundScroll.onScroll(assign(scrollEvent, relativeScrollPosition, { stopPropagation=stopPropagation }))
         end
       end, foundScrolls)
    end)

    return combineSubscriptions(renderSub, touchSub, scrollSub)
  end

  return uiDriver, resetScreen
end


-------------------------------------------------------------------------------
---- Cycles
-------------------------------------------------------------------------------

local runCycle = function(cycle, drivers, shouldWaitForStop, shouldWaitForInterrupted)
  if shouldWaitForStop == nil then
    shouldWaitForStop = true
  end

  if shouldWaitForInterrupted == nil then
    shouldWaitForInterrupted = true
  end

  local stopDriver, getStopSubscription, setStopSubscription = createStopDriver()
  local uiDriver, resetScreen = createUiDrivers(getStopSubscription)

  local getDefaultDrivers = withDefault({
    fx=fxDriver,
    state=stateDriver,
    action=actionDriver,
    ui=uiDriver,
    print=printDriver,
    stop=stopDriver,
    noop=noopDriver
  })

  drivers = getDefaultDrivers(drivers or {})

  local sinksSubjects = map(function() return Rx.Subject.create() end, drivers)

  local allDriverResults = mapIndexed(function(s, k)
    local subOrSources, driverSources = drivers[k](s)
    if isSubscription(subOrSources) then
      return { subscription=subOrSources, sources=driverSources }
    end
    return { sources=subOrSources }
  end, sinksSubjects)

  local sources = applyTo(allDriverResults)(
    pluck('sources'),
    reject(isNil)
  )

  local sinks = cycle(sources) or {}

  local driverSubscriptions = applyTo(allDriverResults)(
    pluck('subscription'),
    reject(isNil)
  )

  local sinkSubscriptions = applyTo(sinksSubjects)(
    mapIndexed(function(s, k)
      local sink = sinks[k]
      if sink then return sink:subscribe(s) end
    end),
    reject(isNil)
  )

  local resetScreenSub = Rx.Subscription.create(function()
    resetScreen()
  end);

  local ensureStopSub = Rx.Subscription.create(function()
    event.push('@cycle/stop')
  end);

  local finalSub = combineSubscriptions(
    values(driverSubscriptions),
    values(sinkSubscriptions),
    resetScreenSub,
    ensureStopSub
  )

  setStopSubscription(finalSub)

  if shouldWaitForStop and shouldWaitForInterrupted then
    event.pullMultiple('@cycle/stop', 'interrupted');
  elseif shouldWaitForStop and not shouldWaitForInterrupted then
    event.pull('@cycle/stop');
  elseif not shouldWaitForStop and shouldWaitForInterrupted then
    event.pull('interrupted');
  end

  return finalSub
end

return runCycle
