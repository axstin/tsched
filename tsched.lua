--[=[
tsched.lua

Example of usage:
lua(jit) tsched.lua target.lua arg1 arg2 ...

For use with sublime text (sublime-build file) (Tools->Build System->New Build System...):
{
	"cmd": ["luajit", "PATH TO TSCHED.LUA", "$file"],
	"selector": "source.lua"
}

]=]

--[[ Init ]]

local usage = "usage: lua[jit] tsched.lua targetfile.lua ..."
local targetfile = arg[1]
local targetarg = {}

if (not targetfile) then error(usage) end

do
    -- adjust arguments

    for i = 1, #arg do
        targetarg[i - 1] = arg[i]
    end

    targetarg[-1] = arg[-1]
end

local _create = coroutine.create 
local _resume = coroutine.resume 
local _running = coroutine.running 
local _status = coroutine.status 
local _wrap = coroutine.wrap 
local _yield = coroutine.yield
local _unpack = table.unpack or unpack
local _insert = table.insert
local _remove = table.remove
local _clock = os.clock

local threads = {}

local function push(t)
    _insert(threads, t)
end

local function pushback(t)
    _insert(threads, 1, t)
end

local function pop()
    return _remove(threads)
end

local function scheduler()
    while (true) do
        if (#threads == 0) then break end

        local thread = pop()
        local res = { thread.condition() }

        if (#res > 0) then
            if (_remove(res, 1)) then
                assert(_resume(thread.co, _unpack(res)))
            else
                pushback(thread)
            end
        end
    end
end

function run(f, ...)
    -- creates a new thread, adds it to the front of the queue and suspends current thread

    local args = {...}

    push({
        co = _create(f);
        condition = function()
            return true, unpack(args)
        end;
    })

    suspend()
end

function spawn(f, ...)
    -- creates a new thread adds it to the back of the queue

    local args = {...}

    pushback({
        co = _create(f);
        condition = function()
            return true, unpack(args)
        end
    })
end

function wait(t)
    -- waits for t seconds

    if (type(t) ~= "number") then t = 0 end

    local suspendtime = _clock()

    pushback({
        co = _running();
        condition = function()
            local elapsed = _clock() - suspendtime

            if (elapsed > t) then
                return true, elapsed
            end 

            return false
        end
    })

    return _yield()
end

function suspend()
    -- suspends the current thread and adds it to the back of the queue

    pushback({
        co = _running();
        condition = function()
            return true
        end
    })

    _yield()
end

function yield(f, ...)
    -- yields thread until a condition is met

    assert(type(f) == "function", "yield: function expected")
    local args = {...}

    pushback({
        co = _running();
        condition = function()
            return f(_unpack(args))
        end
    })

    return _yield()
end

function delay(t, f, ...)
    -- creates a new thread which waits 't' seconds before calling 'f'

    if (type(t) ~= "number") then t = 0 end
    assert(type(f) == "function", "delay: function expected")

    local args = {...}

    spawn(function()
        wait(t)
        f(_unpack(args))
    end)
end

--[[ Execution ]]

_TSCHED = true

do
    local f = assert(loadfile(targetfile))
    spawn(f)
end

scheduler()
