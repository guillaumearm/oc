local uuid = require('uuid');
local os = require('os');
local event = require('event');
local component = require('component');
local computer = require('computer');
local dns = require('dns');
local fs = require('filesystem');
local fse = require('fs-extra');

-- in ms
local TIMEOUT = 2 * 1000

local FTP_PORT = 21;
local BUF_SIZE = 4096;

-- utils
local function cut_string(str, n)
  n = n or 0
  return string.sub(str, 1, n), string.sub(str, n + 1)
end

local function isFile(path)
  return fs.exists(path) and not fs.isDirectory(path);
end

local function getFullLocalPath(path)
  if first(path) == '/' then
    return path;
  end

  local cwd = os.getenv('PWD');
  return fs.canonical(fs.concat(cwd, path))
end

local function getFullTargetPath(localPath, targetPath)
  local fileName = fs.name(localPath);

  if isEmpty(targetPath) then
    targetPath = '';
  end

  if (first(targetPath) ~= '/') then
    targetPath = '/' .. targetPath;
  end

  if last(targetPath) == '/' then
    return targetPath .. fileName;
  end

  return fs.canonical(targetPath);
end

-----------------------------------------------------------
-- FTP LIB
-----------------------------------------------------------

---------------

local function initTransaction(ftpCmd, remoteAddr, targetPath, fileSize, txid)
  -- wait for response 'tx_accepted' | 'tx_refused'
  local eventId = event.listen('modem_message', function(_, _, targetAddr, port, _, message_type, txid_response, err)
    if port ~= FTP_PORT or targetAddr ~= remoteAddr or txid ~= txid_response then return; end

    if message_type == 'tx_accepted' then
      computer.pushSignal('tx_done', txid, message_type, err);
    elseif message_type == 'tx_refused' then
      computer.pushSignal('tx_done', txid, message_type, err);
    end
  end)

  local disposeTimeout = setTimeout(function()
    computer.pushSignal('tx_done', txid, 'tx_timeout', 'TIMEOUT!')
  end, TIMEOUT);

  -- send the transaction
  component.modem.send(remoteAddr, FTP_PORT, ftpCmd, txid, targetPath, fileSize);

  -- wait for response
  local _, _, message_type, errTx = event.pull('tx_done', txid);

  -- cleanup
  event.cancel(eventId);
  disposeTimeout();

  if message_type == 'tx_timeout' then
    return false, 'Error: unable to join remote host (TIMEOUT)'
  elseif message_type == 'tx_refused' then
    return false, 'Error: transaction refused: ' .. errTx;
  end

  return true;
end

---------------

local function sendPackets(remoteAddr, fileContent, txid)
  local allSent = false;

  local found_failure;
  local tx_success_received = false;
  local eventId;
  -- check for responses: tx_failure and tx_success
  eventId = event.listen('modem_message', function(_, _, targetAddr, port, _, msg_type, txid_response, err)
    if port ~= FTP_PORT or targetAddr ~= remoteAddr and txid_response ~= txid then return; end

    if allSent and msg_type == 'tx_success' then
      computer.pushSignal('endtx', txid, msg_type);
    elseif allSent and msg_type == 'tx_failure' then
      computer.pushSignal('endtx', txid, msg_type, err);
    elseif not allSent and msg_type == 'tx_success' then
      tx_success_received = true;
    elseif not allSent and msg_type == 'tx_failure' and isNotEmpty(err) then
      found_failure = err;
      event.cancel(eventId);
    end
  end);

  -- send packets
  local toSend = fileContent;
  repeat
    if found_failure then
      break
      ; end

    local buf, rest = cut_string(toSend, BUF_SIZE);
    toSend = rest;

    if #buf > 0 then
      local ok, err = component.modem.send(remoteAddr, FTP_PORT, 'put_transfer', txid, buf);
      if not ok then
        return false, '> modem.send error: ' .. tostring(err);
      end
      os.sleep(0.05);
    end
  until (#toSend == 0)
  allSent = true;

  if found_failure then
    event.cancel(eventId);
    return false, 'Error: transaction failure: ' .. tostring(found_failure);
  end

  if tx_success_received then
    event.cancel(eventId);
    return true;
  end

  local disposeTimeout = setTimeout(function()
    computer.pushSignal('endtx', txid, 'tx_failure', 'no tx_success received (TIMEOUT)');
  end, TIMEOUT);

  local _, _, msg_type, err = event.pull('endtx', txid);

  -- 5. cleanup
  event.cancel(eventId);
  disposeTimeout();

  if msg_type == 'tx_success' then
    return true;
  end

  return false, 'Error: transaction failure: ' .. tostring(err);
end

---------------

local function ftp_put(hostname, localPath, targetPath, force)
  localPath = getFullLocalPath(localPath);

  if not isFile(localPath) then
    return false, 'Error: "' .. localPath .. '" is not a valid file.'
  end


  local remoteAddr = dns.resolve(hostname);

  if not remoteAddr then
    return false, 'Error: unable to resolve "' .. hostname .. '" hostname';
  end

  -- read the file
  local fileContent, readErr = fse.readFile(localPath);

  if not fileContent or readErr then
    return false, tostring(readErr);
  end

  -- init transaction

  local cmd = ternary(force, 'putforce', 'put');
  targetPath = getFullTargetPath(localPath, targetPath);
  local fileSize = #fileContent;

  component.modem.open(FTP_PORT);

  local txid = uuid.next();
  local txOk, txErr = initTransaction(cmd, remoteAddr, targetPath, fileSize, txid);

  if txErr or not txOk then
    component.modem.close(FTP_PORT);
    return false, tostring(txErr);
  end

  -- transfer packets
  local ok, err = sendPackets(remoteAddr, fileContent, txid);

  component.modem.close(FTP_PORT);

  if err or not ok then
    return false, tostring(err);
  end

  return true;
end

-----------------------------------------------------------

local function main()
  local hostname = 'client2';
  local localPath = './file';
  local targetPath = getFullTargetPath(localPath, '/file');
  local putforce = true;

  print('> transfering "' .. localPath .. '" file to remote "' .. targetPath .. '"...');

  local ok, err = ftp_put(hostname, localPath, targetPath, putforce);

  if ok then
    print('> done.')
  else
    printError(err);
  end
end

main();
