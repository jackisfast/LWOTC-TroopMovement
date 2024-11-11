class X2DownloadableContentInfo_TroopMovement extends X2DownloadableContentInfo;

static event OnLoadedSavedGame()
{
    `LOG("TroopMovement: Saved Game Loaded",, 'TroopMovement');
    class'XCom2WorldMap'.static.InitializeWorldMap();
}

static event OnPostTemplatesCreated()
{
    `LOG("TroopMovement: Templates Created",, 'TroopMovement');
    class'XCom2WorldMap'.static.InitializeWorldMap();
}

static event InstallNewCampaign(XComGameState StartState)
{
    `LOG("TroopMovement: New Campaign Started",, 'TroopMovement');
}