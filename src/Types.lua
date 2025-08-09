local FastSignal = require(script.Parent.FastSignal)

export type CastConfig = {
    Speed: number,
    ExtraForce: Vector3,
    RayParams: RaycastParams,
    Lifetime: number?,
	
	RichochetAngle: number?, --> UNUSED TEMPORARILY
    RichochetHardness: number?, --> UNUSED TEMPORARILY
	PenetrationPower: number?, --> UNUSED TEMPORARILY
	
    OnImpact: FastSignal.ScriptSignal<RaycastResult, ProjectileData>,
}

export type ProjectileData = {
    Config: CastConfig,
    Origin: Vector3,
    Direction: Vector3,
    CurrentPosition: Vector3,
    CurrentDirection: Vector3,
    Velocity: Vector3,
    Time: number,
    Bullet: BasePart?,
}

local Types = {}
return Types
