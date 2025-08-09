# EnaltCast

Super fast and easy to use casting system. Made for projectile physics that's super optimized and light weight.

# Example

`Server`

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fire = ReplicatedStorage.Fire
local Caster = require(ReplicatedStorage.EnaltCast).new()
local ImpactSignal = Caster.NewSignal()

Fire.OnServerEvent:Connect(function(player, origin, direction)
    local Pararms = RaycastParams.new()
	Pararms.FilterType = Enum.RaycastFilterType.Exclude
	Pararms.FilterDescendantsInstances = {player.Character}

    local bullet = ReplicatedStorage.Bullet:Clone()
    bullet.Parent = workspace

    Caster:Cast({
        Speed = 100,
        ExtraForce = Vector3.new(0, -workspace.Gravity / 5, 0),
		RayParams = Pararms,
        RichochetAngle = 10,
        RichochetHardness = 9,
        PenetrationPower = 50,
		OnImpact = ImpactSignal
    }, origin, direction, bullet)
end)

ImpactSignal:Connect(function(...)
    print(...)
end)
```

`Client`
```lua
local UserInputService = game:GetService("UserInputService")
local RpelicatedStorage = game:GetService("ReplicatedStorage")

local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()

Player.CharacterAdded:Connect(function(character)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			child.Activated:Connect(function()

				local origin = character.Head.Position
				local hit = Mouse.Hit

				local direction = (hit.Position - origin).unit

				RpelicatedStorage.Fire:FireServer(origin, direction)
			end)
		end
	end)
end)
```

# Class
**TO DO**