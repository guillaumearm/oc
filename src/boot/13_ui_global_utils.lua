---------------------------------------------------------------------------
------------  Name: ui-global-utils v0.10
------------  Description: Global UI utilities
------------  Author: Trapcodien
---------------------------------------------------------------------------
local uiApi = require('ui')

local getPredicate = function(x)
  return isFunction(x) and x or identical(x)
end

--------------------------------
--------- UI (views)
--------------------------------
_G.ui = uiApi.ui
_G.uiWrap = uiApi.createUI
_G.uiWrapContent = function(content)
  return uiWrap({ content=content })
end

_G.Raw = function(strOrElement)
  if isString(strOrElement) then
    return uiWrapContent({{ strOrElement }})
  end
  return strOrElement
end

_G.View = Raw

_G.EmptyView = View('')

_G.horizontal = function(...)
  local content = arrayOf(map(Raw, pack(...)))
  return uiWrapContent(content)
end

_G.vertical = function(...)
  return uiWrapContent(map(compose(arrayOf, Raw), pack(...)))
end

_G.withStyle = curryN(2, function(style, element)
  local initialStyle = element.style or {}
  local finalStyle = assign(initialStyle, style)
  return assign(element, { style=finalStyle })
end)

_G.withContent = curryN(2, function(txtOrElem, element)
  local newElemContent = isString(txtOrElem) and View(txtOrElem).content or element.content
  return assign(element, { content=newElemContent })
end)

_G.withColor = curryN(2, function(color, element)
  return withStyle({ color=color } , element)
end)

_G.withBgColor = curryN(2, function(bgColor, element)
  return withStyle({ backgroundColor=bgColor }, element)
end)

_G.withBackgroundColor = withBgColor

-- Detect if a value is a RX subject
local isNextable = function(x)
  return isTable(x) and isFunction(x.onNext)
end

local isCallable = function(x)
  return isFunction(x) or isNextable(x)
end

local liftElementClick = function(onClick, fn)
  return function(...)
    if isCallable(onClick) then
      onClick(...)
    end

    if isCallable(fn) then
      return fn(...)
    end

    return ...
  end
end

_G.withClick = curryN(2, function(fnOrSubject, element)
  local onClick = liftElementClick(element.onClick, fnOrSubject)
  return assign(element, { onClick=onClick })
end)

_G.withStopPropagation = function()
  return function(element)
    return withClick(function(e)
      e.stopPropagation()
    end, element)
  end
end

_G.withoutPropagation = withStopPropagation

_G.withOnClick = withClick

_G.withClickOutside = curryN(2, function(fnOrSubject, element)
  local onClickOutside = liftElementClick(element.onClickOutside, fnOrSubject)
  return assign(element, { onClickOutside=onClickOutside })
end)

_G.withOnClickOutside = withClickOutside

-- withClick + withStopPropagation
_G.withScopedClick = curryN(2, function(fnOrSubject, element)
  return applyTo(element)(
    withoutPropagation(),
    withClick(fnOrSubject)
  )
end)

_G.withScroll = curryN(2, function(fnOrSubject, element)
  local onScroll = liftElementClick(element.onScroll, fnOrSubject)
  return assign(element, { onScroll=onScroll })
end)

_G.withOnScroll = withScroll;

----- Margins

_G.withMarginLeft = curryN(2, function(n, element)
  return evolve({
    width=add(n),
    content=map(evolve({
      width=add(n),
      content={ [1]=prepend(string.rep(' ', n)) }
    }))
  })(element)
end)

----- TODO: minWidth/minHight

----- TODO: borders

--------------------------------
--------- EVENTS
--------------------------------

_G.dispatch = function(...)
  local event = require('event')
  event.push('ui', ...)
end

_G.stopUI = function()
  dispatch('@stop')
end

--------------------------------
--------- EFFECTS
--------------------------------

_G.pipeFx = function(...)
  local fxs = pack(...)
  local tappedFxs = map(tap, fxs)
  return pipe(unpack(tappedFxs))
end

--------------------------------
--------- UPDATERS
--------------------------------

_G.toReducer = function(updater)
  return function(state, ...)
    return updater(...)(state)
  end
end

_G.createAction = function(type)
  return function(...)
    return type, ...
  end
end

_G.handleActions = function(actionsMap)
  return function(action, ...)
    local payloadUpdater = prop(action, actionsMap) or always(identity)
    return payloadUpdater(...)
  end
end

_G.withInitialState = curryN(2, function(initialState, updater)
  return function(...)
    local updateFn = updater(...)
    return function(state)
      local nextState, fx = updateFn(state)
      return nextState or initialState, fx
    end
  end
end)

_G.combineUpdaters = function(updaters)
  return function(...)
    local finalFx = noop
    local actions = pack(...)

    local fns = deepMap(function(updater)
      local u = updater(unpack(actions))

      return function(state)
        local nextState, fx = u(state)

        local prevFinalFx = finalFx
        if fx then
          finalFx = function()
            prevFinalFx()
            fx(state, nextState, unpack(actions))
          end
        end
        return nextState
      end
    end, updaters)

    local updateFn = evolve(fns)

    return function(state)
      return updateFn(state), finalFx
    end
  end
end

_G.pipeUpdaters = function(...)
  local updaters = pack(...)
  return function(...)
    local finalFx = noop
    local actions = pack(...)

    local updateFns = map(function(updater)
      local u = updater(unpack(actions))

      return function(state)
        local nextState, fx = u(state)

        local prevFinalFx = finalFx
        if fx then
          finalFx = function()
            prevFinalFx()
            fx(state, nextState, unpack(actions))
          end
        end
        return nextState
      end
    end, updaters)

    local updateFn = pipe(unpack(updateFns))

    return function(state)
      return updateFn(state), finalFx
    end
  end
end

_G.filterAction = curryN(2, function(predicate, updater)
  return ifElse(getPredicate(predicate), updater, always(identity))
end)

_G.withFx = curryN(2, function(givenFx, updater)
  return function(...)
    local update = updater(...)

    return function(state)
      local nextState, fx = update(state)
      local finalFx = ternary(Boolean(fx), pipeFx(fx, givenFx), givenFx)

      return nextState, finalFx
    end
  end
end)

-- return an updater that does not update the state but apply the given fx
_G.justFx = function(fx)
  return function()
    return function(state)
      return state, fx
    end
  end
end

--------------------------------
--------- HANDLERS
--------------------------------

_G.pipeHandlers = function(...)
  local handlers = pack(...)
  return pipe(unpack(map(tap, handlers)))
end

_G.captureEvent = curryN(2, function(predicate, handler)
  predicate = getPredicate(predicate)

  return function(prevState, state, ...)
    if predicate(...) then return handler(prevState, state, ...) end
  end
end)

_G.captureAction = curryN(2, function(predicate, handler)
  predicate = getPredicate(predicate)

  return captureEvent(function(eventName, ...)
    return Boolean(eventName == 'ui' and predicate(...))
  end, handler)
end)

_G.captureOnStop = captureAction('@stop')
