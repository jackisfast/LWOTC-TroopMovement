class XCom2WorldMap extends Object config(LWActivities);

struct RegionDefinition
{
    var name RegionName;
    var array<name> Connections;
};

var config array<RegionDefinition> ValidConnections;
var config bool bIsInitialized;  // Changed to config var

static function bool IsInitialized()
{
    return default.bIsInitialized;
}

static function InitializeWorldMap()
{
    local XCom2WorldMap Instance;

    if (default.bIsInitialized)
    {
        `LOG("World Map already initialized",, 'TroopMovement');
        return;
    }

    `LOG("Initializing World Map Structure",, 'TroopMovement');
    
    Instance = new class'XCom2WorldMap';
    Instance.InitializeRegions();
    Instance.VerifyConnections();
    
    // Save initialization state to config
    SetInitialized(true);
}

static function SetInitialized(bool bInitialized)
{
    default.bIsInitialized = bInitialized;
    StaticSaveConfig();
}

function InitializeRegions()
{
    local array<name> Connections;

    // Clear existing connections
    default.ValidConnections.Length = 0;

    // East Africa
    Connections.Length = 0;
    Connections.AddItem('WorldRegion_EasternEurope');
    Connections.AddItem('WorldRegion_NewIndia');
    Connections.AddItem('WorldRegion_SouthAfrica');
    Connections.AddItem('WorldRegion_WestAfrica');
    AddRegionToMap('WorldRegion_EastAfrica', Connections);

    // South Africa
    Connections.Length = 0;
    Connections.AddItem('WorldRegion_EastAfrica');
    Connections.AddItem('WorldRegion_NewChile');
    Connections.AddItem('WorldRegion_WestAfrica');
    AddRegionToMap('WorldRegion_SouthAfrica', Connections);

    // West Africa
    Connections.Length = 0;
    Connections.AddItem('WorldRegion_EastAfrica');
    Connections.AddItem('WorldRegion_NewBrazil');
    Connections.AddItem('WorldRegion_SouthAfrica');
    Connections.AddItem('WorldRegion_WesternEurope');
    AddRegionToMap('WorldRegion_WestAfrica', Connections);

    // East Asia
    Connections.Length = 0;
    Connections.AddItem('WorldRegion_NewIndia');
    Connections.AddItem('WorldRegion_NewIndonesia');
    AddRegionToMap('WorldRegion_EastAsia', Connections);

    // Arctic
    Connections.Length = 0;
    Connections.AddItem('WorldRegion_WestAsia');
    Connections.AddItem('WorldRegion_WesternUS');
    AddRegionToMap('WorldRegion_NewArctic', Connections);

    // India
    Connections.Length = 0;
    Connections.AddItem('WorldRegion_EastAfrica');
    Connections.AddItem('WorldRegion_EastAsia');
    Connections.AddItem('WorldRegion_WestAsia');
    AddRegionToMap('WorldRegion_NewIndia', Connections);

    // West Asia
    Connections.Length = 0;
    Connections.AddItem('WorldRegion_EasternEurope');
    Connections.AddItem('WorldRegion_NewArctic');
    Connections.AddItem('WorldRegion_NewIndia');
    AddRegionToMap('WorldRegion_WestAsia', Connections);

    // Eastern Europe
    Connections.Length = 0;
    Connections.AddItem('WorldRegion_EastAfrica');
    Connections.AddItem('WorldRegion_WestAsia');
    Connections.AddItem('WorldRegion_WesternEurope');
    AddRegionToMap('WorldRegion_EasternEurope', Connections);

    // Western Europe
    Connections.Length = 0;
    Connections.AddItem('WorldRegion_EasternEurope');
    Connections.AddItem('WorldRegion_EasternUS');
    Connections.AddItem('WorldRegion_WestAfrica');
    AddRegionToMap('WorldRegion_WesternEurope', Connections);

    // Eastern US
    Connections.Length = 0;
    Connections.AddItem('WorldRegion_NewMexico');
    Connections.AddItem('WorldRegion_WesternEurope');
    AddRegionToMap('WorldRegion_EasternUS', Connections);

    // Mexico
    Connections.Length = 0;
    Connections.AddItem('WorldRegion_EasternUS');
    Connections.AddItem('WorldRegion_NewBrazil');
    Connections.AddItem('WorldRegion_WesternUS');
    AddRegionToMap('WorldRegion_NewMexico', Connections);

    // Western US
    Connections.Length = 0;
    Connections.AddItem('WorldRegion_NewArctic');
    Connections.AddItem('WorldRegion_NewMexico');
    AddRegionToMap('WorldRegion_WesternUS', Connections);

    // Australia
    Connections.Length = 0;
    Connections.AddItem('WorldRegion_NewChile');
    Connections.AddItem('WorldRegion_NewIndonesia');
    AddRegionToMap('WorldRegion_NewAustralia', Connections);

    // Indonesia
    Connections.Length = 0;
    Connections.AddItem('WorldRegion_EastAsia');
    Connections.AddItem('WorldRegion_NewAustralia');
    AddRegionToMap('WorldRegion_NewIndonesia', Connections);

    // Brazil
    Connections.Length = 0;
    Connections.AddItem('WorldRegion_NewChile');
    Connections.AddItem('WorldRegion_NewMexico');
    Connections.AddItem('WorldRegion_WestAfrica');
    AddRegionToMap('WorldRegion_NewBrazil', Connections);

    // Chile
    Connections.Length = 0;
    Connections.AddItem('WorldRegion_NewAustralia');
    Connections.AddItem('WorldRegion_NewBrazil');
    Connections.AddItem('WorldRegion_SouthAfrica');
    AddRegionToMap('WorldRegion_NewChile', Connections);

    // Save the connections to config
    StaticSaveConfig();
}

function AddRegionToMap(name RegionName, array<name> Connections)
{
    local RegionDefinition NewRegion;
    
    NewRegion.RegionName = RegionName;
    NewRegion.Connections = Connections;
    default.ValidConnections.AddItem(NewRegion);
}

function VerifyConnections()
{
    local int i, j;
    local RegionDefinition Region1;
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
                `LOG("Error: Missing reciprocal connection between" @ Region1.RegionName @ "and" @ Region1.Connections[j],, 'TroopMovement');
            }
        }
    }

    if(!bHasErrors)
    {
        `LOG("All region connections verified successfully",, 'TroopMovement');
    }
}

static function bool VerifyBidirectionalConnection(name Region1Name, name Region2Name)
{
    local RegionDefinition Region;
    
    foreach default.ValidConnections(Region)
    {
        if(Region.RegionName == Region2Name)
        {
            if(Region.Connections.Find(Region1Name) != INDEX_NONE)
            {
                return true;
            }
            break;
        }
    }
    
    return false;
}

static function array<name> GetValidConnections(name RegionName)
{
    local RegionDefinition Region;
    local array<name> Result;

    Result.Length = 0; // Initialize the array
    
    if(RegionName == '')
    {
        `LOG("ERROR: GetValidConnections called with empty region name",, 'TroopMovement');
        return Result;
    }
    
    foreach default.ValidConnections(Region)
    {
        if(Region.RegionName == RegionName)
        {
            return Region.Connections;
        }
    }
    
    `LOG("WARNING: No connections found for region:" @ RegionName,, 'TroopMovement');
    return Result;
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
    
    Regions.Length = 0; // Initialize the array
    
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

defaultproperties
{
}