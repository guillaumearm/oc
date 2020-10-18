local computer = require('computer')
local c = require('component')
local event = require('event')
local filesystem = require('filesystem')
local log = require('log')('redstone-onoff')

started = false

local handleRedstoneChanged = log.wrap(function(type, addr, side, prevValue, nextValue)
  if prevValue == 0 and nextValue > 0 then
    computer.shutdown()
  end
end)

function start()
  if started then return; end
  log.clean()    

  event.listen('redstone_changed', handleRedstoneChanged)

  started = true
  print("> started redstone-onoff")
end

function stop()
  if not started then return; end 

  event.ignore('redstone_changed', handleRedstoneChanged)
  
  started = false
  print("> stopped redstone-onoff")
end

function restart()
  stop()
  start()
end

function status()
  if started
    then print("> redstone-onoff: ON")
    else print("> redstone-onoff: OFF")
  end
end