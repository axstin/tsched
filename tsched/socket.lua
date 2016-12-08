--local socket = require"socket"

local function in_progress(err)
	err = err:lower()

    return  (err == "operation already in progress") or
            (err == "timeout") or
            (err == "wantread") or -- ?
            (err == "wantwrite") -- ?
end

return {
	connect = function(sock,host,port)
	    sock:settimeout(0, "t")

	    local ret, err
	    local tried_before = false

	    yield(function()
	        ret, err = sock:connect(host, port)

	        if (ret or not in_progress(err)) then
	            if ((not ret) and (err == "already connected" and tried_before)) then
	                ret = 1
	                err = nil
	            end

	            return true
	        end

	        tried_before = tried_before or true
	        return false
	    end)

	    return ret, err
  	end;
  
  	send = function(sock, data, i, j)
	    --sock:settimeout(0) -- (BUG?) Including this causes send/recv to bug out when called too fast (the program hangs)
	    local ret, err, index

	    yield(function()
		    ret, err, index = sock:send(data, i, j)

		    if (ret or not in_progress(err)) then
		        return true
		    end

		    return false
	    end)

	    return ret, err, index
  	end;
  
  	receive = function(sock, pattern, prefix)
    	--sock:settimeout(0) -- (BUG?) Including this causes send/recv to bug out when called too fast (the program hangs)

    	local s, err

    	yield(function()
	        s, err = sock:receive(pattern, prefix)

	        --print(s, err)

	        if (s or not in_progress(err)) then
	            return true
	        end 

	        return false
    	end)

  		return s, err
  	end;
}