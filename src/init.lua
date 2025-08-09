--!strict
--!optimize 2
--- @diagnostic disable: undefined-doc-name
-- Original Author: AlternativeFent
-- Editor and Optimiser: EnumEnv
-- Services --
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Imports --
local Types = require(script.Types)
local Visualiser = require(script.Visualiser)
local Settings = require(script.Settings)
local MathUtils = require(script.Math)
local FastSignal = require(script.FastSignal)

-- Class --
local Caster = {}
Caster.__index = Caster

-- Instances --
local ActorsCreated = false
local CreatingActors = false

local BulletActors = {}
local BulletFolder = workspace:FindFirstChild("BulletsFolder") or Instance.new("Folder")
BulletFolder.Name = "BulletsFolder"
BulletFolder.Parent = workspace

if not ActorsCreated and not CreatingActors then
	CreatingActors = true
	
	for i = 1, Settings.ActorAmount do
		local BulletActor = Instance.new("Actor")
		BulletActor.Name = "BulletActor"..i
		BulletActor.Parent = script

		BulletActors[i] = BulletActor

		if RunService:IsServer() then
			local actorScript = script:FindFirstChild("BulletActorScriptServer")
			if actorScript then
				actorScript:Clone().Parent = BulletActor
			end
		elseif RunService:IsClient() then
			local actorScript = script:FindFirstChild("BulletActorScriptClient")
			if actorScript then
				actorScript:Clone().Parent = BulletActor
			end
		end
	end
	
	ActorsCreated = true
end

-- Types --
type CastConfig = Types.CastConfig
type ProjectileData = Types.ProjectileData
export type Caster = typeof(Caster) & {
	_connections: { RBXScriptConnection },
	_activeBullets: { ProjectileData },
	_actorBullets: { [string]: ProjectileData },
	_actorWorkloads: { [number]: number },
	_bulletToActorMap: { [string]: number },
	_bulletIdCounter: number,
	_currentActorIndex: number,
	_deltaTime: number,
	_lastHeartbeat: number,
	_useParallel: boolean,
}

-- Module Functions --
--- Creates a new instance of 'Caster'.
--- @return Caster
function Caster.new(): Caster
	local self: Caster = setmetatable({}, Caster) :: any

	self._connections = {}
	self._activeBullets = {}
	self._actorBullets = {}
	self._actorWorkloads = {}
	self._bulletToActorMap = {}
	self._bulletIdCounter = 0
	self._currentActorIndex = 1
	self._deltaTime = 0
	self._lastHeartbeat = os.clock()
	self._useParallel = Settings.ParallelProcessing

	for i = 1, Settings.ActorAmount do
		self._actorWorkloads[i] = 0
	end

	if self._useParallel then
		self:_setupActorCommunication()
	end

	if RunService:IsClient() then
		table.insert(self._connections, RunService.RenderStepped:Connect(function(deltaTime: number) 
			self:_heartbeat(deltaTime) 
		end))
	else
		table.insert(self._connections, RunService.Heartbeat:Connect(function(deltaTime: number) 
			self:_heartbeat(deltaTime) 
		end))
	end

	return self :: any
end

--- Sets up communication with all bullet actors
function Caster._setupActorCommunication(self: Caster)
	local communicationFolder = script:FindFirstChild("ActorComm") or Instance.new("Folder")
	communicationFolder.Name = "ActorComm"
	communicationFolder.Parent = script

	local bulletUpdateEvent = communicationFolder:FindFirstChild("BulletUpdate") or Instance.new("BindableEvent")
	bulletUpdateEvent.Name = "BulletUpdate"
	bulletUpdateEvent.Parent = communicationFolder

	local bulletHitEvent = communicationFolder:FindFirstChild("BulletHit") or Instance.new("BindableEvent")
	bulletHitEvent.Name = "BulletHit" 
	bulletHitEvent.Parent = communicationFolder

	table.insert(self._connections, bulletUpdateEvent.Event:Connect(function(data)
		self:_handleActorUpdate(data)
	end))

	table.insert(self._connections, bulletHitEvent.Event:Connect(function(data)
		self:_handleActorHit(data)
	end))
