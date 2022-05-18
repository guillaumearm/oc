local component = require('component');
local event = require('event');
local fs = require('filesystem');
local fse = require('fs-extra');

local logger = require('log')('ftpd');

local FTP_PORT = 21;
local FTP_ROOT = '/var/ftp/';
local TMP_DIR = '/var/tmp_ftp/';

-- in ms
local TIMEOUT = 3 * 1000;

local txs = {};

started = false

local function getModem()
  local modem = component.modem;

  if not modem then
    error('> modem not found!');
  end

  return modem;
end

local function getTmpPath(txid)
  return fs.concat(TMP_DIR, txid);
end

-- remove temp transaction file if exists
local function removeTmpFile(txid)
  local tmpPath = getTmpPath(txid);

  if fs.exists(tmpPath) then
    fs.remove(tmpPath);
    return true;
  end

  return false;
end

-- remove transaction + associated temp file
local function cleanTransaction(txid)
  local tx = txs[txid];

  if tx then
    txs[txid] = nil;
    removeTmpFile(txid);
    return true;
  end

  return false;
end

local function moveTempFile(tx)
  local tmpPath = getTmpPath(tx.id);
  local fullPath = tx.fullpath;
  local fullPathExist = fs.exists(fullPath);

  if not tx.force and fullPathExist then
    return false, 'Error: cannot overwrite an existing file at "' .. fullPath .. '"';
  end

  if fs.exists(tmpPath) then
    -- create the directory if doesn't exist
    fs.makeDirectory(fs.path(fullPath));

    if tx.force and fullPathExist then
      local rmOk, rmErr = fs.remove(fullPath);

      if not rmOk then
        return false, ternary(rmErr, rmErr, 'Error: cannot remove "' .. fullPath .. '" file!');
      end
    end

    -- move the file
    local ok, err = fs.rename(tmpPath, fullPath);

    if not ok then
      return false, ternary(err, err, 'Error: cannot move tmp file!');
    end

    return true;
  end

  return false, 'Error: tmp file does not found!';
end

local function cmd_put(timeoutFn, remoteAddr, port, txid, filepath, size, force)
  local modem = getModem();
  local tx = txs[txid];

  if tx then
    modem.send(remoteAddr, port, 'tx_refused', txid, 'transaction id already exists!')
    return;
  end

  local fullpath = fs.concat(FTP_ROOT, fs.canonical(filepath));

  if not force and fs.exists(fullpath) then
    modem.send(remoteAddr, port, 'tx_refused', txid, 'file "' .. filepath .. '" already exists!');
    return;
  end

  removeTmpFile(txid);

  txs[txid] = {
    force = force, -- put/putforce
    id = txid,
    fullpath = fullpath,
    filepath = filepath,
    remaining_size = size,
    disposeTimeout = setTimeout(timeoutFn, TIMEOUT)
  };

  modem.send(remoteAddr, port, 'tx_accepted', txid);
  logger.write('> transaction "' .. txid .. '" created!');
end

local function cmd_put_transfer(timeoutFn, remoteAddr, port, txid, data)
  local modem = getModem();
  local tx = txs[txid]

  if not tx then
    logger.write('put_transfer error: no transaction found!');
    modem.send(remoteAddr, port, 'tx_failure', txid, 'no transaction found!');
    return;
  end

  tx.disposeTimeout();

  local tmpPath = getTmpPath(txid);
  local ok, err = fse.appendFile(tmpPath, data);

  if not ok or err then
    local errMsg = 'appendFile error "' .. tostring(err) .. '"';
    logger.write('put_transfer error: ' .. errMsg);
    modem.send(remoteAddr, port, 'tx_failure', txid, errMsg);
    cleanTransaction(txid);
    return;
  end

  tx.remaining_size = tx.remaining_size - #data;

  if tx.remaining_size < 0 then
    logger.write('put_transfer error: bad buffer size!');
    modem.send(remoteAddr, port, 'tx_failure', txid, 'bad buffer size!');
    cleanTransaction(txid);
  elseif tx.remaining_size == 0 then
    local moveOk, moveTempFileErr = moveTempFile(tx);

    if moveOk and not moveTempFileErr then
      logger.write('> file "' .. tx.filepath .. '" transfered!');
      modem.send(remoteAddr, port, 'tx_success', txid);
    else
      logger.write(tostring(moveTempFileErr));
      modem.send(remoteAddr, port, 'tx_failure', txid, moveTempFileErr);
    end

    cleanTransaction(txid);
  else
    tx.disposeTimeout = setTimeout(timeoutFn, TIMEOUT);
  end
end

local handleModemMessages = logger.wrap(function(_, _, remoteAddr, port, _, message_type, txid, ...)
  if (port ~= FTP_PORT or isEmpty(txid)) then return; end

  local timeoutFn = function()
    logger.write('put error: transaction TIMEOUT!')
    cleanTransaction(txid);
  end

  if message_type == 'put' then
    local filepath, size = ...;
    cmd_put(timeoutFn, remoteAddr, port, txid, filepath, size, false);
  elseif message_type == 'putforce' then
    local filepath, size = ...;
    cmd_put(timeoutFn, remoteAddr, port, txid, filepath, size, true);
  elseif message_type == 'put_transfer' then
    local data = ...;
    cmd_put_transfer(timeoutFn, remoteAddr, port, txid, data);
  end
end)


function start()
  if started then return; end

  local modem = getModem();

  modem.open(FTP_PORT);

  logger.clean()
  event.listen('modem_message', handleModemMessages)

  started = true;
  print('> started ftpd');
end

function stop()
  if not started then return; end

  local modem = getModem();

  modem.close(FTP_PORT);
  event.ignore('modem_message', handleModemMessages)

  -- cleanup txs
  forEach(function(tx, txid)
    tx.disposeTimeout();
    removeTmpFile(txid);
  end, txs);
  txs = {};

  started = false;
  print('> stopped ftpd');
end

function restart()
  stop();
  start();
end

function status()
  if started then
    print('> ftpd: ON');
  else
    print('> ftpd: OFF');
  end
end
