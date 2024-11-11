class LWReinforceActivity_Override extends X2LWAlienActivityTemplate config(LWActivities);

var config int REINFORCE_DIFFERENCE_REQ_FOR_FORCELEVEL_TRANSFER;
var config float DEFAULT_VIGILANCE_THRESHOLD;

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
    XComGameState NewGameState,
    optional float VigilanceThreshold = 5.0)
{
    local array<XComGameState_WorldRegion> Path, OpenList, ClosedList;
    local XComGameState_WorldRegion CurrentRegion, Neighbor;
    local map<XComGameState_WorldRegion, XComGameState_WorldRegion> ParentMap;
    local XComGameState_WorldRegion_LWStrategyAI RegionalAI;
    
    if(StartRegion == none || NewGameState == none)
    {
        `LOG("GetPathToHighVigilance: Invalid parameters",, 'LWReinforceActivity_Override');
        return Path;
    }

    OpenList.AddItem(StartRegion);
    ParentMap.Set(StartRegion, none);

    while(OpenList.Length > 0)
    {
        CurrentRegion = OpenList[0];
        OpenList.Remove(0);

        RegionalAI = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(CurrentRegion, NewGameState);
        if(RegionalAI != none && RegionalAI.LocalVigilanceLevel >= VigilanceThreshold)
        {
            while(CurrentRegion != none)
            {
                Path.InsertItem(0, CurrentRegion);
                CurrentRegion = ParentMap.Find(CurrentRegion);
            }
            `LOG("GetPathToHighVigilance: Found path of length" @ Path.Length,, 'LWReinforceActivity_Override');
            return Path;
        }

        ClosedList.AddItem(CurrentRegion);

        foreach(CurrentRegion.GetLinkedRegions() as Neighbor)
        {
            if(ClosedList.Contains(Neighbor) || OpenList.Contains(Neighbor))
                continue;

            OpenList.AddItem(Neighbor);
            ParentMap.Set(Neighbor, CurrentRegion);
        }
    }
    
    `LOG("GetPathToHighVigilance: No path found",, 'LWReinforceActivity_Override');
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
            `LOG("UpdateRegionalStrength: Moving force from" @ CurrentRegion.GetMyTemplateName() @ "to" @ Path[i + 1].GetMyTemplateName(),, 'LWReinforceActivity_Override');
            CurrentAI.LocalForceLevel -= 1;
            NextAI.LocalForceLevel += 1;
        }
    }
}

static function int GetReinforceAlertLevel(XComGameState_LWAlienActivity ActivityState, XComGameState_MissionSite MissionSite, XComGameState NewGameState)
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

static function OnReinforceActivityComplete(bool bAlienSuccess, XComGameState_LWAlienActivity ActivityState, XComGameState NewGameState)
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
        `LOG("ReinforceRegion: Alien Success, processing reinforcements",, 'LWReinforceActivity_Override');

        if (OrigRegionalAI.LocalAlertLevel > 1)
        {
            DestRegionalAI.LocalAlertLevel += 1;
            OrigRegionalAI.LocalAlertLevel -= 1;
        }

        Path = GetPathToHighVigilance(DestRegionState, NewGameState, default.DEFAULT_VIGILANCE_THRESHOLD);
        if(Path.Length > 0)
        {
            UpdateRegionalStrength(Path, NewGameState);
        }
        else
        {
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
        `LOG("ReinforceRegion: XCOM Success",, 'LWReinforceActivity_Override');
        OrigRegionalAI.LocalAlertLevel = Max(OrigRegionalAI.LocalAlertLevel - 1, 1);
        OrigRegionalAI.AddVigilance(NewGameState, default.REINFORCEMENTS_STOPPED_ORIGIN_VIGILANCE_INCREASE);
        AddVigilanceNearby(NewGameState, DestRegionState, 
            default.REINFORCEMENTS_STOPPED_ADJACENT_VIGILANCE_BASE,
            default.REINFORCEMENTS_STOPPED_ADJACENT_VIGILANCE_RAND);
    }
}

static function array<name> GetReinforceRewards(XComGameState_LWAlienActivity ActivityState, name MissionFamily, XComGameState NewGameState)
{
    local array<name> Rewards;
    Rewards[0] = 'Reward_Dummy_Materiel';
    return Rewards;
}

defaultproperties
{
    REINFORCE_DIFFERENCE_REQ_FOR_FORCELEVEL_TRANSFER=2
    DEFAULT_VIGILANCE_THRESHOLD=5.0
}
