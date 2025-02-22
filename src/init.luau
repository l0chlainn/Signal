--!strict

type callback = (...any) -> ()

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

local Connection = {}
Connection.__index = Connection

export type Connection = typeof(setmetatable({} :: {
    isConnected: boolean,

    _signal: Signal,
    _callback: callback,

    _next: Connection?,
    _previous: Connection?,
}, Connection))

local function isConnection(value: any): boolean
    return type(value) == "table" and getmetatable(value) == Connection
end

local function createConnection(signal: Signal, callback: callback): Connection
    return setmetatable({
        isConnected = true,

        _signal = signal,
        _callback = callback,

        _next = nil,
        _previous = nil,
    }, Connection) :: Connection
end

function Connection.disconnect(self: Connection): ()
    if not isConnection(self) then
        error(`expected Connection for self, got '{typeof(self)}'`, 2)
    end

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

local Signal = {}
Signal.__index = Signal

export type Signal = typeof(setmetatable({} :: {
    _headConnection: Connection?,
}, Signal))

local function isSignal(value: any): boolean
    return type(value) == "table" and getmetatable(value) == Signal
end

local function createSignal(): Signal
    return setmetatable({
        _headConnection = nil,
    }, Signal)
end

function Signal.trigger(self: Signal, ...: any): ()
    if not isSignal(self) then
        error(`expected Signal for self, got '{typeof(self)}'`, 2)
    end

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
    if not isSignal(self) then
        error(`expected Signal for self, got '{typeof(self)}'`, 2)
    elseif type(callback) ~= "function" then
        error(`expected function for callback, got '{typeof(callback)}'`, 2)
    end

    local connection = createConnection(self, callback)
    local headConnection = self._headConnection
    if headConnection then
        connection._next = headConnection
        headConnection._previous = connection
    end
    self._headConnection = connection

    return connection
end

function Signal.disconnectAll(self: Signal): ()
    if not isSignal(self) then
        error(`expected Signal for self, got '{typeof(self)}'`, 2)
    end

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

return table.freeze({
    isConnection = isConnection,

    isSignal = isSignal,
    createSignal = createSignal,
})
