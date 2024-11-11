class LWReinforceActivity_Override extends X2LWAlienActivityTemplate config(LWActivities);

var XCom2WorldMap WorldMap;
var config int REINFORCE_DIFFERENCE_REQ_FOR_FORCELEVEL_TRANSFER;
var config float DEFAULT_VIGILANCE_THRESHOLD;

static function X2DataTemplate CreateReinforceTemplate()
{
    local X2LWAlienActivityTemplate Template;
    local X2LWActivityCondition_Month MonthRestriction;

    `CREATE_X2TEMPLATE(class'X2LWAlienActivityTemplate', Template, 'Activity_Reinforce');
    Template.iPriority = 50;

    Template.ActivityCreation = new class'X2LWActivityCreation_Reinforce';
    Template.ActivityCreation.Conditions.AddItem(default.SingleActivityInRegion);
    Template.ActivityCreation.Conditions.AddItem(default.AnyAlienRegion);

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
    
    if(StartRegion == none || NewGameState == none)
    {
        `LOG("GetPathToHighVigilance: Invalid parameters",, 'TroopMovement');
        return Path;
    }

    // Initialize the world map
    class'XCom2WorldMap'.static.InitializeWorldMap();

    OpenList.AddItem(StartRegion);
    ParentMap.Set(StartRegion, none);
    HopMap.Set(StartRegion, 0);
    BestVigilanceScore = -1;

    `LOG("Starting pathfinding from:" @ StartRegion.GetMyTemplateName(),, 'TroopMovement');

    while(OpenList.Length > 0)
    {
        CurrentRegion = OpenList[0];
        OpenList.Remove(0);
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
                // Reconstruct path
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

        // Stop exploring after 3 hops
        if(CurrentHops >= 3)
        {
            continue;
        }

        ClosedList.AddItem(CurrentRegion);
        CurrentRegionName = CurrentRegion.GetMyTemplateName();
        ValidNeighbors = class'XCom2WorldMap'.static.GetValidConnections(CurrentRegionName);

        foreach CurrentRegion.GetLinkedRegions() as Neighbor
        {
            // Skip if this isn't a valid connection or already processed
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

    return Path;
}

static function UpdateRegionalStrength(
    array<XComGameState_WorldRegion> Path,
    XComGameState NewGameState)
{
    local XComGameState_WorldRegion CurrentRegion;
    local XComGameState_WorldRegion_LWStrategyAI CurrentAI, NextAI;
    local int i;

    for(i = 0; i < Path.Length - 1; i++)
    {
        CurrentRegion = Path[i];
        CurrentAI = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(CurrentRegion, NewGameState, true);
        NextAI = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(Path[i + 1], NewGameState, true);

        if(CurrentAI.LocalForceLevel > 2 && 
           NextAI.LocalVigilanceLevel - NextAI.LocalForceLevel > default.REINFORCE_DIFFERENCE_REQ_FOR_FORCELEVEL_TRANSFER)
        {
            `LOG("Moving force from" @ CurrentRegion.GetMyTemplateName() @ 
                "to" @ Path[i + 1].GetMyTemplateName(),, 'TroopMovement');
            CurrentAI.LocalForceLevel -= 1;
            NextAI.LocalForceLevel += 1;
        }
    }
}

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
                if(OrigRegionalAI.LocalForceLevel > 2)
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
    }
}

defaultproperties
{
    REINFORCE_DIFFERENCE_REQ_FOR_FORCELEVEL_TRANSFER=2
    DEFAULT_VIGILANCE_THRESHOLD=5.0
}