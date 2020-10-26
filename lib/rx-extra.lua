local event = require('event')
local Rx = require('rx')

local api = {}

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

api.combineSubscriptions = function(...)
  local subscriptions = flatten(pack(...))

  return Rx.Subscription.create(function()
    forEach(callMethod('unsubscribe'), subscriptions)
  end)
end

return api
