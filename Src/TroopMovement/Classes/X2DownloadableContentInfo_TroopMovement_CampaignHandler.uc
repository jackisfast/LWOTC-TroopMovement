class X2DownloadableContentInfo_TroopMovement_CampaignHandler extends Object config(Game);

var config array<name> ModNames;
var config array<int> ModVersions;

static function bool HasVersionNumberEntry(XComGameState_CampaignSettings Settings, name ModName)
{
    return default.ModNames.Find(ModName) != INDEX_NONE;
}

static function int GetVersionNumber(name ModName)
{
    local int Index;
    
    Index = default.ModNames.Find(ModName);
    if(Index != INDEX_NONE)
        return default.ModVersions[Index];
    return -1;
}

static function SetVersionNumber(name ModName, int Version)
{
    local int Index;
    
    Index = default.ModNames.Find(ModName);
    if(Index == INDEX_NONE)
    {
        default.ModNames.AddItem(ModName);
        default.ModVersions.AddItem(Version);
    }
    else
    {
        default.ModVersions[Index] = Version;
    }
    
    StaticSaveConfig();
}

defaultproperties
{
}