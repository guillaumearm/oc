local dns = require('dns');
local uuid = require('uuid');
local component = require('component');
local event = require('event');

local PING_PORT = 2;

local function printUsage()
  print('Usage:')
  print('\t\t ping <hostname> - try to ping a specific hostname on the network')
end

local function getModem()
  local modem = component.modem;

  if not modem then
    error('> ping: modem not found!');
  end

  return modem;
end

local function pingAddr(addr)
  local modem = getModem();

  print('> ping: sending ping request to "' .. addr .. '"')

  if modem.addr == addr then
    print('> ping: pong received locally.')
    return true;
  end


  local request_id = uuid.next();

  modem.broadcast(PING_PORT, 'ping', request_id);

  while (true) do
    local _, _, remoteAddr, port, _, result, request_id_response = event.pull(3, 'modem_message');

    if port == nil then
      error('no response from the remote host (TIMEOUT)')
    end

    if port == PING_PORT and result == 'pong' and remoteAddr == addr and request_id_response == request_id  then
      print('> ping: pong successfully received')
      return true;
    end
  end
end

local function pingHost(hostname)
  local addr = dns.resolve(hostname);

  if not addr then
    error('> ping: unable to resolve "' .. hostname .. '" address!' );
  end

  return pingAddr(addr);
end

-- Program start here
local arg = ...;

-- usage
if not arg or arg == '-h' or arg == '--help' or arg == '?' or arg == '-?' then
  printUsage();
  return;
end

-- execution
pingHost(arg)
