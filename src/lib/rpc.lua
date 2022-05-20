local os = require('os');
local component = require('component');
local event = require('event');
local uuid = require('uuid');
local dns = require('dns');

local RPC_PORT = 3;
local DEFAULT_TIMEOUT = 3000;  -- in ms
local DEFAULT_BUFFER_SIZE = 4096;

----------------------------------------------------------------
-- utils
----------------------------------------------------------------
local function getTimeout(timeout)
  if timeout == false then
    return false;
  end

  return timeout or DEFAULT_TIMEOUT;
end

local function cut_string(str, n)
  n = n or 0
  return string.sub(str, 1, n), string.sub(str, n + 1)
end

----------------------------------------------------------------
-- sendPackets
----------------------------------------------------------------
local function sendPackets(remoteAddr, port, bufferSize, data, channel, requestId, mode)
  local okInit, errInit = component.modem.send(remoteAddr, port, 'RPC_INIT_' .. mode, channel, requestId, #data);
  if not okInit then
    return false, '> modem.send error: ' .. tostring(errInit);
  end

  repeat
    local buf, rest = cut_string(data, bufferSize);
    data = rest;

    if #buf > 0 then
      local ok, err = component.modem.send(remoteAddr, port, 'RPC_TRANSFER_' .. mode, channel, requestId, data);
      if not ok then
        return false, '> modem.send error: ' .. tostring(err);
      end
      os.sleep(0.05);
    end
  until (#data == 0)

  return true;
end

----------------------------------------------------------------
-- createRPC
----------------------------------------------------------------
local createRPC = function(timeoutMs)
  local api = {};  -- public api

  api.timeout = getTimeout(timeoutMs);
  api.port = RPC_PORT;
  api.buffer_size = DEFAULT_BUFFER_SIZE;

  ----------------------------------------------------------------
  -- rpc.listen
  ----------------------------------------------------------------
  api.listen = function(channel, callback, errCallback)
    local txs = {};
    errCallback = errCallback or identity;

    local function createTimeoutFn(requestId)
      return function()
        errCallback('RPC Timeout!');
        txs[requestId] = nil;
      end
    end

    local eventId;
    eventId = event.listen('modem_message', function(_, _, remoteAddr, port, _, msgType,
                                                     receivedChannel, requestId, ...)
      if port ~= api.port or receivedChannel ~= channel then return; end

      if msgType == 'RPC_INIT_REQUEST' then
        local size = ...;

        txs[requestId] = {
          remaining_size = size,
          data = '',
          disposeTimeout = setTimeout(createTimeoutFn(requestId), api.timeout);
        };
      elseif msgType == 'RPC_TRANSFER_REQUEST' then
        local dataChunk = ...;
        local tx = txs[requestId]

        if not tx then
          errCallback('RPC Error: transaction not found!');
          return;
        end

        tx.disposeTimeout();

        tx.data = tx.data .. dataChunk;
        tx.remaining_size = tx.remaining_size - #dataChunk;

        if tx.remaining_size < 0 then
          errCallback('RPC Error: bad buffer size!');
          txs[requestId] = nil;
        elseif tx.remaining_size == 0 then
          txs[requestId] = nil;

          local responseData = stringify(callback(parse(tx.data)));
          local ok, err = sendPackets(remoteAddr, api.port, api.buffer_size,
            responseData, channel, requestId, 'RESPONSE');

          if not ok then
            errCallback('RPC Error: ' .. err);
          end
        else
          tx.disposeTimeout = setTimeout(createTimeoutFn(requestId), api.timeout)
        end
      end
    end)

    -- dispose function
    return function()
      if eventId ~= nil then
        event.cancel(eventId);
        eventId = nil;
        txs = {};
      end
    end
  end

  ----------------------------------------------------------------
  -- rpc.call
  ----------------------------------------------------------------
  api.call = function(hostname, channel, initialData, callback, errCallback)
    errCallback = errCallback or identity;
    initialData = stringify(initialData);

    local targetAddr = dns.resolve(hostname);
    local requestId = uuid.next();

    local disposeTimeout = noop;
    local tx = nil;  -- or { remaining_size = number, data = '' }
    local eventId = nil;

    local function cleanEvents()
      disposeTimeout();
      tx = nil;
      if eventId ~= nil then
        event.cancel(eventId)
        eventId = nil;
      end
    end

    local function timeoutFn()
      cleanEvents();
      errCallback('RPC call error: TIMEOUT !');
    end

    local function resetTimeout()
      disposeTimeout();
      disposeTimeout = setTimeout(timeoutFn, api.timeout);
    end

    eventId = event.listen('modem_message', function(_, _, remoteAddr, port, _, msgType,
                                                     receivedChannel, receivedRequestId, ...)
      if port ~= api.port
          or remoteAddr ~= targetAddr
          or receivedRequestId ~= requestId
          or receivedChannel ~= channel then
        return;
      end

      if msgType == 'RPC_INIT_RESPONSE' then
        local size = ...;

        resetTimeout();

        tx = {
          remaining_size = size,
          data = ''
        }
      elseif msgType == 'RPC_TRANSFER_RESPONSE' then
        local data = ...;

        if tx then
          tx.remaining_size = tx.remaining_size - #data;
          tx.data = tx.data .. data;

          if tx.remaining_size > 0 then
            resetTimeout();
          elseif tx.remaining_size == 0 then
            callback(parse(data));
            cleanEvents();
          else
            errCallback('RPC_TRANSFER_RESPONSE error: bad buffer size!')
            cleanEvents();
          end
        else
          errCallback('RPC_TRANSFER_RESPONSE error: no transaction found!')
          cleanEvents();
          return;
        end
      end
    end)

    -- send packets
    local reqOk, reqErr = sendPackets(targetAddr, api.port, api.buffer_size,
      initialData, channel, requestId, 'REQUEST');

    if not reqOk then
      errCallback(reqErr);
      cleanEvents()
      return;
    end

    disposeTimeout();
    disposeTimeout = setTimeout(timeoutFn, api.timeout);

    -- dispose function
    return function()
      cleanEvents();
    end
  end
  return api;
end


----------------------------------------------------------------
-- exposed lib
----------------------------------------------------------------
local defaultRPC = createRPC();
defaultRPC.createRPC = createRPC;

return defaultRPC;
