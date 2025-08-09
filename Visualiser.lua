local Visualiser = { }

function Visualiser.VisualiseSegment(startCFrame: CFrame, lenght: number): ConeHandleAdornment
    local adornment = Instance.new("ConeHandleAdornment")

	adornment.Adornee = workspace.Terrain
	adornment.CFrame = startCFrame
	adornment.Height = lenght
	adornment.Color3 = Color3.new()
	adornment.Radius = 0.25
	adornment.Transparency = 0.5
	adornment.Parent = workspace

    return adornment
end

function Visualiser.VisualiseHit(hit: CFrame): SphereHandleAdornment?
	local adornment = Instance.new("SphereHandleAdornment")

	adornment.Adornee = workspace.Terrain
	adornment.CFrame = hit
	adornment.Radius = 0.4
	adornment.Transparency = 0.25
	adornment.Color3 = Color3.new(0.2, 1, 0.5)
	adornment.Parent = workspace
    
	return adornment
end

return Visualiser