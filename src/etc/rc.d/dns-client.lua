local component = require('component');
local event = require('event');
local rc = require('rc');
local shell = require('shell');

local logger = require('log')('dns-client');
local db = require('persistable')('hostnames', {});

started = false

local function getModem()
  local modem = component.modem;

  if not modem then
    error('> modem not found!');
  end

  if countItems(component.list('modem')) > 1 then
    error('> too much modems!');
  end

  return modem;
end

api = {
  register = function(name)

    if type(name) ~= 'string' or name == '' then
      return false, 'invalid first parameter name'
    end

    local modem = getModem()

    shell.execute('hostname ' .. name);
    modem.broadcast(1, 'register', name);

    while (true) do
      local _, _, _, port, _, result, err = event.pull(3, 'modem_message');

      if port == nil then
        return false, 'TIMEOUT'
      end

      if result == 'register_ok' then
        return true;
      elseif result == 'register_ko' then
        return false, err;
      end
    end
  end,
  unregister = function()
    local modem = getModem()
    modem.broadcast(1, 'unregister');

    while (true) do
      local _, _, _, port, _, result, err = event.pull(3, 'modem_message');

      if port == nil then
        return false, 'TIMEOUT'
      end

      if result == 'unregister_ok' then
        return true;
      elseif result == 'unregister_ko' then
        return false, err;
      end
    end
  end,
  resolve = function(name)
    return findKey(function(v) return v == name end)(db.get())
  end,
  lookup = function(addr)
    return db.get()[addr]
  end
}

local handleModemMessages = logger.wrap(function(_, _, _, port, _, ...)
  if (port ~= 1) then return; end

  local message_type, data = ...

  if message_type == 'sync' then
    db.write(parse(data));
  end
end)

local function isDnsServerStarted()
  local server = rc.loaded['dns-server']

  if server and server.started == true then
    return true;
  end

  return false;
end

function start()
  if started then return; end

  if isDnsServerStarted() then
    rc.loaded['dns-server'].stop();
  end

  local modem = getModem();

  modem.open(1);
  modem.broadcast(1, 'request');

  logger.clean()
  event.listen('modem_message', handleModemMessages)

  started = true;
  print('> started dns-client');
end


function stop()
  if not started then return; end

  local modem = getModem();

  modem.close(1);
  event.ignore('modem_message', handleModemMessages)

  started = false;
  print('> stopped dns-client');
end

function restart()
  stop();
  start();
end

function status()
  if started then
    print('> dns-client: ON');
  else
    print('> dns-client: OFF');
  end
end
