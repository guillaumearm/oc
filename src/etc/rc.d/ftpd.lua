local component = require('component');
local event = require('event');
local fs = require('filesystem');
local fse = require('fs-extra');

local logger = require('log')('ftpd');

local FTP_PORT = 21;
local FTP_ROOT = '/var/ftp/';
local TMP_DIR = '/tmp/';

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

-- remove temp transaction file if exists
local function removeTmpFile(txid)
  local tmpPath = TMP_DIR .. txid;

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
  local tmpPath = TMP_DIR .. tx.id;
  local fullPath = tx.fullpath;

  if fs.exists(tmpPath) then
    return fs.rename(tmpPath, fullPath);
  end

  return false, 'Error: tmp file does not found!';
end

local function cmd_put(timeoutFn, remoteAddr, port, txid, filepath, size)
  local modem = getModem();
  local tx = txs[txid];

  if tx then
    modem.send(remoteAddr, port, 'tx_refused', txid, 'transaction id already exists!')
    return;
  end

  -- TODO: path resolve ?
  local fullpath = FTP_ROOT .. filepath;

  -- TODO: check if the fullpath contains the FTP_ROOT

  if fs.exists(fullpath) then
    modem.send(remoteAddr, port, 'tx_refused', txid, 'file "' .. filepath .. '" already exists!');
    return;
  end

  removeTmpFile(txid);

  txs[txid] = {
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

  local tmpPath = TMP_DIR .. txid;
  fse.appendFile(tmpPath, data);
  tx.remaining_size = tx.remaining_size - #data;

  if tx.remaining_size < 0 then
    logger.write('put_transfer error: bad buffer size!');
    modem.send(remoteAddr, port, 'tx_failure', txid, 'bad buffer size!');
    cleanTransaction(txid);
  elseif tx.remaining_size == 0 then
    local ok, moveTempFileErr = moveTempFile(tx);

    if ok then
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
    cmd_put(timeoutFn, remoteAddr, port, txid, filepath, size);
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
