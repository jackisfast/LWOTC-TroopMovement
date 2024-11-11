/// LWReinforceActivity_Override handles alien reinforcement activities,
/// implementing intelligent pathfinding for troop movements based on vigilance levels
/// and region connectivity.
/// </summary>
class LWReinforceActivity_Override extends X2LWAlienActivityTemplate config(LWActivities);

// Config variables
var config int REINFORCE_DIFFERENCE_REQ_FOR_FORCELEVEL_TRANSFER;
var config float DEFAULT_VIGILANCE_THRESHOLD;
var config int MAX_PATH_HOPS;
var config int MIN_FORCE_LEVEL;

static function array<X2DataTemplate> CreateTemplates()
{
    local array<X2DataTemplate> Templates;

    Templates.AddItem(CreateReinforceTemplate());
    return Templates;
}

static function X2DataTemplate CreateReinforceTemplate()
{
    local X2LWAlienActivityTemplate Template;
    local X2LWActivityCondition_Month MonthRestriction;

    `CREATE_X2TEMPLATE(class'X2LWAlienActivityTemplate', Template, 'Activity_Reinforce');
    
    // Set up basic template properties
    Template.iPriority = 50;
    Template.ActivityCreation = new class'X2LWActivityCreation_Reinforce';
    Template.DetectionCalc = new class'X2LWActivityDetectionCalc';

    // Add activity conditions
    Template.ActivityCreation.Conditions.AddItem(default.SingleActivityInRegion);
    Template.ActivityCreation.Conditions.AddItem(default.AnyAlienRegion);

    // Set up month restriction
    MonthRestriction = new class'X2LWActivityCondition_Month';
    MonthRestriction.FirstMonthPossible = 1;
    Template.ActivityCreation.Conditions.AddItem(MonthRestriction);

    // Assign callback functions
    Template.OnMissionSuccessFn = TypicalEndActivityOnMissionSuccess;
    Template.OnMissionFailureFn = TypicalAdvanceActivityOnMissionFailure;
    Template.GetMissionForceLevelFn = GetTypicalMissionForceLevel;
    Template.GetMissionAlertLevelFn = GetReinforceAlertLevel;
    Template.GetMissionRewardsFn = GetReinforceRewards;
    Template.OnActivityCompletedFn = OnReinforceActivityComplete;

    return Template;
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
    
    // Validate parameters
    if(StartRegion == none || NewGameState == none)
    {
        `LOG("GetPathToHighVigilance: Invalid parameters",, 'TroopMovement');
        return Path;
    }

    // Ensure world map is initialized
    if (!class'XCom2WorldMap'.static.IsInitialized())
    {
        class'XCom2WorldMap'.static.InitializeWorldMap();
    }

    `LOG("Starting pathfinding from:" @ StartRegion.GetMyTemplateName(),, 'TroopMovement');

    // Initialize search
    OpenList.AddItem(StartRegion);
    ParentMap.Set(StartRegion, none);
    HopMap.Set(StartRegion, 0);
    BestVigilanceScore = -1;

    while(OpenList.Length > 0)
    {
        CurrentRegion = OpenList[0];
        OpenList.Remove(0);
        HopMap.Get(CurrentRegion, CurrentHops);

        // Check current region's vigilance
        RegionalAI = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(CurrentRegion, NewGameState);
        if(RegionalAI != none)
        {
            `LOG("Checking region:" @ CurrentRegion.GetMyTemplateName() @ 
                "Vigilance:" @ RegionalAI.LocalVigilanceLevel @ 
                "Hops:" @ CurrentHops,, 'TroopMovement');

            // Update best path if better vigilance found
            if(RegionalAI.LocalVigilanceLevel > BestVigilanceScore)
            {
                BestVigilanceScore = RegionalAI.LocalVigilanceLevel;
                Path = ReconstructPath(CurrentRegion, ParentMap);
                `LOG("New best path found with vigilance:" @ BestVigilanceScore,, 'TroopMovement');
            }
        }

        // Stop if we've reached max hops
        if(CurrentHops >= default.MAX_PATH_HOPS)
        {
            continue;
        }

        // Process neighbors
        ClosedList.AddItem(CurrentRegion);
        CurrentRegionName = CurrentRegion.GetMyTemplateName();
        ValidNeighbors = class'XCom2WorldMap'.static.GetValidConnections(CurrentRegionName);

        foreach CurrentRegion.GetLinkedRegions() as Neighbor
        {
            if(ShouldProcessNeighbor(Neighbor, ValidNeighbors, ClosedList, OpenList))
            {
                OpenList.AddItem(Neighbor);
                ParentMap.Set(Neighbor, CurrentRegion);
                HopMap.Set(Neighbor, CurrentHops + 1);

                `LOG("Added neighbor:" @ Neighbor.GetMyTemplateName() @ 
                    "at hop:" @ (CurrentHops + 1),, 'TroopMovement');
            }
        }
    }

    if(Path.Length == 0)
    {
        `LOG("No valid path found from" @ StartRegion.GetMyTemplateName(),, 'TroopMovement');
    }

    return Path;
}

private static function bool ShouldProcessNeighbor(
    XComGameState_WorldRegion Neighbor,
    array<name> ValidNeighbors,
    array<XComGameState_WorldRegion> ClosedList,
    array<XComGameState_WorldRegion> OpenList)
{
    return ValidNeighbors.Find(Neighbor.GetMyTemplateName()) != INDEX_NONE && 
           !ClosedList.Contains(Neighbor) && 
           !OpenList.Contains(Neighbor);
}

private static function array<XComGameState_WorldRegion> ReconstructPath(
    XComGameState_WorldRegion EndRegion,
    map<XComGameState_WorldRegion, XComGameState_WorldRegion> ParentMap)
{
    local array<XComGameState_WorldRegion> Path;
    local XComGameState_WorldRegion CurrentRegion;
    
    CurrentRegion = EndRegion;
    while(CurrentRegion != none)
    {
        Path.InsertItem(0, CurrentRegion);
        CurrentRegion = ParentMap.Find(CurrentRegion);
    }
    
    return Path;
}

static function UpdateRegionalStrength(
    array<XComGameState_WorldRegion> Path,
    XComGameState NewGameState)
{
    local XComGameState_WorldRegion CurrentRegion;
    local XComGameState_WorldRegion_LWStrategyAI CurrentAI, NextAI;
    local int i;

    if(Path.Length < 2)
    {
        `LOG("UpdateRegionalStrength: Path too short for strength updates",, 'TroopMovement');
        return;
    }

    `LOG("UpdateRegionalStrength: Processing path of length" @ Path.Length,, 'TroopMovement');

    for(i = 0; i < Path.Length - 1; i++)
    {
        CurrentRegion = Path[i];
        CurrentAI = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(CurrentRegion, NewGameState, true);
        NextAI = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(Path[i + 1], NewGameState, true);

        if(ShouldTransferForce(CurrentAI, NextAI))
        {
            TransferForce(CurrentAI, NextAI, CurrentRegion, Path[i + 1]);
        }
    }
}

private static function bool ShouldTransferForce(
    XComGameState_WorldRegion_LWStrategyAI CurrentAI,
    XComGameState_WorldRegion_LWStrategyAI NextAI)
{
    return CurrentAI.LocalForceLevel > default.MIN_FORCE_LEVEL && 
           NextAI.LocalVigilanceLevel - NextAI.LocalForceLevel > default.REINFORCE_DIFFERENCE_REQ_FOR_FORCELEVEL_TRANSFER;
}

private static function TransferForce(
    XComGameState_WorldRegion_LWStrategyAI FromAI,
    XComGameState_WorldRegion_LWStrategyAI ToAI,
    XComGameState_WorldRegion FromRegion,
    XComGameState_WorldRegion ToRegion)
{
    FromAI.LocalForceLevel -= 1;
    ToAI.LocalForceLevel += 1;
    
    `LOG("Transferred force from" @ FromRegion.GetMyTemplateName() @ 
        "(new force:" @ FromAI.LocalForceLevel @ ")" @
        "to" @ ToRegion.GetMyTemplateName() @ 
        "(new force:" @ ToAI.LocalForceLevel @ ")",, 'TroopMovement');
}