end

--- Gets the actor with the least workload for load balancing
--- @return number actorIndex
function Caster._getLeastLoadedActor(self: Caster): number
	local minWorkload = math.huge
	local bestActor = 1

	for i = 1, Settings.ActorAmount do
		if self._actorWorkloads[i] < minWorkload then
			minWorkload = self._actorWorkloads[i]
			bestActor = i
		end
	end

	return bestActor
end

--- Gets the next actor using round-robin distribution
--- @return number actorIndex
function Caster._getNextActorRoundRobin(self: Caster): number
	local actorIndex = self._currentActorIndex
	self._currentActorIndex = (self._currentActorIndex % Settings.ActorAmount) + 1
	return actorIndex
end

--- Handles bullet updates from actors
function Caster._handleActorUpdate(self: Caster, data: any)
	local bulletId = data.bulletId
	local projectileData = self._actorBullets[bulletId]

	if not projectileData then return end

	projectileData.CurrentPosition = data.position
	projectileData.Time = data.time

	if projectileData.Bullet then
		projectileData.Bullet.CFrame = data.cframe
	end

	if data.destroy then
		if projectileData.Bullet then
			projectileData.Bullet:Destroy()
		end

		local actorIndex = self._bulletToActorMap[bulletId]
		if actorIndex then
			self._actorWorkloads[actorIndex] = math.max(0, self._actorWorkloads[actorIndex] - 1)
			self._bulletToActorMap[bulletId] = nil
		end

		self._actorBullets[bulletId] = nil
	end
end

--- Handles bullet hits from actors
function Caster._handleActorHit(self: Caster, data: any)
	local bulletId = data.bulletId
	local projectileData = self._actorBullets[bulletId]

	if not projectileData then return end

	projectileData.Config.OnImpact:Fire(data.rayResult, projectileData)

	if Settings.Visualise then
		Visualiser.VisualiseHit(CFrame.new(data.rayResult.Position))
	end
end

--- Destroys the caster class
function Caster.Destroy(self: Caster)
	for _, connection in self._connections do
		connection:Disconnect()
	end

	if self._useParallel then
		for i = 1, Settings.ActorAmount do
			if BulletActors[i] then
				BulletActors[i]:SendMessage("Cleanup", {})
			end
		end
	end

	self._connections = {}
	self._activeBullets = {}
	self._actorBullets = {}
	self._actorWorkloads = {}
	self._bulletToActorMap = {}
end

--- Casts a projectile bullet.
--- @param config CastConfig the configuration for the cast
--- @param origin Vector3 the origin of the cast
--- @param direction Vector3 the direction of the cast
--- @param bullet BasePart? the new bullet part to be casted
function Caster.Cast(self: Caster, config: CastConfig, origin: Vector3, direction: Vector3, bullet: BasePart?)
	if RunService:IsServer() and bullet and Settings.SafeMode then
		warn("It's recommended to replicate bullets on the client!")
		return
	end

	if bullet then
		bullet.Parent = BulletFolder
		local ancestryConnection
		ancestryConnection = bullet.AncestryChanged:Connect(function()
			if bullet and bullet.Parent then
				if bullet.Parent ~= nil then
					bullet.Parent = BulletFolder
				else
					ancestryConnection:Disconnect()
				end
			else
				ancestryConnection:Disconnect()
			end
		end)
	end

	local projectileData: ProjectileData = {
		Config = config,
		Origin = origin,
		Direction = direction,
		Time = 0,
		CurrentPosition = origin,
		CurrentDirection = Vector3.zero,
		Velocity = direction * config.Speed,
		Bullet = bullet,
	}

	if self._useParallel then
		self._bulletIdCounter += 1
		local bulletId = tostring(self._bulletIdCounter)
		self._actorBullets[bulletId] = projectileData

		local actorIndex
		if Settings.LoadBalanceStrategy == "RoundRobin" then
			actorIndex = self:_getNextActorRoundRobin()
		else
			actorIndex = self:_getLeastLoadedActor()
		end

		self._actorWorkloads[actorIndex] += 1
		self._bulletToActorMap[bulletId] = actorIndex

		local actorData = {
			bulletId = bulletId,
			origin = origin,
			direction = direction,
			speed = config.Speed,
			extraForce = config.ExtraForce or Vector3.zero,
			lifetime = config.Lifetime or 5,
			rayParams = config.RayParams,
		}

		BulletActors[actorIndex]:SendMessage("CastBullet", actorData)
	else
		print("added")
		table.insert(self._activeBullets, projectileData)
	end
