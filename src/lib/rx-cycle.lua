local c = require('component')
local event = require('event')
local shell = require('shell')

local Rx = require('rx')

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
    return sink:subscribe(function()
      getStopSubscription():unsubscribe()
      event.push('@cycle/stop')
    end), sink
  end, getStopSubscription, setStopSubscription
end

local createUiDrivers = function(getStopSubscription)
  local function isClicked(clickEvent)
    return function(h)
      return clickEvent.x >= h.x and clickEvent.x < h.x + h.width and clickEvent.y >= h.y and clickEvent.y < h.y + h.height
    end
  end

  local gpu = c.gpu

  local previousRenderedElement = nil
  local originalScreenWidth, originalScreenHeight = gpu.getResolution()

  local domNewHandlers = {}

  local paint = require('ui/render')(nil, nil, nil, nil, function(onClick, x, y, width, height)
    table.insert(domNewHandlers, { onClick=onClick, x=x, y=y, width=width, height=height })
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


  local uiDriver = function(sink)
    local renderSub = sink:subscribe(
      function(element) -- onNext
        if not (previousRenderedElement == element) then
          render(element)
          previousRenderedElement = element
        end
      end,
      function(err) -- onError
        getStopSubscription():unsubscribe();
        -- resetScreen(); -- not needed because the stop subscription will already call `resetScreen` function
        printErr(err)
      end
    )

    local touchSub = fromEvent('touch'):subscribe(function(...)
      local _, id, x, y, type, user = ...

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
    state=stateDriver,
    ui=uiDriver,
    print=printDriver,
    stop=stopDriver,
    noop=noopDriver
  })

  drivers = getDefaultDrivers(drivers or {})

  local sinksSubjects = map(function() return Rx.Subject.create() end, drivers)

  local allDriverResults = mapIndexed(function(s, k)
    -- TODO: check errors when exec the driver
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

  -- TODO: check errors when exec the driver
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

  local finalSub = combineSubscriptions(values(driverSubscriptions), values(sinkSubscriptions), resetScreenSub)

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
