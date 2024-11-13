class LWReinforceActivity_Override extends X2LWAlienActivityTemplate config(LWActivities);

// Core configuration variables
var config int REINFORCE_DIFFERENCE_REQ_FOR_FORCELEVEL_TRANSFER;
var config float DEFAULT_VIGILANCE_THRESHOLD;
var config int MAX_PATH_HOPS;
var config int MIN_FORCE_LEVEL;
var config int REINFORCEMENTS_STOPPED_ORIGIN_VIGILANCE_INCREASE;
var config int REINFORCEMENTS_STOPPED_ADJACENT_VIGILANCE_BASE;
var config int REINFORCEMENTS_STOPPED_ADJACENT_VIGILANCE_RAND;

var X2LWActivityCondition SingleActivityInRegion;
var X2LWActivityCondition_AnyAlienRegion AnyAlienRegion;

struct RegionParentPair
{
    var XComGameState_WorldRegion Region;
    var XComGameState_WorldRegion Parent;
};

struct RegionHopPair 
{
    var XComGameState_WorldRegion Region;
    var int Hops;
};

// Implementation functions with different names to avoid conflicts
static function OnMissionSuccessImpl(XComGameState_LWAlienActivity ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
{
    OnReinforceActivityComplete(true, ActivityState, NewGameState);
}

static function OnMissionFailureImpl(XComGameState_LWAlienActivity ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
{
    OnReinforceActivityComplete(false, ActivityState, NewGameState);
}

// Your CreateReinforceTemplate implementation
static function X2DataTemplate CreateReinforceTemplate()
{
    local X2LWAlienActivityTemplate Template;
    local X2LWActivityCondition_Month MonthRestriction;
    local X2LWActivityCondition_SingleInRegion SingleCondition;
    local X2LWActivityCondition_AnyAlienRegion AlienCondition;
    local LWReinforceActivity_Override ReinforceTemplate;

    `CREATE_X2TEMPLATE(class'X2LWAlienActivityTemplate', Template, 'Activity_Reinforce');
    Template.iPriority = 50;
    
    // One per region that ADVENT controls
    Template.ActivityCreation = new class'X2LWActivityCreation_Reinforce';
    
    SingleCondition = new class'X2LWActivityCondition_SingleInRegion';
    AlienCondition = new class'X2LWActivityCondition_AnyAlienRegion';
    Template.ActivityCreation.Conditions.AddItem(SingleCondition);
    Template.ActivityCreation.Conditions.AddItem(AlienCondition);
    
    // Not in first month 
    MonthRestriction = new class'X2LWActivityCondition_Month';
    MonthRestriction.FirstMonthPossible = 1;
    Template.ActivityCreation.Conditions.AddItem(MonthRestriction);
    
    Template.DetectionCalc = new class'X2LWActivityDetectionCalc';
    
    // Assign delegate-compatible functions with Impl suffix
    Template.OnMissionSuccessFn = OnMissionSuccessImpl;
    Template.OnMissionFailureFn = OnMissionFailureImpl;
    Template.GetMissionForceLevelFn = GetMissionForceLevelImpl;  // Updated this line
    Template.GetMissionAlertLevelFn = GetReinforceAlertLevel;
    Template.GetMissionRewardsFn = GetReinforceRewards;
    Template.OnActivityCompletedFn = OnReinforceActivityComplete;
    
    return Template;
}

static function int GetMissionForceLevelImpl(XComGameState_LWAlienActivity ActivityState, XComGameState_MissionSite MissionSite, XComGameState NewGameState)
{
    local XComGameState_WorldRegion OriginRegionState;
    local XComGameState_WorldRegion_LWStrategyAI OriginAIState;

    OriginRegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.SecondaryRegions[0].ObjectID));
    if(OriginRegionState == none)
        OriginRegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.SecondaryRegions[0].ObjectID));

    OriginAIState = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(OriginRegionState, NewGameState);
    
    return Max(1, OriginAIState.LocalForceLevel + ActivityState.GetMyTemplate().ForceLevelModifier);
}

// The rest of your functions can remain the same, but we need to modify how we access config values
static function UpdateRegionalStrength(array<XComGameState_WorldRegion> Path, XComGameState NewGameState)
{
    local XComGameState_WorldRegion CurrentRegion;
    local XComGameState_WorldRegion_LWStrategyAI CurrentAI, NextAI, TargetAI;
    local int i, j;
    local float BestNeed, CurrentNeed;
    local bool bFoundTransfer;
    local LWReinforceActivity_Override Template;

    Template = new class'LWReinforceActivity_Override';

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

    for(i = 0; i < Path.Length - 1; i++)
    {
        CurrentRegion = Path[i];
        CurrentAI = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(CurrentRegion, NewGameState, true);
        NextAI = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(Path[i + 1], NewGameState, true);

        if(CurrentAI.LocalForceLevel <= Min(CurrentAI.LocalVigilanceLevel, Template.MIN_FORCE_LEVEL))
        {
            continue;
        }

        BestNeed = Template.REINFORCE_DIFFERENCE_REQ_FOR_FORCELEVEL_TRANSFER;
        bFoundTransfer = false;

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

static function OnReinforceActivityComplete(
    bool bAlienSuccess, 
    XComGameState_LWAlienActivity ActivityState, 
    XComGameState NewGameState)
{
    local XComGameState_WorldRegion DestRegionState, OrigRegionState;
    local XComGameState_WorldRegion_LWStrategyAI DestRegionalAI, OrigRegionalAI;
    local array<XComGameState_WorldRegion> Path;
    local LWReinforceActivity_Override Template;

    Template = new class'LWReinforceActivity_Override';

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

        if (OrigRegionalAI.LocalAlertLevel > 1)
        {
            DestRegionalAI.LocalAlertLevel += 1;
            OrigRegionalAI.LocalAlertLevel -= 1;
        }

        Path = GetPathToHighVigilance(DestRegionState, NewGameState);
        if(Path.Length > 0)
        {
            UpdateRegionalStrength(Path, NewGameState);
        }
        else if(DestRegionalAI.LocalVigilanceLevel - DestRegionalAI.LocalAlertLevel > Template.REINFORCE_DIFFERENCE_REQ_FOR_FORCELEVEL_TRANSFER)
        {
            if(OrigRegionalAI.LocalForceLevel > Template.MIN_FORCE_LEVEL)
            {
                DestRegionalAI.LocalForceLevel += 1;
                OrigRegionalAI.LocalForceLevel -= 1;
            }
        }
    }
    else
    {
        `LOG("ReinforceRegion: XCOM Success",, 'TroopMovement');
        OrigRegionalAI.LocalAlertLevel = Max(OrigRegionalAI.LocalAlertLevel - 1, 1);
        OrigRegionalAI.AddVigilance(NewGameState, Template.REINFORCEMENTS_STOPPED_ORIGIN_VIGILANCE_INCREASE);
        class'Helpers_LW_Override'.static.AddVigilanceNearby(NewGameState, DestRegionState, 
            Template.REINFORCEMENTS_STOPPED_ADJACENT_VIGILANCE_BASE,
            Template.REINFORCEMENTS_STOPPED_ADJACENT_VIGILANCE_RAND);
    }
}

defaultproperties
{
    SingleActivityInRegion=class'X2LWActivityCondition_SingleInRegion'
    AnyAlienRegion=class'X2LWActivityCondition_AnyAlienRegion'
}