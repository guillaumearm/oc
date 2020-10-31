local Rx = require('rx')

_G.Rx = Rx

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
  if isNotTable(obs) then
    return false
  end

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

_G.combineLatest = function(o, ...)
  return o:combineLatest(...)
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
---- Observable new methods
-------------------------------------------------------------------------------
function Observable:switchMap(callback)
  return self:map(callback):switch()
end

function Observable:switchMapTo(o)
  return self:map(always(o)):switch()
end

function Observable:mapTo(...)
  return self:map(always(...))
end

function Observable:mergeMap(callback)
  return self:flatMap(callback)
end

function Observable:tap(callback)
  return self:map(tap(callback))
end

function Observable:withLatestFrom(...)
  return self:with(...)
end

-- private share function
local function shareWithSubject(this, subjectFactory)
  local refCount = 0
  local _subject = nil
  local thisSub = nil

  local getSubject = function()
    if not _subject or _subject.stopped then
      _subject = subjectFactory()
    end

    return _subject
  end

  return Observable.create(function(observer)
    local subject = getSubject()

    if not thisSub then
      thisSub = this:subscribe(subject)
    end

    refCount = refCount + 1

    local subjectSub = _subject:subscribe(observer)

    return Rx.Subscription.create(function()
      refCount = refCount - 1
      subjectSub:unsubscribe();

      setImmediate(function()
        if thisSub and refCount == 0 then
          thisSub:unsubscribe();
          thisSub = nil
        end
      end)
    end)
  end)
end

function Observable:shareReplay(bufferSize)
  bufferSize = bufferSize or 1

  return shareWithSubject(self, function()
    return Rx.ReplaySubject.create(bufferSize)
  end)
end

function Observable:share()
  return shareWithSubject(self, function()
    return Rx.Subject.create()
  end)
end

function Observable:scanActions(actionsMap, initialState)
  return self:scan(toReducer(handleActions(actionsMap)), initialState)
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

function Subscription:add(...)
  return combineSubscriptions(self, ...)
end
