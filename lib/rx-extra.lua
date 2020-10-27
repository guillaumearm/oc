local event = require('event')
local c = require('component')
local Rx = require('rx')

local api = {}

-- DEPRECATED!
-------------------------------------------------------------------------------
---- run an observable as a program using an observer
-------------------------------------------------------------------------------
api.run = function(observable, observer)
  if not observable or isNotFunction(observable.subscribe) then
    return false, '[rx-extra] on `run` method - not a valid observable'
  end

  local function onNext(...)
    if observer then
      observer:onNext(...)
    end
  end

  local function onError(...)
    if observer then
      observer:onError(...)
    else
      printError(...)
    end
  end

  local function onCompleted()
    if observer then
      observer:onCompleted()
    end
    event.push('@rx/stop')
  end

  local sub = observable:subscribe(Rx.Observer.create(onNext, onError, onCompleted))

  event.pullMultiple('interrupted', '@rx/stop')
  sub:unsubscribe()

  return true
end

-------------------------------------------------------------------------------
---- Cycles drivers
-------------------------------------------------------------------------------
-- just used to consume streams
local noopDriver = function(sink) return sink:subscribe(noop) end

-- basic print driver for debug
local printDriver = function(sink) return sink:subscribe(print) end

-- in-memory state driver
local stateDriver = function(sink)
  local stateSubject = Rx.ReplaySubject.create(1)
  return sink.subscribe(stateSubject), stateSubject
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
    -- delay 20ms before unsubscribe
    return sink:delay(20):subscribe(function()
      getStopSubscription():unsubscribe()
      event.push('@cycle/stop')
    end), sink
  end, setStopSubscription
end

local createUiDrivers = function()
  local function isClicked(clickEvent)
    return function(h)
      return clickEvent.x >= h.x and clickEvent.x < h.x + h.width and clickEvent.y >= h.y and clickEvent.y < h.y + h.height
    end
  end

  local gpu = c.gpu

  local previousRenderedElement = nil
  local originalScreenWidth, originalScreenHeight = gpu.getResolution()

  local domNewHandlers = {}
  local domHandlers = {}

  local repaint = require('ui/render')(nil, nil, nil, nil, function(onClick, x, y, width, height)
    table.insert(domNewHandlers, { onClick=onClick, x=x, y=y, width=width, height=height })
  end)

  domHandlers = domNewHandlers
  domNewHandlers = {}

  local firstRender = true

  local render = function(element, ...)
    if element and firstRender then
      firstRender = false;
      gpu.setResolution(element.width, element.height)
    end

    repaint(element, ...)
    domHandlers = domNewHandlers
    domNewHandlers = {}
  end

  local resetScreen = function()
    render(nil)
    gpu.setResolution(originalScreenWidth, originalScreenHeight)
  end

  domHandlers = domNewHandlers
  domNewHandlers = {}

  local uiDriver = function(sink)
    local renderSub = sink:subscribe(function(element)
      if not (previousRenderedElement == element) then
        render(element)
        previousRenderedElement = element
      end
    end)

    local touchSub = fromEvent('touch'):subscribe(function(...)
      local eName, id, x, y, type, user = ...

      local clickEvent = { id=id, x=x, y=y, type=type, user=user }
      local h = find(isClicked(clickEvent), domHandlers)

      if h and isSubject(h.onClick) then
        h.onClick:onNext(clickEvent)
      elseif h and isFunction(h.onClick) then
        h.onClick(clickEvent)
      end
    end)

    return combineSubscriptions(renderSub, touchSub)
  end

  local uiClearDriver = function(sink)
    return sink:subscribe(function()
      resetScreen();
    end)
  end

  return uiDriver, uiClearDriver
end


-------------------------------------------------------------------------------
---- Cycles
-------------------------------------------------------------------------------

api.runCycle = function(cycle, drivers, shouldWaitForStop, shouldWaitForInterrupted)
  if shouldWaitForStop == nil then
    shouldWaitForStop = true
  end

  if shouldWaitForInterrupted == nil then
    shouldWaitForInterrupted = true
  end

  local stopDriver, setStopSubscription = createStopDriver()
  -- local uiDriver, uiCleanDriver = createUiDrivers()

  local getDefaultDrivers = withDefault({
    state=stateDriver,
    -- ui=uiDriver,
    -- uiClean=uiCleanDriver,
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

  local finalSub = combineSubscriptions(unpack(values(driverSubscriptions)), unpack(values(sinkSubscriptions)))

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

return api
