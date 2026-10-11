//=======================================================================\\
//		Copyright TSP172 || https://steamcommunity.com/id/tsp172/        \\
// 		You can freely modify and use this script in any of your maps    \\
// 		        Made for L4D2, credit is appreciated				     \\
//=======================================================================\\

wantedLevelEnabled <- true;
wantedLevel <- 0;
wantedHeat  <- 0; //crime points
threatLevel <- 1; //bit mask
policeCarelessLevel <- 0.7 //how careless the police are / how unlikely the wanted level will be attained?
allSurvivorsHiding <- false; //are survivors currently hiding?
cooldownTime <- 50.0; //cooldown time to clear wanted level
cooldownBegun <- false;

wantedlevelHud <- EntityGroup[0]; //env_screenoverlay entity
policeCarSpawner <- EntityGroup[1]; //env_entity_maker with ordinary police car
swatCarSpawner <- EntityGroup[2]; //env_entity_maker with SWAT Van
tankCarSpawner <- EntityGroup[3]; //env_entity_maker with a literally fucking tank.

const pursuitTheme = "#policescanner/wantedmusic_theme01.wav";
PrecacheSound(pursuitTheme);

enum eThreats
{
    iPolice = 1,
    iSwat = 2,
    iMilitary = 4
};

activePursuitVehicles <- 0;
maxAllowedVehicles <- 2;

//CRIME CODES:
/*
10-7 = Out of service (Police car or law vehicle destroyed.)
10-17 = Suspicious Noise (car alarm or horn, or other attractive noise.)
10-21 = Call Police Station / Call by Phone (trespassing restricted zone; trigger_multiple)
10-24 = Assignment Completed / Unit Available (survivors lost the cops)
10-28 = Vehicle Registration Check (entering vehicle without permission)
10-34 = Riot (killing large of common infected OR special trigger related to "riot")
10-37 = Suspicious Vehicle (driving recklessly, either forbidden zones or driving or zombies)
10-71 = Shots Fired / Gunfire (pipe bomb, grenade launcher, or any dangerous weapon used.)
10-81 = Traffic Stop / Breaker (vandalism???)
10-90 = Bank Alarm / Robbery in Progress (looting items or robbing a bank both works.)

*/
local worldOrigin = Vector(0, 0, 0);
const sndP = "policescanner/";
const sndT = ".mp3";
const staticSound = "policescanner/radio_static.wav";
const inSound = "policescanner/in1.mp3";
const onFoot = "policescanner/onfoot1.mp3";
const suspectLastSeen = "policescanner/lastseen1.mp3";
local worldOriginDistance = 1000;
local crimeCodes = ["7", "17", "21", "24", "28", "34", "37", "71", "81", "90"];
local respondTo = ["respond1", "respond2", "respond3"];
local policeScannerSpeaking = false;
//local vehicleColor = ["black", "blue", "brown", "gray", "green", "pink", "red", "white"] //pretty much useless tbh.
local vehicleType = ["2door", "4door", "golfcart", "policecar", "cruiser", "tank"]; //currently these vehicles exist in my mod.

local vehicleModels = {
    "models/tspvehicles/golfcart_body.mdl" : 2, //golf cart
    "models/tspvehicles/policecruiser_body.mdl" : 3, //police car
    //other driveables yet to be added.
}

EntFire(wantedlevelHud.GetName(), "StopOverlays", "", 1.0, null);

function PrecacheSoundAssets()
{
    foreach (prefix in respondTo)
    {
        local spath = sndP + prefix + sndT;
        PrecacheSound(spath);
    }

    foreach (code in crimeCodes)
    {
        local spath = sndP + code + sndT;
        PrecacheSound(spath);
    }

    foreach (vType in vehicleType)
    {
        local spath = sndP + vType + sndT;
        PrecacheSound(spath);
    }

    PrecacheSound(staticSound);
    PrecacheSound(suspectLastSeen);
    PrecacheSound(inSound);
    PrecacheSound(onFoot);

    printl("[POLICE SCANNER] All sounds precached");
}

PrecacheSoundAssets()


