# tsched
Thread Scheduler for Lua

***

### Usage

To run a file with `tsched`, simply add `tsched.lua` before the target file and any arguments.

###### Command
`luajit tsched.lua target.lua arg1 arg2 ...`

###### Sublime Text Build-System File (Tools->Build System->New Build System...)

```json
{
	"cmd": ["luajit", "PATHTOTSCHED.lua", "$file"],
	"selector": "source.lua"
}
```

***

### Documentation

###### Docs

```lua
void run(function f, tuple args)
```
Creates a new thread with function `f`, pushes it to the front of the thread scheduler, and suspends the current thread-- essentially running `f` immediately.


```lua
void spawn(function f, tuple args)
```
Creates a new thread with function `f` and adds it to the back of the thread queue. The current thread is not suspended.


```lua
void wait(number delay)
```
Pauses the current thread for `delay` seconds.
If `delay` is not a number or nil, it is set to 0.


```lua
void suspend()
```
Suspends the current thread.


```lua
tuple yield(function f, tuple args)
```
Suspends the current thread until a condition is met. To resume the thread, `f` must return `true`.
`f` is called with arguments `args` and any extra arguments returned from `f` when the thread is resumed (it returns true) will be returned to `yield`.


```lua
void delay(number delay, function f, tuple args)
```
Calls `f` with arguments `args` after `delay` seconds. It is equivalent to ```spawn(function() wait(delay) f(...) end)```

###### Extra

`tsched` was inspired by and is very similar to ROBLOX's Lua thread scheduler. For further documentation, see http://wiki.roblox.com/index.php?title=Thread_scheduler

***

### Code Example

###### Input

```lua
print"main thread begin"

local function spawned_function(a, b, c)
	print"in spawned_function"

	local condition = false

	-- set condition to true after 2 seconds
	delay(2, function()
		condition = true
	end)

	-- thread will yield until condition is true
	print(yield(function()
		if (condition) then
			return true, "hello!"
		end

		return false
	end))

	print"spawned_function end"
end

local function delayed_function(a, b, c)
	print"in delayed_function"
	print(a, b, c)

	run(function()
		print"in run function"

		spawn(spawned_function, 4, 5, 7)

		print"waiting ..."
		wait(1)

		print"run function end"
	end)

	print"delayed_function end"
end

delay(1, delayed_function, 1, 2, 3)

print"main thread end"
```

###### Output

```
main thread begin
main thread end
in delayed_function
1	2	3
in run function
waiting ...
delayed_function end
in spawned_function
run function end
hello!
spawned_function end
[Finished in 3.1s]
```

***

### Extensions

#### socket.lua

`socket.lua` is an extension of [luasockets](https://github.com/diegonehab/luasocket) for `tsched` that allows for asynchronous functionality. 

##### Example

###### Input

```lua
local socket = require"socket"
local async = require"tsched.socket"

local function download(host, file)
	local sock = socket.tcp()
	local buff = ""

	assert(async.connect(sock, host, 80))

	async.send(sock, "GET " .. tostring(file) .. " HTTP/1.1\r\n\r\n")

	while (true) do
		local str, err = async.receive(sock)

		if (str) then 
			buff = buff .. str
		elseif (err == "closed") then
			break
		end
	end

	sock:close()

	return buff
end

for i = 1, 5 do
	spawn(function()
		print("download start " .. i)
		download("www.example.com", "/")
		print("download end " .. i)
	end)
end

for i = 1, 5 do
	spawn(function()
		print("thread " .. i)
	end)
end
```
###### Output

```
download start 1
download start 2
download start 3
download start 4
download start 5
thread 1
thread 2
thread 3
thread 4
thread 5
download end 1
download end 4
download end 5
download end 3
download end 2
[Finished in 0.1s]
```

#### http.lua

Like `socket.lua`, `http.lua` gives asynchronous functionality to [luasockets](https://github.com/diegonehab/luasocket)'s http namespace/library. The module also supports HTTPS, if [luasec](https://github.com/brunoos/luasec) is installed.

For documentation, see: http://w3.impa.br/~diego/software/luasocket/http.html#request 

##### Example

###### Input

```lua
local http = require"tsched.http"

for i = 1, 10 do
	spawn(function()
		local result, err = http.request("https://www.example.com:443/")
		print(result:sub(1, 10))
	end)
end
```

###### Output

```
<!doctype 
<!doctype 
<!doctype 
<!doctype 
<!doctype 
<!doctype 
<!doctype 
<!doctype 
<!doctype 
<!doctype 
[Finished in 1.0s]
```

***






