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
    isFiring: boolean,
    _headConnection: Connection?,
    _disconnections: {Connection},
}, Event))

local function isEvent(value: any): boolean
    return type(value) == "table" and getmetatable(value) == Event
end

local function createEvent(): Event
    return setmetatable({
        isFiring = false,
        _headConnection = nil,
        _disconnections = {},
    }, Event)
end

function Event.fire(self: Event, ...: any): ()
    if not isEvent(self) then
        error(`expected Event for self, got '{typeof(self)}'`, 2)
    end

    self.isFiring = true

    local connection = self._headConnection
    while connection do
        if connection.isConnected then
            if not idleRunner then
                idleRunner = task.spawn(runner)
            end
            task.spawn(
                idleRunner :: thread,
                connection._callback :: callback,
                ...
            )
        end
        connection = connection._next
    end

    -- Any disconnection attempts made while firing are safe to remove now.
    for _, disconnection in self._disconnections do
        disconnection._next = nil
        disconnection._previous = nil
    end
    table.clear(self._disconnections)

    self.isFiring = false
end

function Event._disconnect(self: Event, connection: Connection): ()
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

    -- We don't want to mess with a list in use, because it creates
    -- navigation issues. Instead we'll queue it to be removed later,
    -- but if the list isn't in use it's safe to remove now.
    if self.isFiring then
        table.insert(self._disconnections, connection)
    else
        connection._next = nil
        connection._previous = nil
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
        self:_disconnect(connection)
    end)

    local headConnection = self._headConnection
    if headConnection then
        connection._next = headConnection
        headConnection._previous = connection
    end
    self._headConnection = connection

    return connection
end

function Event.disconnectAll(self: Event): ()
    if not isEvent(self) then
        error(`expected Event for self, got '{typeof(self)}'`, 2)
    end

    local isFiring = self.isFiring
    local disconnections = self._disconnections
    local connection = self._headConnection
    while connection do
        if connection.isConnected then
            connection.isConnected = false

            -- It's important to clean these references up, since
            -- they'll keep the Event alive if this connection isn't
            -- cleared.
            connection._callback = nil
            connection._disconnect = nil

            if isFiring then
                table.insert(disconnections, connection)
            else
                connection._next = nil
                connection._previous = nil
            end
        end
        connection = connection._next
    end
    self._headConnection = nil
end

return table.freeze({
    is = isEvent,
    new = createEvent,
})
