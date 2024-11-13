class X2LWActivityCondition_AnyAlienRegion extends X2LWActivityCondition;

simulated function bool MeetsCondition(X2LWActivityCreation ActivityCreation, XComGameState NewGameState)
{
    return true;
}

simulated function bool MeetsConditionWithRegion(X2LWActivityCreation ActivityCreation, XComGameState_WorldRegion Region, XComGameState NewGameState)
{
    local XComGameState_WorldRegion_LWStrategyAI RegionalAI;
    
    RegionalAI = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(Region, NewGameState);
    
    return RegionalAI != none && !RegionalAI.bLiberated;
}

defaultproperties
{
}