local component = require('component');
local event = require('event');
local fse = require('fs-extra');
local rc = require('rc');

local logger = require('log')('dns-server');
local db = require('persistable')('hostnames', {});

local DNS_PORT = 1;

started = false;
local _hostname = nil;

api = {
  register = function()
    error('cannot register from a dns-server')
  end,
  unregister = function()
    error('cannot unregister from a dns-server')
  end,
  resolve = function(name)
    return findKey(function(v) return v == name end)(db.get())
  end,
  lookup = function(addr)
    return db.get()[addr]
  end
}

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

local function getHostname()
  if not isEmpty(_hostname) then
    return _hostname;
  end

  local err;
  _hostname, err = fse.readFile('/etc/hostname');

  if err or isEmpty(_hostname) then
    error('> please set a hostname for the server!');
  end

  return _hostname;
end

local function getHostnames(hostname, modemAddr)
  local hostnames = db.read();

  if hostnames[modemAddr] ~= hostname then
    hostnames[modemAddr] = hostname;
    db.write(hostnames);
  end

  return hostnames;
end

local handleModemMessages = logger.wrap(function(_, _, fromAddr, port, _, ...)
  if (port ~= DNS_PORT) then return; end

  local modem = component.modem;
  local message_type = ...

  if message_type == 'request' then
    modem.send(fromAddr, port, 'sync', stringify(db.get()))
  elseif message_type == 'register' then
    local _, name = ...
    local data = db.get();

    local isAlreadyRegistered = not not find(function(n, a) return a ~= fromAddr and n == name end)(data)
    if isAlreadyRegistered then
      modem.send(fromAddr, port, 'register_ko', 'name "'.. name .. '" is already registered')
      return;
    end

    data[fromAddr] = name;
    db.write(data);
    modem.send(fromAddr, port, 'register_ok');
    modem.broadcast(DNS_PORT, 'sync', stringify(data))

  elseif message_type == 'unregister' then
    local data = db.get();
    local name = data[fromAddr];

    if name then
      data[fromAddr] = nil;
      db.write(data);
      modem.send(fromAddr, port, 'unregister_ok', name)
      modem.broadcast(DNS_PORT, 'sync', stringify(data))
    else
      modem.send(fromAddr, port, 'unregister_ko', 'no name registered for this address')
    end
  end

end)

local function isDnsClientStarted()
  local client = rc.loaded['dns-client']

  if client and client.started == true then
    return true;
  end

  return false;
end

function start()
  if started then return; end

  if isDnsClientStarted() then
    rc.loaded['dns-client'].stop();
  end

  local modem = getModem();
  local hostname = getHostname();
  local hostnames = getHostnames(hostname, modem.address);

  modem.open(DNS_PORT);

  modem.broadcast(DNS_PORT, 'sync', stringify(hostnames))

  logger.clean()
  event.listen('modem_message', handleModemMessages)

  started = true;
  print('> started dns-server');
end

function stop()
  if not started then return; end

  local modem = getModem();

  modem.close(DNS_PORT);
  event.ignore('modem_message', handleModemMessages)

  started = false;
  print('> stopped dns-server');
end

function restart()
  stop();
  start();
end

function status()
  if started then
    print('> dns-server: ON');
  else
    print('> dns-server: OFF');
  end
end
