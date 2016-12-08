--[[
http.lua

Asynchronous HTTP tsched extension (mostly copied from ssl.https)
]]

local ltn12 = require("ltn12")
local socket = require("socket")
local urllib = require("socket.url")
local http = require("socket.http")
local async = require("tsched.socket")
local ssl_available, ssl = pcall(require, "ssl")

local _M = {}

--[[
-- luasec-0.6
local ssl_default_params = {
	protocol	= "any";
  	options 	= {"all", "no_sslv2", "no_sslv3"};
  	verify		= "none";
  	mode		= "client";
}]]

-- luasec-0.4
local ssl_default_params = {
	protocol 	= "tlsv1";
  	options  	= "all";
  	verify   	= "none";
  	mode 		= "client";
}

local http_trequest

-- turns an url and a body into a generic request (from socket.http)
local function url_to_table(u, b)
    local t = {}
    local reqt = {
        url = u,
        sink = ltn12.sink.table(t),
        target = t
    }
    if b then
        reqt.source = ltn12.source.string(b)
        reqt.headers = {
            ["content-length"] = string.len(b),
            ["content-type"] = "application/x-www-form-urlencoded"
        }
        reqt.method = "POST"
    end
    return reqt
end

local function check_reqt(reqt)
	local parsed_url = urllib.parse(reqt.url)

	if (parsed_url.scheme == "https" or parsed_url.port == 443) then
		parsed_url.scheme = "https"
		parsed_url.port = 443

		reqt.url = urllib.build(parsed_url)

		return true
	end

	return false
end

--[[
_M.request = socket.protect(function(reqt, body)
    if base.type(reqt) == "string" then return srequest(reqt, body)
    else return trequest(reqt) end
end)
]]

local function fetch_trequest()
	if (type(debug) ~= "table") then error("the debug library is required to use tsched.http!") end

	local old_type = type

	type = function(v)
		local info = debug.getinfo(2, "uf")

		for i = 1, info.nups do
			local name, value = debug.getupvalue(info.func, i)
			
			if (name == "trequest") then
				http_trequest = value
				break
			end
		end

		socket.try(nil)
	end

	http.request("")
	type = old_type

	if (not http_trequest) then
		error("fatal error in tsched.http: failed to get trequest in socket.http (tsched.http unusable)")
	end
end

-- clears the connection, and copies functions from the socket's metatable __index to the connection
local function wrap_connection(conn, sock)
	for i, v in next, conn do
		conn[i] = nil
	end

	conn.sock = sock

	for i, v in next, getmetatable(sock).__index do
		if (type(v) == "function") then
			conn[i] = function(self, ...)
				return v(self.sock, ...)
			end
		end
	end
end

local function http_request(reqt)
	-- use pcall to catch socket.try throws/errors
	local result = { pcall(http_trequest, reqt) }
	local success = table.remove(result, 1)

	if (not success) then
		-- socket.try(false, "one", "two") will return false, { "one" } from pcall
		-- the same code will return nil, "one" from socket.protect()
		-- why are the other arguments ("two") excluded? no idea

		if (type(result[1]) == "table") then 
			return nil, result[1][1]
		end

		return success, unpack(result)
	else
		return unpack(result)
	end
end

local function make_create(reqt, ssl_params)
	return function()
		local conn = {}
		wrap_connection(conn, socket.try(socket.tcp()))

		conn.connect = function(self, host, port)
			local res, err = async.connect(self.sock, host, port)
			if (not res) then return res, err end

			if (ssl_params) then
				local combine = {}

				for i, v in next, reqt do combine[i] = v end
				for i, v in next, ssl_params do combine[i] = v end

				self.sock = socket.try(ssl.wrap(self.sock, combine))
				socket.try(self.sock:dohandshake()) -- this probably blocks, but oh well
			end

			-- socket transformed from a tcp master object to a client object after call to connect, "reset" the connection (wrap it again)
			wrap_connection(self, self.sock)

			self.send = function(self, ...)
				return async.send(self.sock, ...)
			end

			self.receive = function(self, ...)
				return async.receive(self.sock, ...)
			end

			return res
		end

		return conn
	end
end

local function request(reqt, body, ssl_params)
	local simple_request = type(reqt) == "string"
	if (simple_request) then reqt = url_to_table(reqt) end

	local https = check_reqt(reqt)
	if (https) then
		if (not ssl_available) then
			return nil, "luasec is required to make https requests"
		end

		if (http.PROXY or reqt.proxy) then
			return nil, "luasec: proxy not supported"
		elseif (reqt.redirect) then
			return nil, "luasec: redirect not supported"
		end

		if (not ssl_params) then
			ssl_params = {}
		end

		for i, v in next, ssl_default_params do
			ssl_params[i] = ssl_params[i] or v
		end
	else
		ssl_params = nil
	end

	if (reqt.create) then
		return nil, "create function not permitted"
	end

	reqt.create = make_create(reqt, ssl_params)
	local res, code, headers, status = http_request(reqt)

	if (res and simple_request) then
		return table.concat(reqt.target), code, headers, status
	end

	return res, code, headers, status
end

fetch_trequest()

_M.request = request

return _M