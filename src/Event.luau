--!strict

local Connection = require(script.Parent:FindFirstChild("Connection"))

type Connection = Connection.Connection

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

local Event = {}
Event.__index = Event

export type Event = typeof(setmetatable({} :: {
    _headConnection: Connection?,
}, Event))

local function isEvent(value: any): boolean
    return type(value) == "table" and getmetatable(value) == Event
end

local function createEvent(): Event
    return setmetatable({
        _headConnection = nil,
    }, Event)
end

function Event._link(self: Event, connection: Connection): ()
    local headConnection = self._headConnection
    if headConnection then
        connection._next = headConnection
        headConnection._previous = connection
    end
    self._headConnection = connection
end

function Event._unlink(self: Event, connection: Connection): ()
    local nextConnection = connection._next
    local previousConnection = connection._previous
    if nextConnection then
        nextConnection._previous = previousConnection
    end
    if previousConnection then
        previousConnection._next = nextConnection
    else
        self._headConnection = nextConnection
    end
end

function Event.trigger(self: Event, ...: any): ()
    if not isEvent(self) then
        error(`expected Event for self, got '{typeof(self)}'`, 2)
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

function Event.connect(self: Event, callback: callback): Connection
    if not isEvent(self) then
        error(`expected Event for self, got '{typeof(self)}'`, 2)
    elseif type(callback) ~= "function" then
        error(`expected function for callback, got '{typeof(callback)}'`, 2)
    end

    local connection
    connection = Connection.new(callback, function()
        self:_unlink(connection)
    end)
    self:_link(connection)

    return connection
end

function Event.disconnectAll(self: Event): ()
    if not isEvent(self) then
        error(`expected Event for self, got '{typeof(self)}'`, 2)
    end

    local connection = self._headConnection
    while connection do
        connection.isConnected = false
        connection = connection._next
    end
    self._headConnection = nil
end

return table.freeze({
    is = isEvent,
    new = createEvent,
})
