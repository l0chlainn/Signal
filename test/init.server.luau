--!strict

-- Test code needs improvement! I am aware, but it's very difficult
-- to do so in Roblox :(

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:FindFirstChild("Packages")

local Signal = require(Packages:FindFirstChild("Signal"))

local signal = Signal.create()
local connection = Signal.connect(signal, function(...)
    print(...)
end)
Signal.trigger(signal, "Hello, World!")
Signal.disconnect(connection)
Signal.trigger(signal, "Goodbye, World!")

local signalAll = Signal.create()
Signal.connect(signalAll, function(...)
    print(...)
end)
Signal.connect(signalAll, function(...)
    print(...)
end)
Signal.trigger(signalAll, "FooBar!")
Signal.disconnectAll(signalAll)
Signal.trigger(signalAll, "FizzBuzz!")
