--!strict

type callback = (...any) -> ()

type ConnectionImplementation = {
    __index: ConnectionImplementation,

    disconnect: (self: Connection) -> (),
}
export type Connection = typeof(setmetatable({} :: {
    isConnected: boolean,

    _callback: callback,
    _signal: Signal,

    _next: Connection?,
    _previous: Connection?,
}, {} :: ConnectionImplementation))

type SignalImplementation = {
    __index: SignalImplementation,

    trigger: (self: Signal, ...any) -> (),
    connect: (self: Signal, callback: callback) -> Connection,
    disconnectAll: (self: Signal) -> (),
}
export type Signal = typeof(setmetatable({} :: {
    _headConnection: Connection?,
}, {} :: SignalImplementation))

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

local Connection = {} :: ConnectionImplementation
Connection.__index = Connection

function Connection.disconnect(self: Connection): ()
    if self.isConnected then
        self.isConnected = false

        local nextConnection = self._next
        local previousConnection = self._previous
        if nextConnection then
            nextConnection._previous = previousConnection
            self._next = nil
        end
        if previousConnection then
            previousConnection._next = nextConnection
            self._previous = nil
        else
            self._signal._headConnection = nextConnection
        end
    end
end

local Signal = {} :: SignalImplementation
Signal.__index = Signal

function Signal.trigger(self: Signal, ...: any): ()
    local connection = self._headConnection
    while connection do
        if not idleRunner then
            idleRunner = task.spawn(runner)
        end
        task.spawn(
            idleRunner :: thread,
            connection._callback,
            ...
        )
        connection = connection._next
    end
end

function Signal.connect(self: Signal, callback: callback): Connection
    local connection = setmetatable({
        isConnected = true,

        _callback = callback,
        _signal = self,

        _next = nil,
        _previous = nil,
    }, Connection) :: Connection
    local headConnection = self._headConnection
    if headConnection then
        connection._next = headConnection
        headConnection._previous = connection
    end
    self._headConnection = connection

    return connection
end

function Signal.disconnectAll(self: Signal): ()
    local currentConnection = self._headConnection
    while currentConnection do
        local nextConnection = currentConnection._next

        currentConnection.isConnected = false
        currentConnection._next = nil
        currentConnection._previous = nil

        currentConnection = nextConnection
    end
    self._headConnection = nil
end

local function is(value: any, name: string): boolean
    if name == "Signal" then
        return type(value) == "table" and getmetatable(value) == Signal
    elseif name == "Connection" then
        return type(value) == "table" and getmetatable(value) == Connection
    end
    return false
end

local function new(): Signal
    return setmetatable({
        _headConnection = nil,
    }, Signal)
end

return table.freeze({
    is = is,
    new = new,
})
