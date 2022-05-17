local rc = require("rc")

local isStartedServer = path("loaded", "dns-server", "started")
local isStartedClient = path("loaded", "dns-client", "started")

local execMethod = function(methodName, ...)
	if isStartedServer(rc) then
		return rc.loaded["dns-server"].api[methodName](...)
	elseif isStartedClient(rc) then
		return rc.loaded["dns-client"].api[methodName](...)
	end

	error("dns-server or dns-client should be started!")
end

local api = {
	register = function(name)
		return execMethod("register", name)
	end,
	unregister = function()
		return execMethod("unregister")
	end,
	resolve = function(name)
		return execMethod("resolve", name)
	end,
	lookup = function(addr)
		return execMethod("lookup", addr)
	end,
}

if isStartedServer(rc) and isStartedClient(rc) then
	print("dns lib fatal error: dns-client and dns-server cannot run together!")
end

return api
