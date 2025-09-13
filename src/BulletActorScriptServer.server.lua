--!strict
--!optimize 2

if not script:GetActor() and script.Parent ~= nil then
	return
else
	repeat
		task.wait()
	until script:GetActor()
end

local actor = script:GetActor()
local communicationFolder = actor.Parent:WaitForChild("ActorComm")
local bulletUpdateEvent = communicationFolder:WaitForChild("BulletUpdate") :: BindableEvent
local bulletHitEvent = communicationFolder:WaitForChild("BulletHit") :: BindableEvent

local activeBullets: { [string]: any } = {}
local lastHeartbeat = os.clock()

local function getPositionAtTime(data: any): Vector3
	local t = data.time
	local gravity = data.extraForce
	local initialVelocity = data.velocity
	return initialVelocity * t + 0.5 * gravity * t * t
end

actor:BindToMessageParallel("CastBullet", function(data)
	activeBullets[data.bulletId] = {
		bulletId = data.bulletId,
		origin = data.origin,
		direction = data.direction,
		time = data.time or 0,
		currentPosition = data.currentPosition or data.origin,
		velocity = data.velocity or ((data :: any).direction * data.speed),
		speed = data.speed,
		extraForce = data.extraForce,
		lifetime = data.lifetime,
		rayParams = data.rayParams,
	}
end)

actor:BindToMessageParallel("Heartbeat", function(data)
	local currentTime = os.clock()
	local timeSinceUpdate = currentTime - lastHeartbeat

	if timeSinceUpdate < data.updateInterval then
		return
	end

	for bulletId, bulletData in activeBullets do
		local displacement = getPositionAtTime(bulletData)
		local projectilePosition = bulletData.currentPosition + displacement

		local velocity = bulletData.velocity + bulletData.extraForce * bulletData.time
		local lookVector = velocity.Magnitude > 0 and velocity.Unit or Vector3.new(0, 0, -1)

		local rayResult = workspace:Raycast(
			bulletData.currentPosition,
			projectilePosition - bulletData.currentPosition,
			bulletData.rayParams
		)

		local destroy = false
		local cframe = CFrame.new(projectilePosition, projectilePosition + lookVector)

		if rayResult then
			destroy = true
			bulletHitEvent:Fire({
				bulletId = bulletId,
				rayResult = rayResult,
			})
		end

		if bulletData.time > bulletData.lifetime then
			destroy = true
		end

		if destroy then
			activeBullets[bulletId] = nil
		else
			bulletData.time += data.deltaTime
			bulletData.currentPosition = projectilePosition
		end

		bulletUpdateEvent:Fire({
			bulletId = bulletId,
			position = projectilePosition,
			cframe = cframe,
			time = bulletData.time,
			destroy = destroy,
		})
	end

	lastHeartbeat = currentTime
end)

actor:BindToMessageParallel("Cleanup", function()
	activeBullets = {}
end)
