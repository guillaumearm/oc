local uuid = require('uuid');
local computer = require('computer');
local event = require('event');

local CLOSE_MSG = 'scheduler_close';

local function closeScheduler(schedulerId)
  return computer.pushSignal(CLOSE_MSG, schedulerId);
end

local function createScheduler()
  local id = uuid.next();
  local eventIds = {};

  --------------------------------------------------------------
  -- private utils
  --------------------------------------------------------------
  local checkSchedulerClosed = function()
    if isEmpty(eventIds) then
      closeScheduler(id);
    end
  end

  local createDispose = function(eId)
    return function()
      if not eventIds[eId] then
        return false;
      end

      event.cancel(eId);
      eventIds[eId] = nil;

      checkSchedulerClosed();

      return true;
    end
  end

  --------------------------------------------------------------
  -- scheduler.wait
  --------------------------------------------------------------
  local wait = function()
    if isEmpty(eventIds) then
      return false;
    end

    event.pull(CLOSE_MSG, id);
    return true;
  end

  --------------------------------------------------------------
  -- scheduler.close
  --------------------------------------------------------------
  local close = function()
    if isEmpty(eventIds) then
      return false;
    end

    for eId in pairs(eventIds) do
      event.cancel(eId);
    end
    eventIds = {};

    return closeScheduler(id);
  end

  --------------------------------------------------------------
  -- scheduler.listen
  --------------------------------------------------------------
  local listen = function(msg_type, cb)
    local eId = event.listen(msg_type, cb);

    eventIds[eId] = true;

    return createDispose(eId);
  end

  --------------------------------------------------------------
  -- scheduler.setTimeout
  --------------------------------------------------------------
  local setTimeout = function(cb, ms)
    local sec = (ms or 0) / 1000;

    local eId;
    eId = event.listen(sec, function(...)
      eventIds[eId] = nil;
      cb(...);
      checkSchedulerClosed();
    end, 1);
    eventIds[eId] = true;

    return createDispose(eId);
  end

  return {
    wait = wait,
    close = close,
    listen = listen,
    setTimeout = setTimeout
  }
end

return createScheduler;
