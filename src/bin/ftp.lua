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

----------------------------------------------------------------
-- utils
----------------------------------------------------------------
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
  local fileName = fs.name(localPath) or '';

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

----------------------------------------------------------------

----------------------------------------------------------------
-- initTransaction
--
-- filesInfo is a number when ftpCmd == 'put' or ftp == 'putforce' (not recusrive)
----------------------------------------------------------------
local function initTransaction(ftpCmd, remoteAddr, targetPath, filesInfo, txid)
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
  component.modem.send(remoteAddr, FTP_PORT, ftpCmd, txid, targetPath, filesInfo);

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

----------------------------------------------------------------

----------------------------------------------------------------
-- transferPackets
----------------------------------------------------------------
local function transferPackets(fileContent, remoteAddr, targetPath, txid, ftpCmd, shouldBreak)
  repeat
    if shouldBreak() then
      break
      ; end

    local buf, rest = cut_string(fileContent, BUF_SIZE);
    fileContent = rest;

    if #buf > 0 then
      local ok, err;
      if ftpCmd == 'put_transfer' then
        ok, err = component.modem.send(remoteAddr, FTP_PORT, ftpCmd, txid, buf);
      else -- otherwise it's a 'putrec_transfer' command
        ok, err = component.modem.send(remoteAddr, FTP_PORT, ftpCmd, txid, targetPath, buf);
      end
      if not ok then
        return false, '> modem.send error: ' .. tostring(err);
      end
      os.sleep(0.05);
    end
  until (#fileContent == 0)

  return true;
end

----------------------------------------------------------------

----------------------------------------------------------------
-- sendPackets (usable by put only)
--
-- targetPath is not used when ftpCmd == 'put_transfer'
----------------------------------------------------------------
local function sendPackets(remoteAddr, targetPath, fileContent, txid, ftpCmd)
  local allSent = false;

  local found_failure;
  local getFoundFailure = function() return found_failure; end
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

  -- transfer packets
  local okTransfer, errTransfer = transferPackets(fileContent, remoteAddr, targetPath, txid, ftpCmd, getFoundFailure);

  if not okTransfer then
    event.cancel(eventId);
    return false, tostring(errTransfer);
  end

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

----------------------------------------------------------------

----------------------------------------------------------------
-- ftp_put
----------------------------------------------------------------
local function ftp_put(hostname, localPath, targetPath, force)
  localPath = getFullLocalPath(localPath);

  if not isFile(localPath) then
    return false, 'Error: "' .. localPath .. '" is not a valid file!'
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
  local ok, err = sendPackets(remoteAddr, targetPath, fileContent, txid, 'put_transfer');

  component.modem.close(FTP_PORT);

  if err or not ok then
    return false, tostring(err);
  end

  return true;
end

----------------------------------------------------------------
-- ftp_putrec
----------------------------------------------------------------
local function ftp_putrec(hostname, localPath, targetPath, force)
  localPath = getFullLocalPath(localPath);

  if not fs.isDirectory(localPath) then
    return false, 'Error: "' .. localPath .. '" is not a valid directory!'
  end


  local remoteAddr = dns.resolve(hostname);

  if not remoteAddr then
    return false, 'Error: unable to resolve "' .. hostname .. '" hostname';
  end

  -- 1. getFilesInfo
  local filesInfo, errInfo = fse.getFilesInfo(localPath);

  if not filesInfo or errInfo then
    return false, 'Error: ' .. tostring(errInfo);
  end

  -- 2. init transaction
  local cmd = ternary(force, 'putrecforce', 'putrec');
  targetPath = getFullTargetPath(localPath, targetPath);

  component.modem.open(FTP_PORT);

  local txid = uuid.next();
  local txOk, txErr = initTransaction(cmd, remoteAddr, targetPath, stringify(filesInfo), txid);

  if txErr or not txOk then
    component.modem.close(FTP_PORT);
    return false, tostring(txErr);
  end

  -- listen for server response
  local allSent = false;

  local found_failure;
  local getFoundFailure = function() return found_failure; end
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

  -- 3. for each file to send: readFile then transferPackets
  for filePath in pairs(filesInfo) do
    local fullLocalPath = fs.concat(localPath, filePath);

    local fileContent, readErr = fse.readFile(fullLocalPath);

    if not fileContent or readErr then
      event.cancel(eventId);
      component.modem.close(FTP_PORT);
      return false, tostring(readErr);
    end

    -- transfer packets
    local _cmd = 'putrec_transfer'
    local okTransfer, errTransfer = transferPackets(fileContent, remoteAddr, filePath, txid, _cmd, getFoundFailure);

    if not okTransfer then
      event.cancel(eventId);
      component.modem.close(FTP_PORT);
      return false, tostring(errTransfer);
    end


    if found_failure then
      event.cancel(eventId);
      component.modem.close(FTP_PORT);
      return false, 'Error: transaction failure: ' .. tostring(found_failure);
    end

    if tx_success_received then
      event.cancel(eventId);
      component.modem.close(FTP_PORT);
      return true;
    end

  end
  allSent = true;

  -- TODO: cleanup + wait for endtx + check errors

  local disposeTimeout = setTimeout(function()
    computer.pushSignal('endtx', txid, 'tx_failure', 'no tx_success received (TIMEOUT)');
  end, TIMEOUT);

  local _, _, msg_type, err = event.pull('endtx', txid);


  -- 5. cleanup
  event.cancel(eventId);
  component.modem.close(FTP_PORT);
  disposeTimeout();

  if msg_type == 'tx_success' then
    return true;
  end

  return false, 'Error: transaction failure: ' .. tostring(err);
end

----------------------------------------------------------------

local function main()
  local hostname = 'client2';
  local localPath = '/home';
  local targetPath = getFullTargetPath(localPath, '/');
  local putforce = false;

  print('> transfering "' .. localPath .. '" file to remote "' .. targetPath .. '"...');

  -- local ok, err = ftp_put(hostname, localPath, targetPath, putforce);
  -- TODO: remove this
  noop(ftp_put);

  local ok, err = ftp_putrec(hostname, localPath, targetPath, putforce);

  if ok then
    print('> done.')
  else
    printError(err);
  end
end

main();
