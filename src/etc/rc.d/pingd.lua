local component = require('component');
local event = require('event');
local logger = require('log')('pingd');

local PING_PORT = 2;

started = false

local function getModem()
  local modem = component.modem;

  if not modem then
    error('> modem not found!');
  end

  return modem;
end

local handleModemMessages = logger.wrap(function(_, _, remoteAddr, port, _, ...)
  if (port ~= PING_PORT) then return; end

  local message_type, ping_uuid = ...

  if message_type == 'ping' then
    getModem().send(remoteAddr, port, 'pong', ping_uuid)
  end
end)


function start()
  if started then return; end

  local modem = getModem();

  modem.open(PING_PORT);
  modem.broadcast(1, 'request');

  logger.clean()
  event.listen('modem_message', handleModemMessages)

  started = true;
  print('> started pingd');
end


function stop()
  if not started then return; end

  local modem = getModem();

  modem.close(PING_PORT);
  event.ignore('modem_message', handleModemMessages)

  started = false;
  print('> stopped pingd');
end

function restart()
  stop();
  start();
end

function status()
  if started then
    print('> pingd: ON');
  else
    print('> pingd: OFF');
  end
end