static function OnReinforceActivityComplete(
    bool bAlienSuccess, 
    XComGameState_LWAlienActivity ActivityState, 
    XComGameState NewGameState)
{
    local XComGameState_WorldRegion DestRegionState, OrigRegionState;
    local XComGameState_WorldRegion_LWStrategyAI DestRegionalAI, OrigRegionalAI;
    local array<XComGameState_WorldRegion> Path;

    if(!ValidateActivityState(ActivityState, NewGameState, DestRegionState, OrigRegionState))
    {
        return;
    }

    DestRegionalAI = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(DestRegionState, NewGameState, true);
    OrigRegionalAI = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(OrigRegionState, NewGameState, true);

    if(bAlienSuccess)
    {
        ProcessAlienSuccess(DestRegionState, DestRegionalAI, OrigRegionalAI, NewGameState);
    }
    else
    {
        ProcessXComSuccess(DestRegionState, OrigRegionalAI, NewGameState);
    }
}

private static function bool ValidateActivityState(
    XComGameState_LWAlienActivity ActivityState,
    XComGameState NewGameState,
    out XComGameState_WorldRegion DestRegionState,
    out XComGameState_WorldRegion OrigRegionState)
{
    if(ActivityState == none || NewGameState == none)
    {
        `LOG("OnReinforceActivityComplete: Invalid parameters",, 'TroopMovement');
        return false;
    }

    if(ActivityState.SecondaryRegions.Length == 0)
    {
        `LOG("OnReinforceActivityComplete: No secondary regions",, 'TroopMovement');
        return false;
    }

    DestRegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
    if(DestRegionState == none)
    {
        DestRegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
    }

    OrigRegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.SecondaryRegions[0].ObjectID));
    if(OrigRegionState == none)
    {
        OrigRegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.SecondaryRegions[0].ObjectID));
    }

    return DestRegionState != none && OrigRegionState != none;
}

