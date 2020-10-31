local computer = require('computer')
local c = require('component')
local event = require('event')
local log = require('log')('redstone-onoff')

_G.started = false

local setRedstoneThreshold = function()
  if c.isAvailable('redstone') and c.redstone.getWakeThreshold() <= 0 then
    c.redstone.setWakeThreshold(1);
  end
end

local handleRedstoneChanged = log.wrap(function(_, _, _, prevValue, nextValue)
  if prevValue == 0 and nextValue > 0 then
    computer.shutdown()
  end
end)

local handleComponentAvailable = log.wrap(function(_, componentType)
  if componentType == 'redstone' then
    setRedstoneThreshold();
  end
end)

_G.start = function()
  if started then return; end
  log.clean()

  setRedstoneThreshold();
  event.listen('redstone_changed', handleRedstoneChanged)
  event.listen('component_available', handleComponentAvailable)

  started = true
  print("> started redstone-onoff")
end

_G.stop = function()
  if not started then return; end

  event.ignore('redstone_changed', handleRedstoneChanged)
  event.remove('component_available', handleComponentAvailable)

  started = false
  print("> stopped redstone-onoff")
end

_G.restart = function()
  stop()
  start()
end

_G.status = function()
  if started
    then print("> redstone-onoff: ON")
    else print("> redstone-onoff: OFF")
  end
end