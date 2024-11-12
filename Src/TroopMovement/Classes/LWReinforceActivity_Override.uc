class LWReinforceActivity_Override extends X2LWAlienActivityTemplate config(LWActivities);

// Core configuration variables
var XCom2WorldMap WorldMap;
var config int REINFORCE_DIFFERENCE_REQ_FOR_FORCELEVEL_TRANSFER;
var config float DEFAULT_VIGILANCE_THRESHOLD;
var config int MAX_PATH_HOPS;
var config int MIN_FORCE_LEVEL;
var config int CACHE_TIMEOUT_HOURS;

// Cache for pathfinding optimization
struct PathCacheEntry
{
    var array<XComGameState_WorldRegion> Path;
    var float BestVigilanceScore;
    var float TimeStamp;
};
var private map<name, PathCacheEntry> PathCache;

static function X2DataTemplate CreateReinforceTemplate()
{
    local X2LWAlienActivityTemplate Template;
    local X2LWActivityCondition_Month MonthRestriction;

    `CREATE_X2TEMPLATE(class'X2LWAlienActivityTemplate', Template, 'Activity_Reinforce');
    Template.iPriority = 50;

    // One per region that ADVENT controls
    Template.ActivityCreation = new class'X2LWActivityCreation_Reinforce';
    Template.ActivityCreation.Conditions.AddItem(default.SingleActivityInRegion);
    Template.ActivityCreation.Conditions.AddItem(default.AnyAlienRegion);

    //Not in first month 
    MonthRestriction = new class'X2LWActivityCondition_Month';
    MonthRestriction.FirstMonthPossible = 1;
    Template.ActivityCreation.Conditions.AddItem(MonthRestriction);

    Template.DetectionCalc = new class'X2LWActivityDetectionCalc';

    Template.OnMissionSuccessFn = TypicalEndActivityOnMissionSuccess;
    Template.OnMissionFailureFn = TypicalAdvanceActivityOnMissionFailure;
    Template.GetMissionForceLevelFn = GetTypicalMissionForceLevel;
    Template.GetMissionAlertLevelFn = GetReinforceAlertLevel;
    Template.GetMissionRewardsFn = GetReinforceRewards;
    Template.OnActivityCompletedFn = OnReinforceActivityComplete;

    return Template;
}

// Validates configuration values on initialization
static function ValidateConfig()
{
    if (default.MAX_PATH_HOPS <= 0)
    {
        `LOG("WARNING: Invalid MAX_PATH_HOPS value, defaulting to 3",, 'TroopMovement');
        default.MAX_PATH_HOPS = 3;
    }

    if (default.MIN_FORCE_LEVEL < 1)
    {
        `LOG("WARNING: Invalid MIN_FORCE_LEVEL value, defaulting to 2",, 'TroopMovement');
        default.MIN_FORCE_LEVEL = 2;
    }

    if (default.REINFORCE_DIFFERENCE_REQ_FOR_FORCELEVEL_TRANSFER < 1)
    {
        `LOG("WARNING: Invalid REINFORCE_DIFFERENCE_REQ_FOR_FORCELEVEL_TRANSFER value, defaulting to 2",, 'TroopMovement');
        default.REINFORCE_DIFFERENCE_REQ_FOR_FORCELEVEL_TRANSFER = 2;
    }

    if (default.DEFAULT_VIGILANCE_THRESHOLD <= 0)
    {
        `LOG("WARNING: Invalid DEFAULT_VIGILANCE_THRESHOLD value, defaulting to 5.0",, 'TroopMovement');
        default.DEFAULT_VIGILANCE_THRESHOLD = 5.0;
    }

    if (default.CACHE_TIMEOUT_HOURS <= 0)
    {
        `LOG("WARNING: Invalid CACHE_TIMEOUT_HOURS value, defaulting to 24",, 'TroopMovement');
        default.CACHE_TIMEOUT_HOURS = 24;
    }
}

