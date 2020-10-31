local fs = require('filesystem')
local fse = require('fs-extra')

local PERSISTABLE_FOLDER = '/var/persistable/'

local persistable = function(dbName, defaultTable)
  local dbPath = fs.concat(PERSISTABLE_FOLDER, dbName)

  local cacheReaded = false
  local dbReaded = false
  local cache = nil
  local db = {}

  db.read = function()
    cache = fse.readTable(dbPath)

    if not cache and defaultTable and not dbReaded then
      cache = defaultTable
      cacheReaded = true
      fse.writeTable(dbPath, cache, math.huge)
    end

    return cache
  end

  db.reload = db.read

  db.get = function()
    if not cacheReaded then
      return db.read()
    end
    return cache
  end

  db.write = function(t)
    cache = t
    return fse.writeTable(dbPath, cache, math.huge)
  end

  db.clean = function()
    db.write(defaultTable)
  end

  return db
end

return persistable