function GetSurvivors()
{
    for(local ent = null; ( ent = Entities.FindByClassname( ent , "player" ) ) != null; ){
        if(ent != null && ent.IsValid() && ent.GetZombieType() == 9){
            yield ent;
        }
    }
}

function GetRandomSurvivor()
{
    local survivors = [];
    for(local ent = null; ( ent = Entities.FindByClassname( ent , "player" ) ) != null; ){
        if(ent != null && ent.IsValid() && ent.GetZombieType() == 9){
            survivors.push(ent);
        }
    }
    if(survivors != null)
    {
        return survivors[RandomInt(0, survivors.len() - 1)];
    }   
}

function ChangeHeat(amount)
{
    wantedHeat += amount;
    
    if (wantedHeat >= 1200 && wantedLevel < 5) 
    {
        SetWantedLevel(5);
        maxAllowedVehicles = 5;
        threatLevel = eThreats.iSwat | eThreats.iMilitary | eThreats.iPolice
    }
    else if (wantedHeat >= 800 && wantedLevel < 4) 
    {
        SetWantedLevel(4);
        maxAllowedVehicles = 4;
        threatLevel = eThreats.iSwat | eThreats.iPolice
    }
    else if (wantedHeat >= 500 && wantedLevel < 3) 
    {
        SetWantedLevel(3);
        maxAllowedVehicles = 3;
        threatLevel = eThreats.iPolice
    }
    else if (wantedHeat >= 250 && wantedLevel < 2) 
    {
        SetWantedLevel(2);
        maxAllowedVehicles = 2;
        threatLevel = eThreats.iPolice
    }
    else if (wantedHeat >= 100 && wantedLevel < 1) 
    {
        SetWantedLevel(1);
        maxAllowedVehicles = 1;
        threatLevel = eThreats.iPolice
    }
}

function SetHeat(amount)
{
    wantedHeat = amount;
    
    if (wantedHeat >= 1200 && wantedLevel < 5) 
    {
        SetWantedLevel(5);
        maxAllowedVehicles = 5;
        threatLevel = eThreats.iSwat | eThreats.iMilitary | eThreats.iPolice
    }
    else if (wantedHeat >= 800 && wantedLevel < 4) 
    {
        SetWantedLevel(4);
        maxAllowedVehicles = 4;
        threatLevel = eThreats.iSwat | eThreats.iPolice
    }
    else if (wantedHeat >= 500 && wantedLevel < 3) 
    {
        SetWantedLevel(3);
        maxAllowedVehicles = 3;
        threatLevel = eThreats.iPolice
    }
    else if (wantedHeat >= 250 && wantedLevel < 2) 
    {
        SetWantedLevel(2);
        maxAllowedVehicles = 2;
        threatLevel = eThreats.iPolice
    }
    else if (wantedHeat >= 100 && wantedLevel < 1) 
    {
        SetWantedLevel(1);
        maxAllowedVehicles = 1;
        threatLevel = eThreats.iPolice
    }
}

function SetWantedLevel(newLevel)
{
    wantedLevel = newLevel;
    printl("WANTED LEVEL: " + newLevel);
    
    if(newLevel > 0)
    {
        EntFire(wantedlevelHud.GetName(), "StartOverlays", "", 0, null);
        DoEntFire("!self", "SwitchOverlay", newLevel.tostring(), 0.02, null, wantedlevelHud);
    }
    else
    {
        EntFire(wantedlevelHud.GetName(), "StopOverlays", "", 0.02, null);
        DoEntFire("!self", "SwitchOverlay", "0", 0.02, null, wantedlevelHud);
    }

    if(newLevel > 2)
    {
        //EmitAmbientSoundOn(pursuitTheme, 10, 0, 100, self);
    }
    else 
    {
        //StopAmbientSoundOn(pursuitTheme, self);
    }
}

