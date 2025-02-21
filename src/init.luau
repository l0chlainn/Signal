--!strict

-- Yield safe Signal implementation in a DOP style.

type callback = (...any) -> ()

export type connection = {
    isConnected: boolean,

    _signal: signal,
    _callback: callback,

    _nextConnection: connection?,
    _previousConnection: connection?,
}
export type signal = {
    _headConnection: connection?,
}

-- We cache this here to avoid thread creation overhead.
-- This could be improved with a thread pool, since logically it would
-- follow that if a thread yields the first call, it's likely to yield
-- the next call too.
local idleRunner: thread? = nil

local function runCallback(callback: callback, ...: any): ()
    local busyRunner = idleRunner :: thread
    idleRunner = nil
    callback(...)
    idleRunner = busyRunner
end

-- We need a runner so the thread does not die, allowing us to reuse it.
local function runner(): ()
    while true do
        runCallback(coroutine.yield())
    end
end

local function create(): signal
    return {
        _headConnection = nil,
    } :: signal
end

local function trigger(signal: signal, ...: any): ()
    local connection = signal._headConnection
    while connection do
        if not idleRunner then
            idleRunner = task.spawn(runner)
        end
        task.spawn(
            idleRunner :: thread,
            connection._callback,
            ...
        )
        connection = connection._nextConnection
    end
end

local function connect(signal: signal, callback: callback): connection
    local connection = {
        isConnected = true,

        _signal = signal,
        _callback = callback,

        _nextConnection = nil,
        _previousConnection = nil,
    } :: connection
    local headConnection = signal._headConnection
    if headConnection then
        connection._nextConnection = headConnection
        headConnection._previousConnection = connection
    end
    signal._headConnection = connection

    return connection
end

local function disconnect(connection: connection): ()
    if connection.isConnected then
        connection.isConnected = false

        local nextConnection = connection._nextConnection
        local previousConnection = connection._previousConnection
        if nextConnection then
            nextConnection._previousConnection = previousConnection
        end
        if previousConnection then
            previousConnection._nextConnection = nextConnection
        else
            connection._signal._headConnection = nextConnection
        end
    end
end

local function disconnectAll(signal: signal): ()
    local connection = signal._headConnection
    while connection do
        connection.isConnected = false
        connection = connection._nextConnection
    end
    signal._headConnection = nil
end

return table.freeze({
    create = create,
    trigger = trigger,
    connect = connect,
    disconnect = disconnect,
    disconnectAll = disconnectAll,
})
