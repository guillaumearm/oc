local runUI = require('ui/run')

local function ensureContainerFactory(containerOrFactory)
  return ternary(isFunction(containerOrFactory), containerOrFactory, always(containerOrFactory))
end


local function isValidContainer(container)
  if not container then
    return false, 'UI Error: no container found'
  end

  if not container.view then
    return false, 'UI ERROR: no view provided in the container'
  end

  if isNotFunction(container.view) then
    return false, 'UI ERROR: invalid view inside the container (should be a function)'
  end

  if container.updater and isNotFunction(container.updater) then
    return false, 'UI ERROR: invalid updater inside the container (should be a function)'
  end

  if container.handler and isNotFunction(container.handler) then
    return false, 'UI ERROR: invalid handler inside the container (should be a function)'
  end

  if container.capture and isNotTable(container.capture) then
    return false, 'UI ERROR: invalid capture events inside the container (should be a table)'
  end

  if container.capture then
    local captureErr = nil

    forEach(function(e)
      if isNotString(e) then
        captureErr = 'UI ERROR: invalid capture events (not a string)'
        return stop
      end
    end, container.capture)

    if captureErr then return false, captureErr end
  end

  return true
end

local function execUI(containerOrFactory, ...)
  local containerFactory = ensureContainerFactory(containerOrFactory)
  local container = containerFactory(...)

  local containerOk, reason = isValidContainer(container)
  if not containerOk then
    return false, reason
  end

  local view, updater, handler = container.view, container.updater, container.handler
  local events = container.capture or {}

  local ok, err = pcall(runUI, view, updater, handler, unpack(events))
  return ok, err
end

return execUI

