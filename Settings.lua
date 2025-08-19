return {
    SurfaceHardness = {
        Default = 10,
        [Enum.Material.Plastic] = 10
    }, --> this is here just for the future for richochet and penetration

    Visualise = true, --> basically debug
	SafeMode = true, --> if to let the server handle the bullet replication or not
	ParallelProcessing = false, --> if should use multiple threads or not
	
	LoadBalanceStrategy = "LeastLoadedActor", --> "RoundBin", "LeastLoadedActor"
	UpdateRate = 30, --> 30hz as default
	ActorAmount = 12,
}