end

--- Gets the bullet folder where all bullets are held.
--- @return Folder
function Caster.GetBulletFolderAsync(self: Caster): Folder
	return BulletFolder or workspace:WaitForChild("BulletsFolder")
end

--- Utility function to create a new FastSignal signal
--- @return FastSignal.ScriptSignal<T1, T2, T3?>
function Caster.NewSignal<T1, T2, T3>(self: Caster): FastSignal.ScriptSignal<T1, T2, T3?>
	return FastSignal.new()
end

--- Gets current workload distribution across actors
--- @return { [number]: number }
function Caster.GetWorkloadDistribution(self: Caster): { [number]: number }
	local distribution = {}
	for i = 1, Settings.ActorAmount do
		distribution[i] = self._actorWorkloads[i]
	end
	return distribution
end

--- Gets total bullets being processed across all actors
--- @return number
function Caster.GetTotalActorBullets(self: Caster): number
	local total = 0
	for i = 1, Settings.ActorAmount do
		total += self._actorWorkloads[i]
	end
	return total
end

--- Toggles between parallel and single-threaded processing
--- @param useParallel boolean
function Caster.SetParallelProcessing(self: Caster, useParallel: boolean)
	if self._useParallel == useParallel then return end

	if useParallel then
		for i = #self._activeBullets, 1, -1 do
			local projectileData = self._activeBullets[i]
			self._bulletIdCounter += 1
			local bulletId = tostring(self._bulletIdCounter)

			self._actorBullets[bulletId] = projectileData

			local actorIndex = self:_getLeastLoadedActor()
			self._actorWorkloads[actorIndex] += 1
			self._bulletToActorMap[bulletId] = actorIndex

			local actorData = {
				bulletId = bulletId,
				origin = projectileData.Origin,
				direction = projectileData.Direction,
				speed = projectileData.Config.Speed,
				extraForce = projectileData.Config.ExtraForce or Vector3.zero,
				lifetime = projectileData.Config.Lifetime or 5,
				rayParams = projectileData.Config.RayParams,
				currentPosition = projectileData.CurrentPosition,
				time = projectileData.Time,
				velocity = projectileData.Velocity,
			}

			BulletActors[actorIndex]:SendMessage("CastBullet", actorData)
			table.remove(self._activeBullets, i)
		end
	else
		for i = 1, Settings.ActorAmount do
			BulletActors[i]:SendMessage("Cleanup", {})
		end

		for bulletId, projectileData in self._actorBullets do
			table.insert(self._activeBullets, projectileData)
		end

		self._actorBullets = {}
		self._bulletToActorMap = {}
		for i = 1, Settings.ActorAmount do
			self._actorWorkloads[i] = 0
		end
	end

	self._useParallel = useParallel
end

---------------------
-- PRIVATE METHODS --
---------------------

--- Update loop for projectile bullets.
--- @param deltaTime number The time between the last frame and the current frame.
function Caster._heartbeat(self: Caster, deltaTime: number)
	self._deltaTime = deltaTime

	local currentTime = os.clock()
	local timeSinceUpdate = currentTime - self._lastHeartbeat
	local updateInterval = 1 / Settings.UpdateRate

	if timeSinceUpdate < updateInterval then
		return
	end

	if not self._useParallel then
		for index, data in self._activeBullets do
			local hit, raycastResult = self:_updateProjectile(data)

			if hit then
				if data.Bullet then
					data.Bullet:Destroy() 
				end

				table.remove(self._activeBullets, index)
			end
		end
	end

	if self._useParallel then
		local heartbeatData = {
			deltaTime = deltaTime,
			updateInterval = updateInterval,
			visualise = Settings.Visualise
		}

		for i = 1, Settings.ActorAmount do
			BulletActors[i]:SendMessage("Heartbeat", heartbeatData)
		end
	end

	self._lastHeartbeat = os.clock()
