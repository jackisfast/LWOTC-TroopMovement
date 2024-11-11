class X2LWActivityCreation_Reinforce_Override extends X2LWActivityCreation_Reinforce config(LWActivities);

var config float VIGILANCE_WEIGHT;
var config float ALERT_WEIGHT;
var config float FORCE_LEVEL_WEIGHT;
var config float MIN_SCORE_THRESHOLD;

function XComGameState_WorldRegion FindBestReinforceDestRegion(XComGameState NewGameState)
{
    local XComGameStateHistory History;
    local StateObjectReference DestRegionRef;
    local XComGameState_WorldRegion DestRegionState, BestDestRegionState;
    local XComGameState_WorldRegion_LWStrategyAI DestRegionalAI;
    local float BestScore, CurrentScore;
    local array<XComGameState_WorldRegion> PotentialPath;
    local int DesiredAlertLevel;

    History = `XCOMHISTORY;

    // Initialize best score to a very low number
    BestScore = -9999;

    foreach PrimaryRegions(DestRegionRef)
    {
        DestRegionState = XComGameState_WorldRegion(History.GetGameStateForObjectID(DestRegionRef.ObjectID));
        DestRegionalAI = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(DestRegionState, NewGameState);
        
        if (DestRegionalAI == none)
        {
            `LOG("Reinforce Region ERROR : No Regional AI " $ DestRegionState.GetMyTemplate().DisplayName,, 'TroopMovement');
            continue;
        }

        // Skip if max alert or liberated
        if (DestRegionalAI.LocalAlertLevel >= default.MAX_ALERT_FOR_REINFORCE || DestRegionalAI.bLiberated)
        {
            continue;
        }

        // Get the desired alert level (keeping original logic)
        DesiredAlertLevel = GetDesiredAlertLevel(DestRegionState);

        // Calculate base score using multiple factors
        CurrentScore = CalculateRegionScore(
            DestRegionState, 
            DestRegionalAI, 
            DesiredAlertLevel, 
            NewGameState
        );

        // Check if there's a viable path for reinforcements
        PotentialPath = class'LWReinforceActivity_Override'.static.GetPathToHighVigilance(
            DestRegionState, 
            NewGameState
        );

        // Bonus score if we have a valid path
        if(PotentialPath.Length > 0)
        {
            CurrentScore += CalculatePathScore(PotentialPath, NewGameState);
            `LOG("Found viable path for " $ DestRegionState.GetMyTemplate().DisplayName $ " with score " $ CurrentScore,, 'TroopMovement');
        }

        // Update best region if this is the best score so far
        if(CurrentScore > BestScore && CurrentScore > default.MIN_SCORE_THRESHOLD)
        {
            BestScore = CurrentScore;
            BestDestRegionState = DestRegionState;
            `LOG("New best destination: " $ DestRegionState.GetMyTemplate().DisplayName $ " with score " $ CurrentScore,, 'TroopMovement');
        }
    }

    return BestDestRegionState;
}

// Calculate a score for a region based on multiple factors
function float CalculateRegionScore(
    XComGameState_WorldRegion RegionState,
    XComGameState_WorldRegion_LWStrategyAI RegionalAI,
    int DesiredAlertLevel,
    XComGameState NewGameState)
{
    local float Score;
    local float AlertNeed, VigilanceScore, ForceNeed;

    // Calculate how much the region needs reinforcement
    AlertNeed = DesiredAlertLevel - RegionalAI.LocalAlertLevel;
    VigilanceScore = RegionalAI.LocalVigilanceLevel;
    ForceNeed = RegionalAI.LocalVigilanceLevel - RegionalAI.LocalForceLevel;

    // Weight the different factors
    Score = (AlertNeed * default.ALERT_WEIGHT) + 
            (VigilanceScore * default.VIGILANCE_WEIGHT) + 
            (ForceNeed * default.FORCE_LEVEL_WEIGHT);

    `LOG("Region Score for " $ RegionState.GetMyTemplate().DisplayName $ 
         ": Alert=" $ AlertNeed $ 
         " Vigilance=" $ VigilanceScore $ 
         " Force Need=" $ ForceNeed $ 
         " Total=" $ Score,, 'TroopMovement');

    return Score;
}

// Calculate additional score based on the path
function float CalculatePathScore(array<XComGameState_WorldRegion> Path, XComGameState NewGameState)
{
    local float PathScore;
    local int i;
    local XComGameState_WorldRegion_LWStrategyAI RegionalAI;

    // Shorter paths are better
    PathScore = 10.0 - (Path.Length * 0.5);  // Penalty for longer paths

    // Check force levels along the path
    for(i = 0; i < Path.Length; i++)
    {
        RegionalAI = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(Path[i], NewGameState);
        if(RegionalAI != none)
        {
            // Bonus for paths through regions with excess force
            if(RegionalAI.LocalForceLevel > 2)
            {
                PathScore += 2.0;
            }
        }
    }

    return PathScore;
}

defaultproperties
{
    VIGILANCE_WEIGHT=1.5
    ALERT_WEIGHT=1.0
    FORCE_LEVEL_WEIGHT=1.0
    MIN_SCORE_THRESHOLD=0.0
}