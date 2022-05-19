local io = require('io')
local fs = require('filesystem')

local fse = {}

---------------------------------------------------------------
-- getFilesInfo implementation
---------------------------------------------------------------

local function _getFilesInfo(rootPath, currentDir, filesInfo, blacklistedMountedPaths)
  local dirPath = fs.concat(rootPath, currentDir);

  for fileName in fs.list(dirPath) do
    local fullPath = fs.concat(dirPath, fileName);
    local relativeFilePath = fs.concat(currentDir, fileName);

    if fs.isDirectory(fullPath) and not blacklistedMountedPaths[fullPath] then
      filesInfo = _getFilesInfo(rootPath, relativeFilePath, filesInfo, blacklistedMountedPaths);
    else
      filesInfo[relativeFilePath] = fs.size(fullPath);
    end
  end

  return filesInfo;
end

local function getBlacklistedMountedPaths()
  local paths = {};
  local rootProxy;

  for proxy, path in fs.mounts() do
    if path == '/' then
      rootProxy = proxy;
    else
      paths[path] = proxy;
    end
  end

  forEach(function(proxy, p)
    if proxy ~= rootProxy and p ~= '/dev' and not startsWith('/media', p) then
      paths[p] = nil;
    end
  end, paths);

  return map(always(true))(paths);
end

---------------------------------------------------------------
-- getFilesInfo
---------------------------------------------------------------

fse.getFilesInfo = function(rootPath)
  if not fs.isDirectory(rootPath) then
    return nil, 'getFilesInfo error: not a directory';
  end

  local mountedPaths = getBlacklistedMountedPaths();
  return _getFilesInfo(rootPath, '', {}, mountedPaths);
end

---------------------------------------------------------------
-- readFile
---------------------------------------------------------------
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

---------------------------------------------------------------
-- writeFile
---------------------------------------------------------------
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

---------------------------------------------------------------
-- appendFile
---------------------------------------------------------------
fse.appendFile = function(path, data)
  return fse.writeFile(path, data, 'a')
end

---------------------------------------------------------------
-- readTable
---------------------------------------------------------------
fse.readTable = function(path)
  local data, error = fse.readFile(path)

  if not data then return data, error end
  return parse(data), error
end

---------------------------------------------------------------
-- writeTable
---------------------------------------------------------------
fse.writeTable = function(path, t, pretty)
  return fse.writeFile(path, serialize(t, pretty))
end

return fse
