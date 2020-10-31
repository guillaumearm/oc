local io = require('io')
local fs = require('filesystem')

local fse = {}

fse.readFile = function(path)
  local file, error = io.open(path, 'r')
  if error or not file then
    return nil, error
  end

  local data, readErr = file:read('*a')
  if readErr or not data then
    return nil, readErr
  end

  file:close()
  return data
end

fse.writeFile = function(path, data, mode)
  mode = mode or 'w'
  fs.makeDirectory(fs.path(path))

  local file, error = io.open(path, mode)
  if error or not file then
    return false, error
  end

  local ok, writeErr = file:write(data)
  if writeErr or not ok then
    return false, writeErr
  end

  file:close()
  return true
end

fse.appendFile = function(path, data)
  return fse.writeFile(path, data, 'a')
end

fse.readTable = function(path)
  local data, error = fse.readFile(path)

  if not data then return data, error end
  return parse(data), error
end

fse.writeTable = function(path, t, pretty)
  return fse.writeFile(path, serialize(t, pretty))
end

return fse