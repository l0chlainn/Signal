--!strict

-- Test code needs improvement! I am aware, but it's very difficult
-- to do so in Roblox :(

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:FindFirstChild("Packages")

local Signal = require(Packages:FindFirstChild("Signal"))

type Connection = Signal.Connection
type Event = Signal.Event

local Connection = Signal.Connection
local Event = Signal.Event

local event = Event.new()
print(`event is a Event: {Event.is(event)}`)

local connection = event:connect(function(...)
    print(...)
end)
print(`connection is a Connection: {Connection.is(connection)}`)

event:trigger("Hello, World!")
connection:disconnect()
event:trigger("Goodbye, World!")

event:connect(function(...)
    print(...)
end)
event:connect(function(...)
    print(...)
end)
event:trigger("Fizz!")
event:disconnectAll()
event:trigger("Buzz!")
