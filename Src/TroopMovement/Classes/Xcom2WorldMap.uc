class XCom2WorldMap extends Object config(LWActivities);

var const array<RegionDefinition> ValidConnections;

static function InitializeWorldMap()
{
    local RegionDefinition Region;
    
    `LOG("Initializing World Map Structure",, 'TroopMovement');

    // East Africa
    Region.RegionName = 'WorldRegion_EastAfrica';
    Region.Connections.Length = 0;
    Region.Connections.AddItem('WorldRegion_EasternEurope');
    Region.Connections.AddItem('WorldRegion_NewIndia');
    Region.Connections.AddItem('WorldRegion_SouthAfrica');
    Region.Connections.AddItem('WorldRegion_WestAfrica');
    default.ValidConnections.AddItem(Region);

    // South Africa
    Region.RegionName = 'WorldRegion_SouthAfrica';
    Region.Connections.Length = 0;
    Region.Connections.AddItem('WorldRegion_EastAfrica');
    Region.Connections.AddItem('WorldRegion_NewChile');
    Region.Connections.AddItem('WorldRegion_WestAfrica');
    default.ValidConnections.AddItem(Region);

    // West Africa
    Region.RegionName = 'WorldRegion_WestAfrica';
    Region.Connections.Length = 0;
    Region.Connections.AddItem('WorldRegion_EastAfrica');
    Region.Connections.AddItem('WorldRegion_NewBrazil');
    Region.Connections.AddItem('WorldRegion_SouthAfrica');
    Region.Connections.AddItem('WorldRegion_WesternEurope');
    default.ValidConnections.AddItem(Region);

    // East Asia
    Region.RegionName = 'WorldRegion_EastAsia';
    Region.Connections.Length = 0;
    Region.Connections.AddItem('WorldRegion_NewIndia');
    Region.Connections.AddItem('WorldRegion_NewIndonesia');
    default.ValidConnections.AddItem(Region);

    // New Arctic
    Region.RegionName = 'WorldRegion_NewArctic';
    Region.Connections.Length = 0;
    Region.Connections.AddItem('WorldRegion_WestAsia');
    Region.Connections.AddItem('WorldRegion_WesternUS');
    default.ValidConnections.AddItem(Region);

    // New India
    Region.RegionName = 'WorldRegion_NewIndia';
    Region.Connections.Length = 0;
    Region.Connections.AddItem('WorldRegion_EastAfrica');
    Region.Connections.AddItem('WorldRegion_EastAsia');
    Region.Connections.AddItem('WorldRegion_WestAsia');
    default.ValidConnections.AddItem(Region);

    // West Asia
    Region.RegionName = 'WorldRegion_WestAsia';
    Region.Connections.Length = 0;
    Region.Connections.AddItem('WorldRegion_EasternEurope');
    Region.Connections.AddItem('WorldRegion_NewArctic');
    Region.Connections.AddItem('WorldRegion_NewIndia');
    default.ValidConnections.AddItem(Region);

    // Eastern Europe
    Region.RegionName = 'WorldRegion_EasternEurope';
    Region.Connections.Length = 0;
    Region.Connections.AddItem('WorldRegion_EastAfrica');
    Region.Connections.AddItem('WorldRegion_WestAsia');
    Region.Connections.AddItem('WorldRegion_WesternEurope');
    default.ValidConnections.AddItem(Region);

    // Western Europe
    Region.RegionName = 'WorldRegion_WesternEurope';
    Region.Connections.Length = 0;
    Region.Connections.AddItem('WorldRegion_EasternEurope');
    Region.Connections.AddItem('WorldRegion_EasternUS');
    Region.Connections.AddItem('WorldRegion_WestAfrica');
    default.ValidConnections.AddItem(Region);

    // Eastern US
    Region.RegionName = 'WorldRegion_EasternUS';
    Region.Connections.Length = 0;
    Region.Connections.AddItem('WorldRegion_NewMexico');
    Region.Connections.AddItem('WorldRegion_WesternEurope');
    default.ValidConnections.AddItem(Region);

    // New Mexico
    Region.RegionName = 'WorldRegion_NewMexico';
    Region.Connections.Length = 0;
    Region.Connections.AddItem('WorldRegion_EasternUS');
    Region.Connections.AddItem('WorldRegion_NewBrazil');
    Region.Connections.AddItem('WorldRegion_WesternUS');
    default.ValidConnections.AddItem(Region);

    // Western US
    Region.RegionName = 'WorldRegion_WesternUS';
    Region.Connections.Length = 0;
    Region.Connections.AddItem('WorldRegion_NewArctic');
    Region.Connections.AddItem('WorldRegion_NewMexico');
    default.ValidConnections.AddItem(Region);

    // New Australia
    Region.RegionName = 'WorldRegion_NewAustralia';
    Region.Connections.Length = 0;
    Region.Connections.AddItem('WorldRegion_NewChile');
    Region.Connections.AddItem('WorldRegion_NewIndonesia');
    default.ValidConnections.AddItem(Region);

    // New Indonesia
    Region.RegionName = 'WorldRegion_NewIndonesia';
    Region.Connections.Length = 0;
    Region.Connections.AddItem('WorldRegion_EastAsia');
    Region.Connections.AddItem('WorldRegion_NewAustralia');
    default.ValidConnections.AddItem(Region);

    // New Brazil
    Region.RegionName = 'WorldRegion_NewBrazil';
    Region.Connections.Length = 0;
    Region.Connections.AddItem('WorldRegion_NewChile');
    Region.Connections.AddItem('WorldRegion_NewMexico');
    Region.Connections.AddItem('WorldRegion_WestAfrica');
    default.ValidConnections.AddItem(Region);

    // New Chile
    Region.RegionName = 'WorldRegion_NewChile';
    Region.Connections.Length = 0;
    Region.Connections.AddItem('WorldRegion_NewAustralia');
    Region.Connections.AddItem('WorldRegion_NewBrazil');
    Region.Connections.AddItem('WorldRegion_SouthAfrica');
    default.ValidConnections.AddItem(Region);

    VerifyConnections();
}

// Verify all connections are bidirectional
static function VerifyConnections()
{
    local int i, j;
    local RegionDefinition Region1, Region2;
    local bool bFoundMismatch;

    for(i = 0; i < default.ValidConnections.Length; i++)
    {
        Region1 = default.ValidConnections[i];
        for(j = 0; j < Region1.Connections.Length; j++)
        {
            bFoundMismatch = true;
            foreach default.ValidConnections(Region2)
            {
                if(Region2.RegionName == Region1.Connections[j])
                {
                    if(Region2.Connections.Find(Region1.RegionName) != INDEX_NONE)
                    {
                        bFoundMismatch = false;
                        break;
                    }
                }
            }
            
            if(bFoundMismatch)
            {
                `LOG("WARNING: Connection mismatch between" @ Region1.RegionName @ 
                    "and" @ Region1.Connections[j],, 'TroopMovement');
            }
        }
    }
}

// Get all valid connections for a region
static function array<name> GetValidConnections(name RegionName)
{
    local int i;
    
    for(i = 0; i < default.ValidConnections.Length; i++)
    {
        if(default.ValidConnections[i].RegionName == RegionName)
        {
            return default.ValidConnections[i].Connections;
        }
    }
    
    return new class'array<name>';
}