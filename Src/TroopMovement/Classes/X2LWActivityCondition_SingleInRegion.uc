class X2LWActivityCondition_SingleInRegion extends X2LWActivityCondition;

simulated function bool MeetsCondition(X2LWActivityCreation ActivityCreation, XComGameState NewGameState)
{
    return true;  // This is called for general activity creation
}

simulated function bool MeetsConditionWithRegion(X2LWActivityCreation ActivityCreation, XComGameState_WorldRegion Region, XComGameState NewGameState)
{
    local XComGameStateHistory History;
    local XComGameState_LWAlienActivity OtherActivity;
    
    History = `XCOMHISTORY;
    
    foreach History.IterateByClassType(class'XComGameState_LWAlienActivity', OtherActivity)
    {
        // If we find another activity in the same region, return false
        if(OtherActivity.PrimaryRegion.ObjectID == Region.ObjectID)
        {
            return false;
        }
    }
    
    return true;
}

defaultproperties
{
}