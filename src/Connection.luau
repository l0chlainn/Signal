--!strict

type callback = (...any) -> ()
type disconnect = () -> ()

local Connection = {}
Connection.__index = Connection

export type Connection = typeof(setmetatable({} :: {
    isConnected: boolean,

    _callback: callback,
    _disconnect: disconnect,

    _next: Connection?,
    _previous: Connection?,
}, Connection))

local function isConnection(value: any): boolean
    return type(value) == "table" and getmetatable(value) == Connection
end

local function createConnection(
    callback: callback,
    disconnect: disconnect
): Connection
    if type(callback) ~= "function" then
        error(`expected function for callback, got '{typeof(callback)}'`, 2)
    elseif type(disconnect) ~= "function" then
        error(`expected function for disconnect, got '{typeof(disconnect)}'`, 2)
    end

    return setmetatable({
        isConnected = true,

        _callback = callback,
        _disconnect = disconnect,

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
        self._disconnect()
    end
end

return table.freeze({
    is = isConnection,
    new = createConnection,
})
