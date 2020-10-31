local filesystem = require('filesystem')
local fse = require('fs-extra')

local LOG_DIRECTORY = '/var/log/'
local LOG_EXTENSION = 'log'

local createLogger = function(loggerName, withStackTrace)
  if isNotString(loggerName) or isEmpty(loggerName) then error('invalid loggerName') end

  if withStackTrace == nil then
    withStackTrace = true
  end

  local log = {}

  log.path = filesystem.concat(LOG_DIRECTORY, loggerName) .. '.' .. LOG_EXTENSION

  log.write = function(line)
    return fse.appendFile(log.path, line .. '\n')
  end

  log.clean = function()
    return fse.writeFile(log.path, '')
  end

  log.wrap = function(fn)
    return function(...)
      local resultArgs
      if withStackTrace then
        resultArgs = pack(xpcall(fn, debug.traceback, ...))
      else
        resultArgs = pack(pcall(fn, ...))
      end
      local ok = first(resultArgs)
      local restArgs = drop(1, resultArgs)

      if not ok then
        local err = first(restArgs)
        log.write(err)
        error(err)
      end

      return unpack(restArgs)
    end
  end

  return log
end

return createLogger