function SayTheSound(soundT, chooseSound = 0)
{
    // Build full sound string from indices
    local sndPath = "";
    
    switch (soundT)
    {
        case 0: sndPath = sndP + respondTo[chooseSound] + sndT; break;      // "respond to 10-"
        case 1: sndPath = sndP + crimeCodes[chooseSound] + sndT; break;     // "71"
        case 2: sndPath = sndP + suspectLastSeen + sndT; break;             // "suspect last seen"
        case 3: sndPath = sndP + inSound + sndT; break;                     // "in"
        case 4: sndPath = sndP + onFoot + sndT; break;                      // "a vehicle / on foot"
        case 5: sndPath = sndP + vehicleType[chooseSound] + sndT; break;    // "golfcart"
    }

    if (sndPath == "") return;

    foreach (survivor in GetSurvivors())
    {
        if (survivor != null && survivor.IsValid())
        {
            //EmitSoundOnClient(sndPath, survivor);
            EmitAmbientSoundOn(sndPath, 10, 0, 100, self)
        }
    }
}

function PoliceScannerSpeaking()
{
    policeScannerSpeaking = policeScannerSpeaking == true ? false : true;
}

function RadioStatic(toggle = 0)
{
    if (toggle == 1)
    {
        EmitAmbientSoundOn(staticSound, 5, 0, 100, self);
    }
    else
    {
        StopAmbientSoundOn(staticSound, self);
    }
}

function GeneratePoliceScannerQuote(criminalLocation = Vector(0,0,0), code = 0, direction = 0, inFoot = 0, vehicle = 0)
{
    if(policeScannerSpeaking)
    {
        return;
    }

    local respondSound = RandomInt(0, respondTo.len() - 1);
    
    local delay0 = 1;
    local delay1 = delay0 + GetSoundDuration(respondTo[respondSound], null) + 0.15;
    local delay2 = delay1 + GetSoundDuration(crimeCodes[code], null) + 1;
    local delay3 = delay2 + GetSoundDuration(suspectLastSeen, null) + 1;
    local delay4 = delay3 + GetSoundDuration(inSound, null) + 0.5;

    DoEntFire("!self", "RunScriptCode", "SayTheSound(0, " + respondSound + ")", delay0, null, self);
    DoEntFire("!self", "RunScriptCode", "SayTheSound(1, " + code + ")", 1.2, null, self);
    DoEntFire("!self", "RunScriptCode", "SayTheSound(2, 0)", 2.1, null, self);
    DoEntFire("!self", "RunScriptCode", "SayTheSound(3, 0)", 3.1, null, self);

    RadioStatic(1);
    PoliceScannerSpeaking();
    DoEntFire("!self", "RunScriptCode", "PoliceScannerSpeaking()", delay4 + 1.0, null, self);

    local profileText = "on foot.";

    if (inFoot == 1)
    {
        DoEntFire("!self", "RunScriptCode", "SayTheSound(4, 0)", delay4, null, self);
        DoEntFire("!self", "RunScriptCode", "RadioStatic(0)", delay4 + 1.0, null, self);
    }
    else 
    {
        profileText = "in " + vehicleType[vehicle];
        DoEntFire("!self", "RunScriptCode", "SayTheSound(5, " + vehicle + ")", delay4, null, self);
        DoEntFire("!self", "RunScriptCode", "RadioStatic(0)", delay4 + 1.0, null, self);
    }
    ClientPrint(null, 3, "Police Radio: We got a 10-" + crimeCodes[code] + ", Suspect last seen " + profileText);
}

function GetPlayerVehicle(player)
{
    if (player != null && player.IsValid())
    {
        local parentEnt = player.GetMoveParent();
        
        if (parentEnt != null && parentEnt.IsValid())
        {
            local modelName = parentEnt.GetModelName();
            if (modelName in vehicleModels)
            {
                return vehicleModels[modelName];
            }
        }
    }
    return null;
}

function GetCriminalProfile(criminalID, code = 7) // default (7 = 10-71)
{
    local criminal = GetPlayerFromUserID(criminalID);
    
    if (criminal == null || !criminal.IsValid())
    {
        printl("[POLICE SCANNER] Criminal player doesn't exist.");
        return;
    }

    local criminalPos = criminal.GetOrigin();
    local vehicleIdx = GetPlayerVehicle(criminal);
    local isOnFoot = (vehicleIdx == null) ? 1 : 0;
    
    if (isOnFoot == 1) vehicleIdx = 0;

    printl("[POLICE SCANNER] Reporting player: On Foot: " + isOnFoot + " | Vehicle ID: " + vehicleIdx);

    GeneratePoliceScannerQuote(criminalPos, code, 0, isOnFoot, vehicleIdx);
}

