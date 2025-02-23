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

event:fire("Hello, World!")
connection:disconnect()
event:fire("Goodbye, World!")

event:connect(function(...)
    print(...)
end)
event:connect(function(...)
    print(...)
end)
event:fire("Fizz!")
event:disconnectAll()
event:fire("Buzz!")

local a, b, c, d
d = event:connect(function()
    print("D")
end)
c = event:connect(function()
    print("C")
    b:disconnect()
    c:disconnect()
    d:disconnect()
end)
b = event:connect(function()
    print("B")
end)
a = event:connect(function()
    print("A")
    a:disconnect()
end)
event:fire()
event:fire()

print(a, b, c, d)

for i = 1, 10 do
    event:connect(function()
        print(i)
    end)
end
event:fire()
event:disconnectAll()
event:fire()

for i = 1, 10 do
    event:connect(function()
        task.wait()
        print(i)
    end)
end
event:fire()
event:disconnectAll()
event:fire()
