--!strict

local Connection = require(script:FindFirstChild("Connection"))
local Event = require(script:FindFirstChild("Event"))

export type Connection = Connection.Connection
export type Event = Event.Event

return table.freeze({
    Connection = Connection,
    Event = Event,
})
