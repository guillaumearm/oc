local dns = require('dns');
local fse = require('fs-extra');

local function printUsage()
  print('Usage:')
  print('\t\t dns help - print this message')
  print('\t\t dns register [name] - try to register with the current hostname if name arg is not provided')
  print('\t\t dns unregister - try to unregister')
  print('')
  print('type `man dns` for more details')
end

local function getHostname()
  local hostname, err = fse.readFile('/etc/hostname');

  if err or isEmpty(hostname) then
    return nil;
  end
  return hostname;
end

local function register(name)
  if isEmpty(name) then
    name = getHostname();
  end

  if isEmpty(name) then
    error('> no hostname found!');
  end

  local ok, err = dns.register(name);
  if ok then
    print(name .. ' registered!')
  else
    error('> ' .. err);
  end
end

local function unregister()
  local ok, err = dns.unregister();
  if ok then
    print('unregistered!')
  else
    error('> ' .. err);
  end
end

-- Program start here

local cmd, arg = ...;
if cmd == 'register' then
  register(arg);
elseif cmd == 'unregister' then
  unregister()
else
  printUsage();
end
