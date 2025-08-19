local Types = require(script.Parent.Types)
type ProjectileData = Types.ProjectileData

local Math = { }

---Square roots a vector
---@param vector Vector3 the vector you want to square root
function Math.VectorSquareRoot(vector: Vector3): Vector3
	return Vector3.new(math.sqrt(vector.X), math.sqrt(vector.Y), math.sqrt(vector.Z))
end

--- Returns the new porjectile position based on time
--- @param projectileData ProjectileData
--- @return Vector3
function Math.GetPositionAtTime(projectileData: ProjectileData): Vector3
	return Vector3.new(
		projectileData.Velocity.X * projectileData.Time + 0.5 * projectileData.Config.ExtraForce.X * projectileData.Time * projectileData.Time,
		projectileData.Velocity.Y * projectileData.Time + 0.5 * projectileData.Config.ExtraForce.Y * projectileData.Time * projectileData.Time,
		projectileData.Velocity.Z * projectileData.Time + 0.5 * projectileData.Config.ExtraForce.Z * projectileData.Time * projectileData.Time
	)
end

return Math