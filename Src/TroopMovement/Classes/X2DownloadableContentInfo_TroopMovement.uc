/// X2DownloadableContentInfo_TroopMovement handles the initialization and setup of the TroopMovement mod.
/// Manages template creation, save game compatibility, and new campaign setup.
/// </summary>
class X2DownloadableContentInfo_TroopMovement extends X2DownloadableContentInfo config(Game);

var config int VERSION;
var config array<name> ActivityTemplates;

static event OnLoadedSavedGame()
{
    if(!class'X2DownloadableContentInfo_TroopMovement_CampaignHandler'.static.HasVersionNumberEntry(none, 'TroopMovement'))
    {
        class'X2DownloadableContentInfo_TroopMovement_CampaignHandler'.static.SetVersionNumber('TroopMovement', default.VERSION);
    }
}

static event InstallNewCampaign(XComGameState StartState)
{
    `LOG("TroopMovement: Installing new campaign",, 'TroopMovement');
    
    class'X2DownloadableContentInfo_TroopMovement_CampaignHandler'.static.SetVersionNumber('TroopMovement', default.VERSION);
    
    InitializeWorldMapSystem();
}

private static function UpdateTemplates(X2StrategyElementTemplateManager StratMgr)
{
    local X2DataTemplate Template;
    local name ActivityName;
    local bool bAllTemplatesValid;
    
    bAllTemplatesValid = true;
    
    foreach default.ActivityTemplates(ActivityName)
    {
        Template = StratMgr.FindStrategyElementTemplate(ActivityName);
        
        if (Template == none)
        {
            `LOG("WARNING: Failed to find template for activity:" @ ActivityName,, 'TroopMovement');
            bAllTemplatesValid = false;
        }
        else
        {
            `LOG("Successfully validated template:" @ ActivityName,, 'TroopMovement');
        }
    }
    
    if (!bAllTemplatesValid)
    {
        `LOG("WARNING: Some activity templates failed validation",, 'TroopMovement');
    }
}

private static function InitializeWorldMapSystem()
{
    if (!class'XCom2WorldMap'.static.IsInitialized())
    {
        `LOG("Initializing World Map system",, 'TroopMovement');
        class'XCom2WorldMap'.static.InitializeWorldMap();
    }
    else
    {
        `LOG("World Map system already initialized",, 'TroopMovement');
    }
}

private static function UpgradeMod(XComGameState NewGameState, XComGameState_CampaignSettings Settings)
{
    local int PreviousVersion;
    
    PreviousVersion = Settings.GetVersionNumber('TroopMovement');
    `LOG("Upgrading TroopMovement from version" @ PreviousVersion @ "to" @ default.VERSION,, 'TroopMovement');
    
    
    Settings.SetVersionNumber('TroopMovement', default.VERSION);
}

private static function SubmitGameState(XComGameState NewGameState)
{
    if (NewGameState.GetNumGameStateObjects() > 0)
    {
        `XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
    }
    else
    {
        `XCOMHISTORY.CleanupPendingGameState(NewGameState);
    }
}

defaultproperties
{
    VERSION=1
}