function PursuitVehicleReduceorAdd(_number)
{
    activePursuitVehicles += _number
}

function LookForNearestSpawnPoint() //doesnt use this anymore.
{
    local target = GetRandomSurvivor();
    local spawnPoint = null;

    if(target != null)
    {
        spawnPoint = Entities.FindByNameNearest("npc_policecarspawner", target.GetOrigin(), 2000);
    }

    return spawnPoint;
}

function SurvivorsHiding(_toggle = 0)
{
    allSurvivorsHiding = _toggle == 1 ? true : false;

    local ent = null;
    while ((ent = Entities.FindByClassname(ent, "prop_physics")) != null)
    {
        if (ent.IsValid() && ent.ValidateScriptScope())
        {
            local policeScope = ent.GetScriptScope();
            
            if (policeScope != null && "SetPatrolConfig" in policeScope)
            {
                DoEntFire("!self", "RunScriptCode", "SetPatrolConfig(" + _toggle + ")", 0.00, null, ent);
            }
        }
    }
}

function DeletePoliceVehicles()
{
    local ent = null;
    while ((ent = Entities.FindByClassname(ent, "prop_physics")) != null)
    {
        if (ent.IsValid() && ent.ValidateScriptScope())
        {
            local policeScope = ent.GetScriptScope();
            
            if (policeScope != null)
            {
                if ("BlowUpVehicle" in policeScope)
                {
                    DoEntFire("!self", "RunScriptCode", "BlowUpVehicle()", 0.02, null, ent);
                }
                else
                {
                    DoEntFire("!self", "FireUser1", "", 0.02, null, ent);
                }
            }
        }
    }
    activePursuitVehicles = 0; 
}

function WantedStarsBlink()
{
    EntFire(wantedlevelHud.GetName(), "StopOverlays", "", 0.0, null);
    EntFire(wantedlevelHud.GetName(), "StartOverlays", "", 0.5, null);
    EntFire(wantedlevelHud.GetName(), "StopOverlays", "", 1.0, null);
    EntFire(wantedlevelHud.GetName(), "StartOverlays", "", 1.5, null);
}

function SelectRandomNavFromDistance(minDistance, maxDistance, survivor)
{
    if(survivor == null) return;
    local startPos = survivor.GetOrigin()
    local startArea = NavMesh.GetNavArea(startPos, 200);

    local availableNavs = {};
    local bestNavAreas = [];

    if (startArea == null)
    {
        return null;
    }

    NavMesh.GetNavAreasInRadius(startArea.GetCenter(), maxDistance, availableNavs);

    foreach (navmesh in availableNavs)
    {
        local navCenter = navmesh.GetCenter();
        local dist = (navCenter - startPos).Length2D();
            
        if (dist >= minDistance && dist <= maxDistance && (navmesh.GetAttributes() & 536870912) == 0) //navs marked with LYINGDOWN is forbidden.
        {
            bestNavAreas.push(navmesh);
        }
    }
        
    if (bestNavAreas.len() > 0)
    {
        return bestNavAreas[RandomInt(0, bestNavAreas.len() - 1)];
    }

    return null;
}

