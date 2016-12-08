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

### Code Examples

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