private static function ProcessAlienSuccess(
    XComGameState_WorldRegion DestRegionState,
    XComGameState_WorldRegion_LWStrategyAI DestRegionalAI,
    XComGameState_WorldRegion_LWStrategyAI OrigRegionalAI,
    XComGameState NewGameState)
{
    local array<XComGameState_WorldRegion> Path;

    `LOG("ReinforceRegion: Alien Success, processing reinforcements",, 'TroopMovement');

    // Update alert levels
    if (OrigRegionalAI.LocalAlertLevel > 1)
    {
        DestRegionalAI.LocalAlertLevel += 1;
        OrigRegionalAI.LocalAlertLevel -= 1;
    }

    // Find and process reinforcement path
    Path = GetPathToHighVigilance(DestRegionState, NewGameState);
    if(Path.Length > 0)
    {
        UpdateRegionalStrength(Path, NewGameState);
    }
    else
    {
        ProcessDirectReinforcement(DestRegionalAI, OrigRegionalAI);
    }
}

private static function ProcessDirectReinforcement(
    XComGameState_WorldRegion_LWStrategyAI DestRegionalAI,
    XComGameState_WorldRegion_LWStrategyAI OrigRegionalAI)
{
    if(DestRegionalAI.LocalVigilanceLevel - DestRegionalAI.LocalAlertLevel > default.REINFORCE_DIFFERENCE_REQ_FOR_FORCELEVEL_TRANSFER)
    {
        if(OrigRegionalAI.LocalForceLevel > default.MIN_FORCE_LEVEL)
        {
            DestRegionalAI.LocalForceLevel += 1;
            OrigRegionalAI.LocalForceLevel -= 1;
        }
    }
}

private static function ProcessXComSuccess(
    XComGameState_WorldRegion DestRegionState,
    XComGameState_WorldRegion_LWStrategyAI OrigRegionalAI,
    XComGameState NewGameState)
{
    `LOG("ReinforceRegion: XCOM Success",, 'TroopMovement');
    
    OrigRegionalAI.LocalAlertLevel = Max(OrigRegionalAI.LocalAlertLevel - 1, 1);
    OrigRegionalAI.AddVigilance(NewGameState, default.REINFORCEMENTS_STOPPED_ORIGIN_VIGILANCE_INCREASE);
    
    AddVigilanceNearby(NewGameState, DestRegionState, 
        default.REINFORCEMENTS_STOPPED_ADJACENT_VIGILANCE_BASE,
        default.REINFORCEMENTS_STOPPED_ADJACENT_