local component = require('component');
local event = require('event');
local rc = require('rc');
local shell = require('shell');

local logger = require('log')('dns-client');
local db = require('persistable')('hostnames', {});

local DNS_PORT = 1;
local TIMEOUT = 2;

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

    local modem = getModem();

    modem.broadcast(DNS_PORT, 'register', name);
    while (true) do
      local _, _, _, port, _, result, err = event.pull(TIMEOUT, 'modem_message');

      if port == nil then
        return false, 'TIMEOUT'
      end

      if port == DNS_PORT and result == 'register_ok' then
        shell.execute('hostname ' .. name);
        os.setenv('HOSTNAME', name);
        return true;
      elseif port == DNS_PORT and result == 'register_ko' then
        return false, err;
      end
    end
  end,
  unregister = function()
    local modem = getModem();

    modem.broadcast(DNS_PORT, 'unregister');
    while (true) do
      local _, _, _, port, _, result, err = event.pull(TIMEOUT, 'modem_message');

      if port == nil then
        return false, 'TIMEOUT'
      end

      if port == DNS_PORT and result == 'unregister_ok' then
        return true;
      elseif port == DNS_PORT and result == 'unregister_ko' then
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
  if (port ~= DNS_PORT) then return; end

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

  modem.open(DNS_PORT);
  modem.broadcast(DNS_PORT, 'request');

  logger.clean()
  event.listen('modem_message', handleModemMessages)

  started = true;
  print('> started dns-client');
end


function stop()
  if not started then return; end

  local modem = getModem();

  modem.close(DNS_PORT);
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