// Checks if a cached path is still valid
static function bool IsCacheValid(PathCacheEntry CacheEntry)
{
    local float CurrentTime;
    
    if(CacheEntry.Path.Length == 0)
    {
        return false;
    }
    
    CurrentTime = class'XComGameState_GeoscapeEntity'.static.GetCurrentTime();
    return (CurrentTime - CacheEntry.TimeStamp) < (default.CACHE_TIMEOUT_HOURS * 3600);
}

static function array<XComGameState_WorldRegion> GetPathToHighVigilance(
    XComGameState_WorldRegion StartRegion,
    XComGameState NewGameState)
{
    local array<XComGameState_WorldRegion> Path, OpenList, ClosedList;
    local XComGameState_WorldRegion CurrentRegion, Neighbor;
    local map<XComGameState_WorldRegion, XComGameState_WorldRegion> ParentMap;
    local XComGameState_WorldRegion_LWStrategyAI RegionalAI;
    local array<name> ValidNeighbors;
    local float BestVigilanceScore;
    local name CurrentRegionName;
    local int CurrentHops;
    local map<XComGameState_WorldRegion, int> HopMap;
    local PathCacheEntry CacheEntry;
    
    // Early exit checks
    if(StartRegion == none || NewGameState == none)
    {
        `LOG("GetPathToHighVigilance: Invalid parameters",, 'TroopMovement');
        return Path;
    }

    // Check cache first
    CurrentRegionName = StartRegion.GetMyTemplateName();
    if(default.PathCache.Get(CurrentRegionName, CacheEntry))
    {
        if(IsCacheValid(CacheEntry))
        {
            `LOG("Using cached path for region:" @ CurrentRegionName,, 'TroopMovement');
            return CacheEntry.Path;
        }
        else
        {
            `LOG("Cache expired for region:" @ CurrentRegionName,, 'TroopMovement');
            default.PathCache.Remove(CurrentRegionName);
        }
    }

    // Initialize the world map if needed
    if(!class'XCom2WorldMap'.static.IsInitialized())
    {
        class'XCom2WorldMap'.static.InitializeWorldMap();
    }

    // Initialize search
    OpenList.AddItem(StartRegion);
    ParentMap.Set(StartRegion, none);
    HopMap.Set(StartRegion, 0);
    BestVigilanceScore = -1;

    `LOG("Starting pathfinding from:" @ StartRegion.GetMyTemplateName(),, 'TroopMovement');
    
    //Pathfinding loop
    while(OpenList.Length > 0)
    {
        CurrentRegion = OpenList[0];
        OpenList.Remove(0, 1); 
        HopMap.Get(CurrentRegion, CurrentHops);

        RegionalAI = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(CurrentRegion, NewGameState);
        if(RegionalAI != none)
        {
            `LOG("Checking region:" @ CurrentRegion.GetMyTemplateName() @ 
                "Vigilance:" @ RegionalAI.LocalVigilanceLevel @ 
                "Hops:" @ CurrentHops,, 'TroopMovement');

            // Update best path if this region has higher vigilance
            if(RegionalAI.LocalVigilanceLevel > BestVigilanceScore)
            {
                BestVigilanceScore = RegionalAI.LocalVigilanceLevel;
                // Clear and reconstruct path
                Path.Length = 0;
                Neighbor = CurrentRegion;
                while(Neighbor != none)
                {
                    Path.InsertItem(0, Neighbor);
                    Neighbor = ParentMap.Find(Neighbor);
                }
                `LOG("New best path found with vigilance:" @ BestVigilanceScore,, 'TroopMovement');
            }
        }

        // Stop exploring after max hops
        if(CurrentHops >= default.MAX_PATH_HOPS)
        {
            continue;
        }

        ClosedList.AddItem(CurrentRegion);
        CurrentRegionName = CurrentRegion.GetMyTemplateName();
        ValidNeighbors = class'XCom2WorldMap'.static.GetValidConnections(CurrentRegionName);

        foreach CurrentRegion.GetLinkedRegions() as Neighbor
        {
            // Skip if invalid connection or already processed
            if(ValidNeighbors.Find(Neighbor.GetMyTemplateName()) == INDEX_NONE ||
               ClosedList.Contains(Neighbor) || 
               OpenList.Contains(Neighbor))
            {
                continue;
            }

            OpenList.AddItem(Neighbor);
            ParentMap.Set(Neighbor, CurrentRegion);
            HopMap.Set(Neighbor, CurrentHops + 1);

            `LOG("Added neighbor:" @ Neighbor.GetMyTemplateName() @ 
                "at hop:" @ (CurrentHops + 1),, 'TroopMovement');
        }
    }

    // Cache the result
    CacheEntry.Path = Path;
    CacheEntry.BestVigilanceScore = BestVigilanceScore;
    CacheEntry.TimeStamp = class'XComGameState_GeoscapeEntity'.static.GetCurrentTime();
    default.PathCache.Set(StartRegion.GetMyTemplateName(), CacheEntry);

    // Clean up
    ParentMap.Clear();
    HopMap.Clear();
    OpenList.Length = 0;
    ClosedList.Length = 0;
    ValidNeighbors.Length = 0;

    return Path;
}

static function UpdateRegionalStrength(
    array<XComGameState_WorldRegion> Path,
    XComGameState NewGameState)
{
    local XComGameState_WorldRegion CurrentRegion;
    local XComGameState_WorldRegion_LWStrategyAI CurrentAI, NextAI, TargetAI;
    local int i, j;
    local float BestNeed, CurrentNeed;
    local bool bFoundTransfer;

    // Input validation
    if(NewGameState == none)
    {
        `LOG("UpdateRegionalStrength: NewGameState is none",, 'TroopMovement');
        return;
    }

    if(Path.Length < 2)
    {
        `LOG("UpdateRegionalStrength: Path too short for force movement",, 'TroopMovement');
        return;
    }

    // Process each potential source region
    for(i = 0; i < Path.Length - 1; i++)
    {
        CurrentRegion = Path[i];
        CurrentAI = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(CurrentRegion, NewGameState, true);
        NextAI = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(Path[i + 1], NewGameState, true);

        // Safety check for minimum force level
        if(CurrentAI.LocalForceLevel <= Min(CurrentAI.LocalVigilanceLevel, default.MIN_FORCE_LEVEL))
        {
            `LOG("Region" @ CurrentRegion.GetMyTemplateName() @ "force level too low to transfer",, 'TroopMovement');
            continue;
        }

        // Look ahead for highest need
        BestNeed = default.REINFORCE_DIFFERENCE_REQ_FOR_FORCELEVEL_TRANSFER;
        bFoundTransfer = false;

        // Scan forward for priority target
        for(j = i + 1; j < Path.Length; j++)
        {
            TargetAI = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(Path[j], NewGameState, true);
            CurrentNeed = TargetAI.LocalVigilanceLevel - TargetAI.LocalForceLevel;

            if(CurrentNeed > BestNeed)
            {
                BestNeed = CurrentNeed;
                bFoundTransfer = true;
            }
        }

        // Execute force transfer if needed only one region at a time
        if(bFoundTransfer)
        {
            `LOG("Moving force from" @ CurrentRegion.GetMyTemplateName() @ 
                "to" @ Path[i + 1].GetMyTemplateName() @ 
                "toward high-need target with priority" @ BestNeed,, 'TroopMovement');
            
            CurrentAI.LocalForceLevel -= 1;
            NextAI.LocalForceLevel += 1;
        }
    }
}

//Used to determine difficult for interception missions
static function int GetReinforceAlertLevel(
    XComGameState_LWAlienActivity ActivityState, 
    XComGameState_MissionSite MissionSite, 
    XComGameState NewGameState)
{
    local XComGameState_WorldRegion OriginRegionState, DestinationRegionState;
    local XComGameState_WorldRegion_LWStrategyAI OriginAIState, DestinationAIState;

    OriginRegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.SecondaryRegions[0].ObjectID));
    if(OriginRegionState == none)
        OriginRegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.SecondaryRegions[0].ObjectID));

    DestinationRegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
    if(DestinationRegionState == none)
        DestinationRegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));

    OriginAIState = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(OriginRegionState, NewGameState);
    DestinationAIState = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(DestinationRegionState, NewGameState);

    return Max(OriginAIState.LocalAlertLevel, DestinationAIState.LocalAlertLevel) + ActivityState.GetMyTemplate().AlertLevelModifier;
}

static function array<name> GetReinforceRewards(
    XComGameState_LWAlienActivity ActivityState, 
    name MissionFamily, 
    XComGameState NewGameState)
{
    local array<name> Rewards;
    Rewards[0] = 'Reward_Dummy_Materiel';
    return Rewards;
}

static function OnReinforceActivityComplete(
    bool bAlienSuccess, 
    XComGameState_LWAlienActivity ActivityState, 
    XComGameState NewGameState)
{
    local XComGameState_WorldRegion DestRegionState, OrigRegionState;
    local XComGameState_WorldRegion_LWStrategyAI DestRegionalAI, OrigRegionalAI;
    local array<XComGameState_WorldRegion> Path;

    DestRegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
    if(DestRegionState == none)
        DestRegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));

    OrigRegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.SecondaryRegions[0].ObjectID));
    if(OrigRegionState == none)
        OrigRegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.SecondaryRegions[0].ObjectID));

    DestRegionalAI = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(DestRegionState, NewGameState, true);
    OrigRegionalAI = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(OrigRegionState, NewGameState, true);

    if(bAlienSuccess)
    {
        `LOG("ReinforceRegion: Alien Success, processing reinforcements",, 'TroopMovement');

        // Handle alert level changes
        if (OrigRegionalAI.LocalAlertLevel > 1)
        {
            DestRegionalAI.LocalAlertLevel += 1;
            OrigRegionalAI.LocalAlertLevel -= 1;
        }

        // Clear cache for affected regions
        default.PathCache.Remove(DestRegionState.GetMyTemplateName());
        default.PathCache.Remove(OrigRegionState.GetMyTemplateName());

        // Find and process path to high vigilance
        Path = GetPathToHighVigilance(DestRegionState, NewGameState);
        if(Path.Length > 0)
        {
            UpdateRegionalStrength(Path, NewGameState);
        }
        else
        {
            // Fallback to original behavior if no path found
            if(DestRegionalAI.LocalVigilanceLevel - DestRegionalAI.LocalAlertLevel > default.REINFORCE_DIFFERENCE_REQ_FOR_FORCELEVEL_TRANSFER)
            {
                if(OrigRegionalAI.LocalForceLevel > default.MIN_FORCE_LEVEL)
                {
                    DestRegionalAI.LocalForceLevel += 1;
                    OrigRegionalAI.LocalForceLevel -= 1;
                }
            }
        }
    }
    else
    {
        `LOG("ReinforceRegion: XCOM Success",, 'TroopMovement');
        OrigRegionalAI.LocalAlertLevel = Max(OrigRegionalAI.LocalAlertLevel - 1, 1);
        OrigRegionalAI.AddVigilance(NewGameState, default.REINFORCEMENTS_STOPPED_ORIGIN_VIGILANCE_INCREASE);
        AddVigilanceNearby(NewGameState, DestRegionState, 
            default.REINFORCEMENTS_STOPPED_ADJACENT_VIGILANCE_BASE,
            default.REINFORCEMENTS_STOPPED_ADJACENT_VIGILANCE_RAND);
            
        // Clear cache for affected regions since vigilance levels changed
        default.PathCache.Remove(DestRegionState.GetMyTemplateName());
        default.PathCache.Remove(OrigRegionState.GetMyTemplateName());
    }
}

defaultproperties
{
    REINFORCE_DIFFERENCE_REQ_FOR_FORCELEVEL_TRANSFER=2
    DEFAULT_VIGILANCE_THRESHOLD=5.0
    MAX_PATH_HOPS=3
    MIN_FORCE_LEVEL=2
    CACHE_TIMEOUT_HOURS=24
}