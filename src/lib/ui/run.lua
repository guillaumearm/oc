local eventApi = require('event')
local runEvents = require('ui/events')
local c = require('component')

local gpu = c.gpu

function isClicked(clickEvent)
  return function(h)
    return clickEvent.x >= h.x and clickEvent.x < h.x + h.width and clickEvent.y >= h.y and clickEvent.y < h.y + h.height
  end
end

function isNotClicked(clickEvent)
  return complement(isClicked(clickEvent))
end

function runUI(view, updater, handler, ...)
  handler = handler or noop
  local events = concat({ 'touch', 'ui' }, pack(...))
  local previousRenderedElement = nil
  local originalScreenWidth, originalScreenHeight = gpu.getResolution()

  local newHandlers = {}
  local handlers = {}

  local repaint = require('ui/render')(nil, nil, nil, nil, function(elem, x, y, width, height)
    table.insert(newHandlers, { onClick=elem.onClick, onClickOutside=elem.onClickOutside, x=x, y=y, width=width, height=height })
  end)

  handlers = newHandlers
  newHandlers = {}
  local firstRender = false

  local render = function(element, ...)
    if element and not firstRender then
      firstRender = true;
      gpu.setResolution(element.width, element.height)
    end

    repaint(element, ...)
    handlers = newHandlers
    newHandlers = {}
  end

  local resetScreen = function()
    render(nil)
    gpu.setResolution(originalScreenWidth, originalScreenHeight)
  end

  handlers = newHandlers
  newHandlers = {}

  local eventUpdater = function(eName, ...)
    if (eName == 'ui') then
      return updater(...)
    else
      return identity
    end
  end

  return runEvents(events, eventUpdater, function(prevState, state, eName, ...)
    if not (prevState == state) then
      local element = view(state)
      if not (previousRenderedElement == element) then
        render(element)
        previousRenderedElement = element
      end
    end

    local secondArg = ...
    local shouldStop = eName == 'ui' and secondArg == '@stop'

    if eName == 'interrupted' then
      eventApi.push('ui', '@stop')
    end

    if eName == 'interrupted' or shouldStop then
      resetScreen()
    end

    if eName == 'touch' then
      local id, x, y, type, user = ...
      local clickEvent = { id=id, x=x, y=y, type=type, user=user }

      -- detech regular click
      local foundHandler = find(isClicked(clickEvent), handlers)
      if foundHandler then
        local clickResult = pack(foundHandler.onClick(clickEvent))

        if isNotEmpty(clickResult) then
          eventApi.push('ui', unpack(clickResult))
        end
      end

      -- detect click outside
      local filteredHandlers = filter(both(prop('onClickOutside'), isNotClicked(clickElement)), handlers)

      forEach(function(h)
        local clickOutsideResult = pack(h.onClickOutside(clickEvent))

        if isNotEmpty(clickOutsideResult) then
          eventApi.push('ui', unpack(clickOutsideResult))
        end
      end, filteredHandlers)
    else
      handler(prevState, state, eName, ...)
    end
  end)
end

return runUI