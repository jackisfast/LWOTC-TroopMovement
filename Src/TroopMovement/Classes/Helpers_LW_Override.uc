class Helpers_LW_Override extends Helpers_LW;

static function AddVigilanceNearby(
    XComGameState NewGameState, 
    XComGameState_WorldRegion RegionState,
    int BaseValue,
    int RandValue)
{
    local array<StateObjectReference> LinkedRegions;
    local StateObjectReference RegionRef;
    local XComGameState_WorldRegion_LWStrategyAI RegionalAI;
    local XComGameState_WorldRegion LinkedRegion;
    local array<name> ValidConnections;
    local XComGameStateHistory History;
    local name LinkedRegionName;

    History = `XCOMHISTORY;
    
    if(RegionState == none || NewGameState == none)
    {
        return;
    }

    ValidConnections = class'XCom2WorldMap'.static.GetValidConnections(RegionState.GetMyTemplateName());

    foreach ValidConnections(LinkedRegionName)
    {
        foreach History.IterateByClassType(class'XComGameState_WorldRegion', LinkedRegion)
        {
            if(LinkedRegion.GetMyTemplateName() == LinkedRegionName)
            {
                RegionRef.ObjectID = LinkedRegion.ObjectID;
                LinkedRegions.AddItem(RegionRef);
                break;
            }
        }
    }

    foreach LinkedRegions(RegionRef)
    {
        LinkedRegion = XComGameState_WorldRegion(History.GetGameStateForObjectID(RegionRef.ObjectID));
        if(LinkedRegion != none)
        {
            RegionalAI = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(LinkedRegion, NewGameState, true);
            if(RegionalAI != none)
            {
                RegionalAI.AddVigilance(NewGameState, BaseValue + `SYNC_RAND(RandValue));
            }
        }
    }
}