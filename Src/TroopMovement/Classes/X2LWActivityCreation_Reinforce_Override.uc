class X2LWActivityCreation_Reinforce_Override extends X2LWActivityCreation_Reinforce;

function XComGameState_WorldRegion FindBestReinforceDestRegion(XComGameState NewGameState)
{
    local XComGameStateHistory History;
    local StateObjectReference DestRegionRef;
    local XComGameState_WorldRegion DestRegionState, BestDestRegionState;
    local XComGameState_WorldRegion_LWStrategyAI DestRegionalAI;
    local array<XComGameState_WorldRegion> PotentialPath;
    local float BestScore, CurrentScore;

    History = `XCOMHISTORY;

    // Initialize the world map
    class'XCom2WorldMap'.static.InitializeWorldMap();

    foreach PrimaryRegions(DestRegionRef)
    {
        DestRegionState = XComGameState_WorldRegion(History.GetGameStateForObjectID(DestRegionRef.ObjectID));
        DestRegionalAI = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(DestRegionState, NewGameState);

        if (DestRegionalAI == none || 
            DestRegionalAI.LocalAlertLevel >= default.MAX_ALERT_FOR_REINFORCE || 
            DestRegionalAI.bLiberated)
        {
            continue;
        }

        // Get potential path using our pathfinding
        PotentialPath = class'LWReinforceActivity_Override'.static.GetPathToHighVigilance(
            DestRegionState, 
            NewGameState
        );

        // Score this region based on path and other factors
        CurrentScore = CalculateRegionScore(DestRegionState, DestRegionalAI, PotentialPath);

        if(CurrentScore > BestScore)
        {
            BestScore = CurrentScore;
            BestDestRegionState = DestRegionState;
        }
    }

    return BestDestRegionState;
}

function float CalculateRegionScore(
    XComGameState_WorldRegion RegionState,
    XComGameState_WorldRegion_LWStrategyAI RegionalAI,
    array<XComGameState_WorldRegion> Path)
{
    local float Score;
    local int DesiredAlertLevel;

    DesiredAlertLevel = GetDesiredAlertLevel(RegionState);
    
    // Base score from alert level need
    Score = DesiredAlertLevel - RegionalAI.LocalAlertLevel;
    
    // Bonus if we found a valid path to high vigilance
    if(Path.Length > 0)
    {
        Score += 2.0;
        // Penalty for longer paths
        Score -= (Path.Length * 0.2);
    }

    return Score;
}