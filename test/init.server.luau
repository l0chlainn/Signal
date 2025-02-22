--!strict

-- Test code needs improvement! I am aware, but it's very difficult
-- to do so in Roblox :(

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:FindFirstChild("Packages")

local Signal = require(Packages:FindFirstChild("Signal"))

type Signal = Signal.Signal
type Connection = Signal.Connection

local signal = Signal.new()
print("signal is a Signal: ", Signal.isA(signal, "Signal"))

local connection = signal:connect(function(...)
    print(...)
end)
print("connection is a Connection: ", Signal.isA(connection, "Connection"))

signal:trigger("Hello, World!")
connection:disconnect()
signal:trigger("Goodbye, World!")

signal:connect(function(...)
    print(...)
end)
signal:connect(function(...)
    print(...)
end)
signal:trigger("Fizz!")
signal:disconnectAll()
signal:trigger("Buzz!")
