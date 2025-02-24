--!strict

type callback = () -> ()

local Connection = {}
Connection.__index = Connection

export type Connection = typeof(setmetatable({} :: {
    isConnected: boolean,

    _callback: callback?,
    _disconnect: callback?,

    _next: Connection?,
    _previous: Connection?,
}, Connection))

local function isConnection(value: any): boolean
    return type(value) == "table" and getmetatable(value) == Connection
end

local function createConnection(
    callback: callback,
    disconnect: callback
): Connection
    return setmetatable({
        isConnected = true,

        _callback = callback,
        _disconnect = disconnect,

        _next = nil,
        _previous = nil,
    }, Connection)
end

function Connection.disconnect(self: Connection): ()
    if self.isConnected then
        self.isConnected = false

        (self._disconnect :: callback)()

        -- It's important to clean these references up, since
        -- they'll keep the Event alive if this connection isn't
        -- cleared.
        self._callback = nil
        self._disconnect = nil
    end
end

return table.freeze({
    is = isConnection,
    new = createConnection,
})
