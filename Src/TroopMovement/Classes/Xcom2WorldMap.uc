/// <summary>
/// XCom2WorldMap defines and manages the valid connections between world regions.
/// This is used by the reinforcement pathfinding system to ensure realistic troop movements.
/// </summary>
class XCom2WorldMap extends Object config(LWActivities);

struct RegionDefinition
{
    var name RegionName;
    var array<name> Connections;
};

var const array<RegionDefinition> ValidConnections;
var private static bool bIsInitialized;

static function bool IsInitialized()
{
    return bIsInitialized;
}

static function InitializeWorldMap()
{
    if (bIsInitialized)
    {
        `LOG("World Map already initialized",, 'TroopMovement');
        return;
    }

    `LOG("Initializing World Map Structure",, 'TroopMovement');
    
    default.ValidConnections.Length = 0;  // Clear existing
    InitializeRegions();
    VerifyConnections();
    
    bIsInitialized = true;
}

private static function InitializeRegions()
{
    AddRegion('WorldRegion_EastAfrica', ["WorldRegion_EasternEurope", "WorldRegion_NewIndia", "WorldRegion_SouthAfrica", "WorldRegion_WestAfrica"]);
    AddRegion('WorldRegion_SouthAfrica', ["WorldRegion_EastAfrica", "WorldRegion_NewChile", "WorldRegion_WestAfrica"]);
    AddRegion('WorldRegion_WestAfrica', ["WorldRegion_EastAfrica", "WorldRegion_NewBrazil", "WorldRegion_SouthAfrica", "WorldRegion_WesternEurope"]);
    AddRegion('WorldRegion_EastAsia', ["WorldRegion_NewIndia", "WorldRegion_NewIndonesia"]);
    AddRegion('WorldRegion_NewArctic', ["WorldRegion_WestAsia", "WorldRegion_WesternUS"]);
    AddRegion('WorldRegion_NewIndia', ["WorldRegion_EastAfrica", "WorldRegion_EastAsia", "WorldRegion_WestAsia"]);
    AddRegion('WorldRegion_WestAsia', ["WorldRegion_EasternEurope", "WorldRegion_NewArctic", "WorldRegion_NewIndia"]);
    AddRegion('WorldRegion_EasternEurope', ["WorldRegion_EastAfrica", "WorldRegion_WestAsia", "WorldRegion_WesternEurope"]);
    AddRegion('WorldRegion_WesternEurope', ["WorldRegion_EasternEurope", "WorldRegion_EasternUS", "WorldRegion_WestAfrica"]);
    AddRegion('WorldRegion_EasternUS', ["WorldRegion_NewMexico", "WorldRegion_WesternEurope"]);
    AddRegion('WorldRegion_NewMexico', ["WorldRegion_EasternUS", "WorldRegion_NewBrazil", "WorldRegion_WesternUS"]);
    AddRegion('WorldRegion_WesternUS', ["WorldRegion_NewArctic", "WorldRegion_NewMexico"]);
    AddRegion('WorldRegion_NewAustralia', ["WorldRegion_NewChile", "WorldRegion_NewIndonesia"]);
    AddRegion('WorldRegion_NewIndonesia', ["WorldRegion_EastAsia", "WorldRegion_NewAustralia"]);
    AddRegion('WorldRegion_NewBrazil', ["WorldRegion_NewChile", "WorldRegion_NewMexico", "WorldRegion_WestAfrica"]);
    AddRegion('WorldRegion_NewChile', ["WorldRegion_NewAustralia", "WorldRegion_NewBrazil", "WorldRegion_SouthAfrica"]);
}

private static function AddRegion(name RegionName, array<name> Connections)
{
    local RegionDefinition Region;
    
    Region.RegionName = RegionName;
    Region.Connections = Connections;
    default.ValidConnections.AddItem(Region);
}

static function VerifyConnections()
{
    local int i, j;
    local RegionDefinition Region1, Region2;
    local bool bHasErrors;

    `LOG("Verifying region connections...",, 'TroopMovement');

    for(i = 0; i < default.ValidConnections.Length; i++)
    {
        Region1 = default.ValidConnections[i];
        for(j = 0; j < Region1.Connections.Length; j++)
        {
            if(!VerifyBidirectionalConnection(Region1.RegionName, Region1.Connections[j]))
            {
                bHasErrors = true;
            }
        }
    }

    if(!bHasErrors)
    {
        `LOG("All region connections verified successfully",, 'TroopMovement');
    }
}

private static function bool VerifyBidirectionalConnection(name Region1Name, name Region2Name)
{
    local RegionDefinition Region2;
    
    foreach default.ValidConnections(Region2)
    {
        if(Region2.RegionName == Region2Name)
        {
            if(Region2.Connections.Find(Region1Name) != INDEX_NONE)
            {
                return true;
            }
            break;
        }
    }
    
    `LOG("ERROR: Missing reciprocal connection between" @ Region1Name @ "and" @ Region2Name,, 'TroopMovement');
    return false;
}

static function array<name> GetValidConnections(name RegionName)
{
    local int i;
    
    if(RegionName == '')
    {
        `LOG("ERROR: GetValidConnections called with empty region name",, 'TroopMovement');
        return new class'array<name>';
    }
    
    for(i = 0; i < default.ValidConnections.Length; i++)
    {
        if(default.ValidConnections[i].RegionName == RegionName)
        {
            return default.ValidConnections[i].Connections;
        }
    }
    
    `LOG("WARNING: No connections found for region:" @ RegionName,, 'TroopMovement');
    return new class'array<name>';
}

static function bool AreRegionsConnected(name Region1Name, name Region2Name)
{
    local array<name> Connections;
    
    Connections = GetValidConnections(Region1Name);
    return Connections.Find(Region2Name) != INDEX_NONE;
}

static function array<name> GetAllRegions()
{
    local array<name> Regions;
    local RegionDefinition Region;
    
    foreach default.ValidConnections(Region)
    {
        Regions.AddItem(Region.RegionName);
    }
    
    return Regions;
}

static function int GetConnectionCount(name RegionName)
{
    local array<name> Connections;
    
    Connections = GetValidConnections(RegionName);
    return Connections.Length;
}