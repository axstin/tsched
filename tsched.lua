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

local Usage = "lua[jit] tsched.lua targetfile ..."
local TargetFile = arg[1]
local TargetArg = {}

if (not TargetFile) then error('usage: ' .. Usage) end

for i = 1, #arg do
    TargetArg[i - 1] = arg[i]
end

local _create = coroutine.create 
local _resume = coroutine.resume 
local _running = coroutine.running 
local _status = coroutine.status 
local _wrap = coroutine.wrap 
local _yield = coroutine.yield
local unpack = table.unpack or unpack

local Threads = {}

local function Push(t)
    table.insert(Threads, t)
    return t
end

local function PushBack(t)
    table.insert(Threads, 1, t)
    return t
end

local function Pop()
    return table.remove(Threads)
end

local function Scheduler()
    while (true) do
        if (#Threads == 0) then break end
        local thread = Pop()

        local ctime = os.clock()
        local ret

        --print("tsched: " .. thread.state)

        if (thread.state == "resume") then
            -- normal thread wishing to be resumed :D
            -- requires 'arg' 
            thread.state = "running"

            if (not thread.arg) then thread.arg = {} end
            ret = {_resume(thread.co, unpack(thread.arg))}
        elseif (thread.state == "wait") then
            -- this thread is waiting for a specified amount of time
            -- if the time is up, resume the thread and remove it from the queue
            -- else, leave it alone

            if (ctime > (thread.suspend_time + thread.delay)) then
                -- time's up
                thread.state = "running"
                ret = {_resume(thread.co, ctime - thread.suspend_time)}
                thread.suspend_time = nil
                thread.delay = nil
            else
                PushBack(thread)
            end
        elseif (thread.state == "yield") then
            -- this thread is waiting for a condition to be met
            -- let's call its callback function and resume the thread if it returns true

            local yield_ret = {thread.f(unpack(thread.arg))}
            if (table.remove(yield_ret, 1)) then
                thread.state = "running"
                ret = {_resume(thread.co, unpack(yield_ret))}
                thread.f = nil
                thread.arg = nil
            else
                PushBack(thread)
            end
        end

        -- print(ret and "tsched: success" or "tsched: fail")
        -- local s = "tsched list: "
        -- for i, v in next, Threads do s = s .. tostring(v.state) .. ", " end
        -- print(s)

        if (ret and not ret[1]) then
            error(ret[2])
        end
    end
end

function run(f, ...)
    -- creates a new thread, adds it to the front of the queue and suspends current thread
    Push({
        state = "resume";
        co = _create(f);
        arg = {...};
    })

    _yield()
end

function spawn(f, ...)
    -- creates a new thread adds it to the back of the queue
    PushBack({
        state = "resume";
        co = _create(f);
        arg = {...};
    })
end

function suspend()
    -- suspends the current thread and adds it to the back of the queue
    wait(-1)
end

function wait(t)
    -- waits for t seconds
    if (not t or type(t) ~= "number") then t = 0 end

    PushBack({
        state = "wait";
        co = coroutine.running();
        suspend_time = os.clock();
        delay = t;
    })

    return _yield()
end

function yield(f, ...)
    -- yields thread until a condition is met
    if (not f or type(f) ~= "function") then error("yield: function expected") end

    PushBack({
        state = "yield";
        co = coroutine.running();
        f = f;
        arg = {...};
    })

    return _yield()
end

--[[ Execution ]]

_TSCHED = true

do
    local f = assert(loadfile(TargetFile))
    spawn(f)
end

Scheduler()
