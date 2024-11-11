/// X2DownloadableContentInfo_TroopMovement handles the initialization and setup of the TroopMovement mod.
/// Manages template creation, save game compatibility, and new campaign setup.
/// </summary>
class X2DownloadableContentInfo_TroopMovement extends X2DownloadableContentInfo config(Game);

var config int VERSION;
var config array<name> ActivityTemplates;

// Cache for tracking initialization
var private bool bInitialized;

static event OnPostTemplatesCreated()
{
    local X2StrategyElementTemplateManager StratMgr;
    
    `LOG("TroopMovement: Beginning template initialization",, 'TroopMovement');
    
    // Get the strategy template manager
    StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
    
    // Validate and update templates
    UpdateTemplates(StratMgr);
    
    // Initialize world map
    InitializeWorldMapSystem();
    
    `LOG("TroopMovement: Template initialization complete",, 'TroopMovement');
}

static event OnLoadedSavedGame()
{
    local XComGameState NewGameState;
    local XComGameState_CampaignSettings Settings;
    
    `LOG("TroopMovement: Processing saved game load",, 'TroopMovement');
    
    // Check version and perform upgrades if needed
    Settings = XComGameState_CampaignSettings(
        `XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings')
    );
    
    if (Settings != none && (!Settings.HasVersionNumberEntry('TroopMovement') || 
        Settings.GetVersionNumber('TroopMovement') < default.VERSION))
    {
        NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("TroopMovement Version Update");
        UpgradeMod(NewGameState, Settings);
        SubmitGameState(NewGameState);
    }
    
    // Initialize world map
    InitializeWorldMapSystem();
}

static event InstallNewCampaign(XComGameState StartState)
{
    local XComGameState_CampaignSettings Settings;
    
    `LOG("TroopMovement: Installing new campaign",, 'TroopMovement');
    
    // Set initial version
    Settings = XComGameState_CampaignSettings(
        StartState.CreateStateObject(class'XComGameState_CampaignSettings', 
        `XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings').ObjectID)
    );
    
    if (Settings != none)
    {
        Settings.SetVersionNumber('TroopMovement', default.VERSION);
        StartState.AddStateObject(Settings);
    }
    
    // Initialize world map
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
    
    // Add version-specific upgrade logic here if needed
    // Example:
    // if (PreviousVersion < 2)
    // {
    //     UpgradeToVersion2(NewGameState);
    // }
    
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