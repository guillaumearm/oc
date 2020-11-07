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
_G.defer = Rx.Observable.defer

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

-- it works with observables and regular arrays (table with only numeric keys)
_G.mergeAll = function(firstArg, ...)
  if isObservable(firstArg) then
    return firstArg:merge(...)
  end

  if isTable(firstArg) then
    return assign(firstArg, ...)
  end

  return NEVER
end

_G.merge = mergeAll

-------------------------------------------------------------------------------
---- Observable and events
-------------------------------------------------------------------------------
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

local eventsKeyMap = {
  ["13,28"] = "enter",
  ["8,14"]  = "backspace",
  ["9,15"]  = "tab",
  ["0,200"] = "up",
  ["0,203"] = "left",
  ["0,205"] = "right",
  ["0,208"] = "down",
  ["0,42"]  = "shift", -- left shift only
  ["0,54"]  = "right-shift",
  ["0,29"]  = "ctrl", -- left ctrl only
  ["0,157"] = "right-ctrl",
  ["0,56"]  = "alt", -- left alt only
  ["0,184"] = "right-alt",
  ["0,201"] = "page-up",
  ["0,209"] = "page-down",
  ["0,210"] = "insert",
  ["0,211"] = "delete",
  ["0,199"] = "home",
  ["0,207"] = "end"
}

local getEventFromKeyMap = function(key, code)
  return eventsKeyMap[String(math.floor(key)) .. ',' .. String(math.floor(code))]
end

local fromKey = function(eventName)
  return function ()
    return fromEvent(eventName)
    :map(function(_, _, key, code)
      if (isPrintable(key)) then
        return 'key', char(key)
      end

      return getEventFromKeyMap(key, code)
    end)
    :reject(isNil)
  end
end

_G.fromKeyDown = fromKey('key_down')
_G.fromKeyUp = fromKey('key_up')

-------------------------------------------------------------------------------
---- Observable new methods
-------------------------------------------------------------------------------

-------------------------------------
---- Regular methods
-------------------------------------
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

function Observable:shift(n)
  return self:map(shift(n or 1))
end

function Observable:unshift(...)
  return self:map(unshift(...))
end

function Observable:when(o)
  return o:switchMap(function(enabled)
    if not enabled then
      return NEVER
    end

    return self
  end)
end

function Observable:activateWhen(o)
  return self:when(o)
end

function Observable:Then(o)
  o = o or NEVER

  return self:switchMap(function(value)
    if Boolean(value) then
      return o
    end

    return of(null)
  end)
end

function Observable:Else(o)
  o = o or NEVER

  return self:switchMap(function(value)
    if value == null then
      return o
    end

    return of(value)
  end)
end

function Observable:mapPayload(...)
  local callbacks = map(function(f)
    return function(firstArg, ...)
      return firstArg, f(...)
    end
  end, pack(...))

  return self:map(pack(callbacks))
end

-------------------------------------
---- Fx methods
-------------------------------------
function Observable:mapFx(...)
  return self:map(Fx(...))
end

-------------------------------------
---- action methods
-------------------------------------
function Observable:removeAction()
  return self:map(shift(1))
end

function Observable:action(actionType)
  return self:unshift(actionType)
end

function Observable:renameAction(actionType)
  return self:map(function(_, ...)
    return actionType, ...
  end)
end

function Observable:filterAction(...)
  return self:filter(oneOf(...))
end

function Observable:filterActions(...)
  return self:filter(oneOf(...))
end

-- private share function
local function shareWithSubject(this, subjectFactory)
  local refCount = 0
  local _subject = nil
  local sourceSub = Subscription.empty()

  local getSubject = function()
    if not _subject or _subject.stopped then
      _subject = subjectFactory()
    end

    return _subject
  end

  return Observable.create(function(observer)
    local subject = getSubject()

    local subjectSub = subject:subscribe(observer)

    local mainSub = Rx.Subscription.create(function()
      refCount = refCount - 1
      subjectSub:unsubscribe();

      -- setImmediate(function()
      if refCount == 0 then
        sourceSub:unsubscribe();
        sourceSub = Subscription.empty()
      end
      -- end)
    end)

    if refCount == 0 then
      sourceSub = this:subscribe(Observer.create(
        function(...)
          subject:onNext(...)
        end,
        function(...)
          subject:onError(...)
        end,
        function(_)
          subject:onCompleted()
          mainSub:unsubscribe()
        end)
      )
    end

    refCount = refCount + 1
    return mainSub
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

local function toReducer(updater)
  return function(state, ...)
    return updater(...)(state)
  end
end

local function handleActions(actionsMap)
  return function(action, ...)
    local payloadUpdater = prop(action, actionsMap) or always(identity)
    return payloadUpdater(...)
  end
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

_G.isCallable = function(x)
  return isFunction(x) or isSubject(x)
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
