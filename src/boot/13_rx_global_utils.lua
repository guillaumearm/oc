local Rx = require('rx')

_G.Subscription = Rx.Subscription
_G.Observer = Rx.Observer
_G.Observable = Rx.Observable
_G.Subject = Rx.Subject
_G.BehaviorSubject = Rx.BehaviorSubject
_G.ReplaySubject = Rx.ReplaySubject

-------------------------------------------------------------------------------
---- Observable utilities
-------------------------------------------------------------------------------

_G.EMPTY = Rx.Observable.empty()
_G.NEVER = Rx.Observable.never()
_G.of = Rx.Observable.of
_G.throw = Rx.Observable.throw

_G.isObservable = function(obs)
  obs = obs or {}
  return isFunction(obs.subscribe)
end

_G.ensureObservable = function(x)
  if isObservable(x) then return x end
  return Rx.Observable.of(x)
end

_G.fromEvent = function(eventName)
  local event = require('event')
  return Rx.Observable.create(function(observer)
    local eventId = event.listen(eventName, function(...)
      observer:onNext(...)
    end)

    return Rx.Subscription.create(function()
      event.cancel(eventId)
      observer:onCompleted();
    end)
  end)
end

_G.interval = function(ms)
  return Rx.Observable.create(function(observer)
    local counter = 0

    local intervalId = setInterval(function()
      observer:onNext(counter)
      counter = counter + 1
    end, ms)

    return Rx.Subscription.create(function()
      clearInterval(intervalId)
      observer:onCompleted();
    end)
  end)
end

-------------------------------------------------------------------------------
---- Subjects utilities
-------------------------------------------------------------------------------
_G.isSubject = function(s)
  s = s or {}
  return isObservable(s) and isFunction(s.onNext) and isFunction(s.onError) and isFunction(s.onCompleted)
end

-------------------------------------------------------------------------------
---- Subscription utilities
-------------------------------------------------------------------------------

_G.isSubscription = function(sub)
  sub = sub or {}
  return isFunction(sub.unsubscribe)
end

_G.combineSubscriptions = function(...)
  local subscriptions = flatten(pack(...))

  return Rx.Subscription.create(function()
    forEach(function(s)
      s:unsubscribe()
    end, subscriptions)
  end)
end

function Observable:test()
  print('=> test ok !')
end
