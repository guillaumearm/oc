local c = require('component')
local event = require('event')
local filesystem = require('filesystem')
local log = require('log')('media')

local MEDIA_FOLDER = '/media/'

started = false

local getAllFsAddr = function() return c.list('filesystem') end
local getFsProxy = function(addr) return c.proxy(addr) end
local getAllFs = pipe(getAllFsAddr, keys, map(getFsProxy))

local isFsAccepted = function(fs)
  local label = fs.getLabel()
  if label == 'tmpfs' then return false end

  if fs.address == filesystem.get('/').address then
    return false
  end

  return Boolean(label)
end

local handleFsAdded = log.wrap(function(_, addr, componentType)
  if componentType == 'filesystem' then
    local fs = c.proxy(addr)
    if isFsAccepted(fs) then
      local mediaPath = filesystem.concat(MEDIA_FOLDER, fs.getLabel())
      filesystem.mount(addr, mediaPath)
    end
  end
end)

local handleFsRemoved = log.wrap(function(_, addr, componentType)
  if componentType == 'filesystem' then
    filesystem.umount(addr)
  end
end)

_G.reload = function()
  forEach(function(fs)
    if isFsAccepted(fs) then
      local mediaPath = filesystem.concat(MEDIA_FOLDER, fs.getLabel())
      if not filesystem.exists(mediaPath) then
        filesystem.mount(fs.address, mediaPath)
      end
    end
  end, getAllFs())

  print('> filesystem /media/ mounting points reloaded')
end

_G.start = function()
  if started then return; end
  log.clean()

  event.listen('component_added', handleFsAdded)
  event.listen('component_removed', handleFsRemoved)
  reload()

  started = true
  print("> started media")
end

function stop()
  if not started then return; end

  event.ignore('component_added', handleFsAdded)
  event.ignore('component_removed', handleFsRemoved)

  started = false
  print("> stopped media")
end

_G.restart = function()
  stop()
  start()
end

_G.status = function()
  if started
    then print("> media: ON")
    else print("> media: OFF")
  end
end