function WantedLevelThink()
{
    if (wantedLevel != 0 && allSurvivorsHiding)
    {
        WantedStarsBlink();
        cooldownBegun = true;
        cooldownTime -= 2.0;
        
        if (cooldownTime <= 0)
        {
            printl("Wanted level cleared");
            
            EntFire(wantedlevelHud.GetName(), "StopOverlays", "", 2.1, null); 
            
            DeletePoliceVehicles();
            SetHeat(0);
            wantedLevel = 0;
            cooldownBegun = false;
            cooldownTime = 50.0;
        }
        return 2.0;
    }

    else if (!allSurvivorsHiding && cooldownBegun && wantedLevel != 0)
    {
        EntFire(wantedlevelHud.GetName(), "StartOverlays", "", 0, null);
        cooldownBegun = false;
        cooldownTime = 50.0;
        return 0.1;
    }

    if(wantedLevel != 0 && wantedLevelEnabled)
    {
        local nearestSpawnPoint = SelectRandomNavFromDistance(950, 1600, GetRandomSurvivor())
        if(activePursuitVehicles <= maxAllowedVehicles && nearestSpawnPoint != null)
        {
            if (activePursuitVehicles >= maxAllowedVehicles) return;

            local availableSpawners = [];

            //printl(threatLevel);

            if (threatLevel & eThreats.iPolice)
            {
                //printl("Police active");
                availableSpawners.push(policeCarSpawner);
            }
            
            // Bit 2 (2): SWAT Van
            if (threatLevel & eThreats.iSwat)
            {
                //printl("SWAT active");
                availableSpawners.push(swatCarSpawner);
            }
            
            // Bit 3 (4): Literal Tank
            if (threatLevel & eThreats.iMilitary) 
            {
                //printl("Military active");
                availableSpawners.push(tankCarSpawner);
            }

            //printl(availableSpawners)

            if (availableSpawners.len() == 0) return;

            local selectedSpawner = availableSpawners[RandomInt(0, availableSpawners.len() - 1)];

            if (selectedSpawner != null && selectedSpawner.IsValid())
            {
                selectedSpawner.SetOrigin(nearestSpawnPoint.GetCenter() + Vector(0, 0, 10));
                selectedSpawner.SetAngles(QAngle(0, RandomInt(0, 360), 0));
                DoEntFire("!self", "ForceSpawn", "", 0.02, null, selectedSpawner);
                activePursuitVehicles++;
            }

            ChangeHeat(-2);
        }
    }
    return 2.0;
}

//======================GAME EVENTS AND TRIGGERS=====================//

function OnGameEvent_hegrenade_detonate(params)
{
    if ("userid" in params)
    {
        local player = GetPlayerFromUserID(params.userid);
        if (player != null && player.IsValid() && player.GetZombieType() == 9)
        {
            if (RandomFloat(0.0, 1.0) <= policeCarelessLevel)
            {
                printl("Not my problem...");
            }
            else
            {
                ChangeHeat(110);
                GetCriminalProfile(params.userid, 7);
                printl("Okay! That's my problem!");
            }
        }
    }
}

function OnGameEvent_triggered_car_alarm(params)
{
    if ("userid" in params)
    {
        local player = GetPlayerFromUserID(params.userid);
        if (player != null && player.IsValid() && player.GetZombieType() == 9)
        {
            if (RandomFloat(0.0, 1.0) <= policeCarelessLevel)
            {
                printl("Not my problem...");
            }
            else
            {
                ChangeHeat(260);
                GetCriminalProfile(params.userid, 9);
                printl("Okay! That's my problem!");
            }
        }
    }
}
/*
function OnGameEvent_player_death(params)
{
    local theAttacker = params.attacker;
    local attackerName = params.attackername;
    local victim = params.victimname;

    if(victim.GetClassname() == "infected" && attackerName.GetClassname() == "player")
    {
        printl("Crime commited!");
        wantedHeat += 10;
    }
}
*/


//call this following functions when necessary:

function CommitCrimeWithCare(heatPoints, crimeType = 2) //police will %100 care about this.
{
    if (activator != null)
    {
        GetCriminalProfile(activator.GetPlayerUserId(), crimeType);
        ChangeHeat(heatPoints);
    }
}

function CommitCrime(heatPoints, crimeType = 4) //police may or may not care about this.
{
    if (activator != null)
    {
        if (RandomFloat(0.0, 1.0) <= policeCarelessLevel)
        {
            printl("Not my problem...");
        }
        else
        {
            GetCriminalProfile(activator.GetPlayerUserId(), crimeType);
            ChangeHeat(heatPoints);
            printl("Okay! That's my problem!");
        }
    }
}

function DebugClearHeat()
{
    SetHeat(0)
    wantedHeat = 0;
    maxAllowedVehicles = 0;
}

function DebugBringItOn()
{
    SetHeat(1300)
    maxAllowedVehicles = 15;
}

AddThinkToEnt(self, "WantedLevelThink");
__CollectGameEventCallbacks(this);