end

--- Handles the updating position of the bullet (single-threaded fallback)
--- @param projectileData ProjectileData
--- @return boolean, RaycastResult?
function Caster._updateProjectile(self: Caster, projectileData: ProjectileData): (boolean, RaycastResult?)
	local displacement = MathUtils.GetPositionAtTime(projectileData)
	local projectilePosition = projectileData.CurrentPosition + displacement

	local velocity = projectileData.Velocity + projectileData.Config.ExtraForce * projectileData.Time
	local lookVector = velocity.Magnitude > 0 and velocity.Unit or Vector3.new(0, 0, -1)

	local rayResult = workspace:Raycast(
		projectileData.CurrentPosition,
		projectilePosition - projectileData.CurrentPosition,
		projectileData.Config.RayParams
	)

	if projectileData.Bullet then
		projectileData.Bullet.CFrame = CFrame.new(projectilePosition, projectilePosition + lookVector)
	end

	local destroy = false
	if rayResult then
		destroy = self:_hit(projectileData, rayResult)
	end

	if projectileData.Time > (projectileData.Config.Lifetime or 5) or destroy then
		return true, rayResult
	end

	projectileData.Time += self._deltaTime
	projectileData.CurrentDirection = projectileData.CurrentPosition - projectilePosition
	projectileData.CurrentPosition = projectilePosition

	if Settings.Visualise then
		Visualiser.VisualiseSegment(CFrame.new(projectilePosition, projectilePosition + lookVector), displacement.Magnitude)
	end

	return false
end

--- Handles the impact of the bullet (single-threaded fallback)
--- @param projectileData ProjectileData 
--- @param rayResult RaycastResult
--- @return boolean (if should destroy)
function Caster._hit(self: Caster, projectileData: ProjectileData, rayResult: RaycastResult): boolean
	if Settings.Visualise then
		Visualiser.VisualiseHit(CFrame.new(rayResult.Position))
	end

	local normal = rayResult.Normal
	local unitDirection = projectileData.CurrentDirection.Unit
	local surfaceAngle = math.acos(unitDirection:Dot(normal.Unit))
	local hardness = Settings.SurfaceHardness[rayResult.Material] or Settings.SurfaceHardness.Default

	-- // Ricochet
	if projectileData.Config.RichochetAngle and surfaceAngle <= math.rad(projectileData.Config.RichochetAngle) and hardness >= projectileData.Config.RichochetHardness then
		projectileData.Time = 0
		projectileData.CurrentPosition = rayResult.Position
		projectileData.Origin = rayResult.Position
		projectileData.Velocity = -(unitDirection - (2 * unitDirection:Dot(normal) * normal)).Unit * projectileData.Config.Speed 
		return false
		-- // Penetration
	--[[
		elseif rayResult ~= workspace.Terrain then
		local reverseDirection = -unitDirection * rayResult.Instance.Size.Magnitude
		local reverseOrigin = rayResult.Position - reverseDirection
		local reverseResult = workspace:Raycast(reverseOrigin, reverseDirection, RaycastParams.new()) :: RaycastResult?
		local reversePosition = reverseResult and reverseResult.Position or (reverseOrigin + reverseDirection)

		local depth = (reversePosition - rayResult.Position).Magnitude
		local strenght = (depth * hardness)

		if projectileData.Config.PenetrationPower >= strenght then
			local tempTime = projectileData.Time
			projectileData.Config.PenetrationPower -= strenght
			local reverseData = table.clone(projectileData)
			reverseData.CurrentPosition = reversePosition
			projectileData.Time = MathUtils.GetTimeAtPosition(reverseData)
			projectileData.CurrentPosition = MathUtils.GetPositionAtTime(projectileData)

			local difference = (projectileData.Time - tempTime)
			projectileData.Time = math.min(projectileData.Time + difference, projectileData.Config.Lifetime or 5)
		else
			return true
		end
	]]
	end

	projectileData.Config.OnImpact:Fire(rayResult, projectileData)

	return true
end

-- End --
return Caster :: Caster
