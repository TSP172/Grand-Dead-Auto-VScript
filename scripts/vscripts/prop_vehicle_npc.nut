//=======================================================================\\
//		Copyright TSP172 || https://steamcommunity.com/id/tsp172/        \\
// 		You can freely modify and use this script in any of your maps    \\
// 		        Made for L4D2, credit is appreciated				     \\
//=======================================================================\\

// ATTACH THIS SCRIPT TO A VEHICLE PROP (PHYSICS) TO MAKE IT DRIVEABLE //

//to create a vehicle you need:
/*
1 - prop_physics_multiplayer for the vehicle body (make sure is set to "debris" to prevent collision issues with players)
WARNING: ALSO ADD OnHitByTank OUTPUT THAT FIRES CATCHONFIRE() FUNCTION OTHERWISE THE CAR WILL DISAPPEAR AS ITS OWN.
WARNING 2: ADD ONUSER1 OUTPUTS TO KILL PHYS_CONSTRAINT AND TIRE ENTITIES.
2 - prop_physics_multiplayer for tires (4 of them)
3 - phys_ballsocket to attach tires to body prop
4 - phys_constraint to connect 2 tires in middle of vehicle (front and rear)
5 - phys_keepupright entity to prevent vehicle from flipping over.
6 - logic_relay with onspawn output to configure
7 - add func_breakable to make collide with players but also damageable by players/infected.
WARNING: SANE NAME AS VEHICLE BODY WITH "_breakable" PREFIX! LOWER CASE!
8 - OPTIONAL: Sounds effects and lights for vehicle to give a nice touch.
9 - OPTIONAL: env_weaponfire entity to make car fire at survivors.

Rest will handled by this script.
*/

//=========== PAINT COLOR CONFIG ===========//

local paintJobs = [
    "255 255 255", //White (default)
    "94 188 69", //green
    "23 88 224", //blue
    "23 88 224", //calm purple
    "255 81 81", //glow red
    "0 225 222", //cyan
    "255 210 0", //yellow
    "196 137 35", //orange
    "196 137 35", //lime
    "196 137 35", //hot pink
    "166 166 166", //gray
    "0 0 0", //black
    "118 96 49" //brown
]

//=========== AI TYPE CONFIG ===========//

local wantedLevelScript = Entities.FindByName(null, "script_wantedlevel"); //add only if you want police chases.

local AIType = 0;
local AIActive = true;
local searchRadius = 1000;
local despawnRadius = 2000;
local despawnIfNoEnemy = true;
local nextWayPointTimer = 0.5;
local stuckTimer = 5.0;
local tryingToGetUnstuck = false;
local myLastOriginTimer = 2.0;
local myLastOrigin = null;
local currentWayPoint = null;
local currentEnemy = null;
local infectedType = 8;
local howManyInfected = 2; //never should be 0
/* AI TYPES:
0 = Police: spawns enemy infected after survivors that OUTSIDE of the vehicle nearby (prefered tanks)
1 = Hit & Run: contuniously runs over target survivors, in vehicle or not.

NOTE: the vehicle will not be controlled by AI if the driver is infected player (versus)
*/

//=========== VEHICLE CONFIG ===========//
local playersInVehicle = 
{
    driver = null,
    passanger1 = null,
    passanger2 = null,
    passanger3 = null
}
local vehicleCapacity = 2; //set this to change vehicle capacity (it cant be less than 1 or more than 4)

local vehicleOffset = self.GetOrigin();
local driverSeatOffset = Vector(0, 0, 0);
local passangerSeat1Offset = null;
local passangerSeat2Offset = null;
local passangerSeat3Offset = null;

//=========== FUEL CONFIG ===========//

local vehicleFuel = 99999; // Seconds of fuel remaining; since this is NPC controlled give a infinite fuel
local maxFuel = 99999.0; //seconds of max fuel allowed; ditto above
local fuelPerGasCan = 60.0; //how much gas (in seconds) will gas can gonna give us? pretty much useless for npc driven car
local isEngineRunning = false; //set this false at first to prevent gas being consumed while nobody inside car.
local lowGasWarningGiven = false;

//=========== HEALTH CONFIG ===========//

//local breakableEntity = Entities.FindByName(null, self.GetName() + "_breakable");
local breakableEntity = 1;
//local maxVehicleHealth = 1000;
//local currentVehicleHealth = 1000; //if vehicle health gets 100 or under, the catch on fire.
//the 2 variables above obsolete because is gonna have func_breakable entity anyways.
local isBurning = false;
local isDestroyed = false;

PrecacheSound("sfx/vehicles/police_siren02.wav");

local thrustForward = SpawnEntityFromTable("phys_thruster", {targetname = self.GetName() + "_forward", spawnflags = 26, forcetime = 0, force = 8000, attach1 = self.GetName(), angles = Vector(0, -180, 0)});
local thrustBackward = SpawnEntityFromTable("phys_thruster", {targetname = self.GetName() + "_backward", spawnflags = 26, forcetime = 0, force = 8000, attach1 = self.GetName(), angles = Vector(0, 0, 0)});
local thrustLeft = SpawnEntityFromTable("phys_thruster", {targetname = self.GetName() + "_left", spawnflags = 44, forcetime = 0, force = 17000 * 5, attach1 = self.GetName(), angles = Vector(0, -90, 0)});
local thrustRight = SpawnEntityFromTable("phys_thruster", {targetname = self.GetName() + "_right", spawnflags = 44, forcetime = 0, force = 17000 * 5, attach1 = self.GetName(), angles = Vector(0, -270, 0)});
local env_weaponfire = null;

//printl(self.GetName());


function GetChildren(ent)
{
    local children = [];
    if (ent == null || !ent.IsValid()) return children;

    local child = NetProps.GetPropEntity(ent, "m_hMoveChild");

    while (child != null && child.IsValid())
    {
        children.push(child);
        
        local subChildren = GetChildren(child);
        foreach (subChild in subChildren)
        {
            children.push(subChild);
        }

        child = NetProps.GetPropEntity(child, "m_hMovePeer");
    }

    return children;
}

foreach(child in GetChildren(self))
{
    if(child.GetClassname() == "func_breakable")
    {
        breakableEntity = child;
        break;
    }
    else if(child.GetClassname() == "env_weaponfire")
    {
        env_weaponfire = child;
    }
}

function RemoveLocalMatchingConstraints(vehicleEnt, searchRadius = 150.0)
{
    //this does not work properly, use OnKilled output for the car model instead. but let this still kill phys_ballsocket entities.
    if (vehicleEnt == null || !vehicleEnt.IsValid()) return;

    local carName = vehicleEnt.GetName(); // ex: "police_car&0001"
    if (carName == "") return;

    local suffixIdx = carName.find("&");
    if (suffixIdx == null) return;
    
    local instanceSuffix = carName.slice(suffixIdx); // "&0001"
    local origin = vehicleEnt.GetOrigin();

    local constraintClasses = [
        "phys_ballsocket",
        "phys_constraint",
        "phys_hinge",
        "phys_slideconstraint",
        "phys_spring",
        "phys_keepupright",
        "prop_physics"
    ];

    foreach (className in constraintClasses)
    {
        local nearbyEnts = [];
        local ent = null;

        while ((ent = Entities.FindByClassnameWithin(ent, className, origin, searchRadius)) != null)
        {
            if (ent.IsValid())
            {
                nearbyEnts.push(ent);
            }
        }

        foreach (targetEnt in nearbyEnts)
        {
            if (targetEnt != null && targetEnt.IsValid())
            {
                local targetName = targetEnt.GetName();

                if (targetEnt.GetClassname() == "phys_constraint" || (targetName != "" && targetName.find(instanceSuffix) != null))
                {
                    if (targetName != "")
                    {
                        DoEntFire("!self", "Kill", "", 0.0, null, targetName);
                    }
                }
            }
        }
    }
}
function SetAIType(type = 0)
{
    AIType = 0;
}

function SetCapacity(capacity) 
{
    if(capacity < 1 || capacity > 4) {
        printl("Vehicle capacity must be between 1 and 4");
        return;
    }
    vehicleCapacity = capacity;
}

function GetBotInfected()
{
    for(local ent = null; ( ent = Entities.FindByClassname( ent , "player" ) ) != null; ){
        if(ent != null && ent.IsValid() && ent.GetZombieType() != 9 && IsPlayerABot(ent)){
            yield ent;
        }
    }
}

function GetInfected()
{
    for(local ent = null; ( ent = Entities.FindByClassname( ent , "player" ) ) != null; ){
        if(ent != null && ent.IsValid() && ent.GetZombieType() != 9){
            yield ent;
        }
    }
}

function GetSurvivors()
{
    for(local ent = null; ( ent = Entities.FindByClassname( ent , "player" ) ) != null; ){
        if(ent != null && ent.IsValid() && ent.GetZombieType() == 9){
            yield ent;
        }
    }
}

function GetPeopleSittingInsideCar()
{
    local vehiclePlayers = [];

    foreach(key, person in playersInVehicle)
    {
        if(person != null)
        {
            vehiclePlayers.push(person);
        }
    }
    return vehiclePlayers;
}

function ForceBotsGetInVehicle()
{
    local vehOrigin = self.GetOrigin();

    foreach (botSurvivor in GetBotInfected())
    {
        // Skip if this bot is already inside this vehicle
        local alreadyInVeh = false;
        foreach (slot, p in playersInVehicle)
        {
            if (p == botSurvivor) { alreadyInVeh = true; break; }
        }
        if (alreadyInVeh) continue;

        // Seat 1
        if (vehicleCapacity >= 2 && passangerSeat1Offset != null && playersInVehicle.passanger1 == null)
        {
            playersInVehicle.passanger1 = botSurvivor;
            NetProps.SetPropInt(botSurvivor, "movetype", 0);
            botSurvivor.SetOrigin(vehOrigin + passangerSeat1Offset);
            DoEntFire("!self", "SetParent", self.GetName(), 0.00, null, botSurvivor);
            printl("Bot Passenger 1 entered vehicle: " + botSurvivor.GetPlayerName());
        }
        // Seat 2
        else if (vehicleCapacity >= 3 && passangerSeat2Offset != null && playersInVehicle.passanger2 == null)
        {
            playersInVehicle.passanger2 = botSurvivor;
            NetProps.SetPropInt(botSurvivor, "movetype", 0);
            botSurvivor.SetOrigin(vehOrigin + passangerSeat2Offset);
            DoEntFire("!self", "SetParent", self.GetName(), 0.00, null, botSurvivor);
            printl("Bot Passenger 2 entered vehicle: " + botSurvivor.GetPlayerName());
        }
        // Seat 3
        else if (vehicleCapacity >= 4 && passangerSeat3Offset != null && playersInVehicle.passanger3 == null)
        {
            playersInVehicle.passanger3 = botSurvivor;
            NetProps.SetPropInt(botSurvivor, "movetype", 0);
            botSurvivor.SetOrigin(vehOrigin + passangerSeat3Offset);
            DoEntFire("!self", "SetParent", self.GetName(), 0.00, null, botSurvivor);
            printl("Bot Passenger 3 entered vehicle: " + botSurvivor.GetPlayerName());
        }
    }
}

function ForceBotsGetOutVehicle()
{
    foreach (slot, occupant in playersInVehicle)
    {
        if (occupant != null && occupant.IsValid() && occupant.GetZombieType() == 9 && IsPlayerABot(occupant))
        {
            GetOutVehicle(occupant);
        }
    }
}

function SetSeatOrigins(driverOrigin, passanger1Available = 0, passanger1Origin = null, passanger2Available = 0, passanger2Origin = null, passanger3Available = 0, passanger3Origin = null) 
{
    // Pass raw relative vectors here (e.g. Vector(15, -20, 10))
    driverSeatOffset = driverOrigin;
    if(passanger1Available == 1 && passanger1Origin != null) passangerSeat1Offset = passanger1Origin;
    if(passanger2Available == 1 && passanger2Origin != null) passangerSeat2Offset = passanger2Origin;
    if(passanger3Available == 1 && passanger3Origin != null) passangerSeat3Offset = passanger3Origin;
}

function GetCurrentOccupantCount()
{
    local count = 0;
    foreach (slot, player in playersInVehicle)
    {
        if (player != null && player.IsValid())
        {
            count++;
        }
    }
    return count;
}

//player solid type is "195" according to netprops.

function GetInVehicle()
{
    if (!("activator" in ::getroottable()) || activator == null) return;

    // Check if player is already in this vehicle
    foreach (slot, player in playersInVehicle)
    {
        if (player == activator || activator.GetContext("InVehicle") == "Yes") return;
    }

    if (GetCurrentOccupantCount() >= vehicleCapacity) {
        printl("Vehicle is full");
        return;
    }

    local vehOrigin = self.GetOrigin();

    // Driver seat priority
    if (playersInVehicle.driver == null)
    {
        playersInVehicle.driver = activator;
        NetProps.SetPropInt(activator, "movetype", 0); // Freeze movement
        activator.SetContext("InVehicle", "Yes", -1);
        
        activator.SetOrigin(vehOrigin + driverSeatOffset);
        
        DoEntFire("!self", "SetParent", self.GetName(), 0.0, null, activator);
        local gameUIEntity = Entities.FindByName(null, self.GetName() + "_gameui");
        if(gameUIEntity != null)
        {
            DoEntFire(self.GetName() + "_gameui", "Activate", "", 0, activator, null);
        }
    }
    else if (vehicleCapacity >= 2 && passangerSeat1Offset != null && playersInVehicle.passanger1 == null)
    {
        playersInVehicle.passanger1 = activator;
        NetProps.SetPropInt(activator, "movetype", 0);
        activator.SetContext("InVehicle", "Yes", -1);
        
        activator.SetOrigin(vehOrigin + passangerSeat1Offset);
        DoEntFire("!self", "SetParent", self.GetName(), 0.0, null, activator);
    }
    else if (vehicleCapacity >= 3 && passangerSeat2Offset != null && playersInVehicle.passanger2 == null)
    {
        playersInVehicle.passanger2 = activator;
        NetProps.SetPropInt(activator, "movetype", 0);
        activator.SetContext("InVehicle", "Yes", -1);
        
        activator.SetOrigin(vehOrigin + passangerSeat2Offset);
        DoEntFire("!self", "SetParent", self.GetName(), 0.0, null, activator);
    }
    else if (vehicleCapacity >= 4 && passangerSeat3Offset != null && playersInVehicle.passanger3 == null)
    {
        playersInVehicle.passanger3 = activator;
        NetProps.SetPropInt(activator, "movetype", 0);
        activator.SetContext("InVehicle", "Yes", -1);
        
        activator.SetOrigin(vehOrigin + passangerSeat3Offset);
        DoEntFire("!self", "SetParent", self.GetName(), 0.0, null, activator);
    }
}

function GetOutVehicle(playerToExit)
{
    if (playerToExit == null || !playerToExit.IsValid()) return;

    local foundSlot = null;
    foreach (slot, p in playersInVehicle)
    {
        if (p == playerToExit)
        {
            foundSlot = slot;
            break;
        }
    }

    if (foundSlot == null) return;

    //local exitPos = self.GetOrigin() + Vector(0, 0, 50); //this shit teleports us out of boundaries for some reason.
    //local worldExitPos = playerToExit.GetOrigin() + Vector(0, 0, 50); //same shit

    DoEntFire("!self", "ClearParent", "", 0, null, playerToExit);

    local gameUIEntity = Entities.FindByName(null, self.GetName() + "_gameui");

    // Unbind Measure Movement entity and deactivate game_ui if driver
    if (foundSlot == "driver" && gameUIEntity != null)
    {
        DoEntFire(self.GetName() + "_gameui", "Deactivate", "", 0, playerToExit, null);
        ForceBotsGetOutVehicle();
    }

    local entHandle = playerToExit.GetPlayerUserId();
    playersInVehicle[foundSlot] = null;

    NetProps.SetPropInt(playerToExit, "movetype", 2); // MOVETYPE_WALK
    playerToExit.SetContext("InVehicle", "No", -1);
    DoEntFire("!self", "RunScriptCode", "TeleportOutsideHack(" + entHandle + ")", 0.03, playerToExit, self);

    printl(foundSlot + " exited vehicle");
}

function TeleportOutsideHack(player)
{
    if(player != null)
    {
        local thePlayer = GetPlayerFromUserID(player)
        thePlayer.SetOrigin(thePlayer.GetOrigin() + Vector(0, 0, 60));
    }
}

function ForceEveryoneGetOut()
{
    if(GetInfected() != null)
    {
        foreach(infected in GetInfected())
        {
            GetOutVehicle(infected)
        }
    }
}

function CatchOnFire()
{
    if(isBurning)
    {
        return;
    }

    //currentVehicleHealth = 100;

    if(env_weaponfire != null)
    {
        DoEntFire("!self", "Kill", "", 0.02, null, env_weaponfire);
    }

    local fireParticle = SpawnEntityFromTable("info_particle_system", {
        effect_name = "fire_jet_01",
        parent = self,
        start_active = 1,
        origin = self.GetOrigin()
    })

    DoEntFire("!self", "SetParent", self.GetName(), 0.02, null, fireParticle)

    isBurning = true;

    DoEntFire("!self", "RunScriptCode", "BlowUpVehicle()", 3.0, null, self);

    EmitAmbientSoundOn("ambient/fire/interior_fireclose03_mono.wav", 10, 85, 100, self);
    StopAmbientSoundOn("sfx/vehicles/police_siren02.wav", self);
}

function BlowUpVehicle()
{
    local explosionEntity = SpawnEntityFromTable("env_explosion", {
        fireballsprite = "sprites/zerogxplode.spr",
        iRadiusOverride = 350,
        iMagnitude = 300,
        rendermode = 5,
        spawnflags = 2
        origin = self.GetOrigin()
    })

    local explosionParticleEntity = SpawnEntityFromTable("info_particle_system", {
        effect_name = "Fluid_Seeds",
        start_active = 1,
        origin = self.GetOrigin()
    })

    EmitSoundOn("bombing.close_explos", self);

    isDestroyed = true;

    self.SetVelocity(Vector(0, 0, 3000));   

    if(wantedLevelScript != null)
    {
        DoEntFire("!self", "RunScriptCode", "PursuitVehicleReduceorAdd(-1)", 0, null, wantedLevelScript);
    }

    ForceEveryoneGetOut();

    StopAmbientSoundOn("ambient/fire/interior_fireclose03_mono.wav", self);

    RemoveLocalMatchingConstraints(self, 150.0);

    DoEntFire("!self", "color", "0 0 0", 0.00, null, self);
    DoEntFire("!self", "Explode", "", 0.05, null, explosionEntity);
    DoEntFire("!self", "Kill", "", 5, null, explosionParticleEntity);

    DoEntFire("!self", "FireUser1", "", 0, null, self); //fire OnUser1 inputs and kill these entities to prevent edict issues.
    DoEntFire("!self", "Kill", "", 5, null, self);
    
    AddThinkToEnt(self, ""); //stop thinking.
}

function RefuelVehicle()
{
    if (isDestroyed) return;

    vehicleFuel += fuelPerGasCan;
    if (vehicleFuel > maxFuel) vehicleFuel = maxFuel;

    lowGasWarningGiven = false;

    ClientPrint(null, 3, "\x04[VEHICLE]\x01 Added fuel! Current Fuel: " + vehicleFuel + "s");
    
    // Play refueling sound effect
    EmitAmbientSoundOn("player/items/gas_can_fill_pour_01.wav", 10, 150, 100, self);
}

function ConsumeFuel() //pretty much obsolete for infected/enemy driven vehicles.
{
    if(isEngineRunning)
    {
        vehicleFuel -= 0.05;
        //printl("Current Gas: " + vehicleFuel);
    }
}

function ToggleEngine(_value) //same as above.
{
    isEngineRunning = _value == 1 ? true : false;
}

function GetDistance(ent1, ent2)
{
    if(ent1 != null && ent2 != null)
    {
        local theLength = (ent1.GetOrigin() - ent2.GetOrigin()).Length();    
        return theLength;
    }
    return null;
}

function GetDistanceVector(ent1, ent2)
{
    if(ent1 != null && ent2 != null)
    {
        local theLength = (ent1 - ent2).Length();
        return theLength;
    }
    return null;
}

function FindEnemy()
{
    local survivors = GetSurvivors();
    local nearbiestVictim = null;
    local nearbiestVictimRange = searchRadius;
    if(survivors != null)
    {
        foreach(s in survivors)
        {
            local theDistance = GetDistance(self, s);
            if(theDistance < nearbiestVictimRange)
            {
                nearbiestVictim = s;
                nearbiestVictimRange = theDistance;
            }
            else continue;
        }
    }
    return nearbiestVictim;
}

function EnemyOutsideOfCar()
{
    if(currentEnemy == null)
    {
        return false;
    }
    if(currentEnemy.GetContext("InVehicle") == "No" || currentEnemy.GetContext("InVehicle") == null)
    {
        return true;
    }
    return false;
}

function EnemyNearby()
{
    if(currentEnemy != null)
    {
        return GetDistance(self, currentEnemy) <= 250;
    }
    return false
}

function UpdateStuckStatus()
{
    tryingToGetUnstuck = tryingToGetUnstuck == true ? false : true;
}

function AIUpdateNavigation()
{
    if (currentWayPoint == null) return;

    local myPos = self.GetOrigin();
    local dirToTarget = currentWayPoint - myPos;
    
    dirToTarget.z = 0.0;
    
    local distance = dirToTarget.Length();
    if (distance < 1.0) return;
    dirToTarget.Norm();

    if(tryingToGetUnstuck)
    {
        DoEntFire("!self", "Deactivate", "", 0.0, null, thrustForward);
        DoEntFire("!self", "Activate", "", 0.0, null, thrustBackward);
        DoEntFire("!self", "Activate", "", 0.0, null, thrustRight);
        DoEntFire("!self", "Deactivate", "", 0.0, null, thrustLeft);
        return;
    }

    local forwardVec = self.GetForwardVector();
    forwardVec.z = 0.0; forwardVec.Norm();

    // 1. Calculate angles in degrees
    local targetAngle  = atan2(dirToTarget.y, dirToTarget.x) * (180.0 / 3.14159265);
    local forwardAngle = atan2(forwardVec.y, forwardVec.x) * (180.0 / 3.14159265);

    // 2. Relative angle offset (-180 to +180)
    local deltaAngle = targetAngle - forwardAngle;
    while (deltaAngle > 180.0)  deltaAngle -= 360.0;
    while (deltaAngle < -180.0) deltaAngle += 360.0;

    // Thresholds
    local turnAngleThreshold = 30.0;  // Deadzone around nose center
    local reverseAngleCutoff = 110.0; // Angle threshold to engage reverse gear

    if(myLastOrigin != null)
    {
        if(myLastOriginTimer <= 0)
        {
            myLastOriginTimer = 2.0;
            myLastOrigin = self.GetOrigin();
        }
        else 
        {
            if(GetDistanceVector(myLastOrigin, self.GetOrigin()) < 25)
            {
                stuckTimer -= 0.05;
            }
            if(stuckTimer <= 0)
            {
                stuckTimer = 5.0;
                printl("WE ARE STUCK!");
                tryingToGetUnstuck = true;
                DoEntFire("!self", "RunScriptCode", "UpdateStuckStatus()", 2.00, null, self);
                return;
            }
        }
    }
    else 
    {
        myLastOrigin = self.GetOrigin();
    }

    // 3. Drive Logic (Fixed Nose-Forward Alignment)
    if (abs(deltaAngle) <= reverseAngleCutoff)
    {
        // --- FORWARD MODE (Nose towards waypoint) ---
        DoEntFire("!self", "Activate", "", 0.0, null, thrustForward);
        DoEntFire("!self", "Deactivate", "", 0.0, null, thrustBackward);

        // Positive deltaAngle = Waypoint is to the LEFT
        // Negative deltaAngle = Waypoint is to the RIGHT
        if (deltaAngle > turnAngleThreshold)
        {
            DoEntFire("!self", "Activate", "", 0.0, null, thrustRight);
            DoEntFire("!self", "Deactivate", "", 0.0, null, thrustLeft);
        }
        else if (deltaAngle < -turnAngleThreshold)
        {
            DoEntFire("!self", "Activate", "", 0.0, null, thrustLeft);
            DoEntFire("!self", "Deactivate", "", 0.0, null, thrustRight);
        }
        else
        {
            DoEntFire("!self", "Deactivate", "", 0.0, null, thrustLeft);
            DoEntFire("!self", "Deactivate", "", 0.0, null, thrustRight);
        }
    }
    else
    {
        // --- REVERSE MODE (Target is directly behind) ---
        DoEntFire("!self", "Deactivate", "", 0.0, null, thrustForward);
        DoEntFire("!self", "Activate", "", 0.0, null, thrustBackward);

        // When reversing, reverse steering polarity so rear swings toward target
        if (deltaAngle > turnAngleThreshold)
        {
            DoEntFire("!self", "Activate", "", 0.0, null, thrustLeft);
            DoEntFire("!self", "Deactivate", "", 0.0, null, thrustRight);
        }
        else if (deltaAngle < -turnAngleThreshold)
        {
            DoEntFire("!self", "Activate", "", 0.0, null, thrustRight);
            DoEntFire("!self", "Deactivate", "", 0.0, null, thrustLeft);
        }
        else
        {
            DoEntFire("!self", "Deactivate", "", 0.0, null, thrustLeft);
            DoEntFire("!self", "Deactivate", "", 0.0, null, thrustRight);
        }
    }
}

function SpawnInfectedAndStopTheCar()
{
    for(local i = 0; i < howManyInfected; i++)
    {
        ZSpawn({
        type = infectedType,
        pos = self.GetOrigin() + Vector(0, 0, 60),
        ang = QAngle(0, RandomInt(0, 360), 0)
        })
    }
    DoEntFire("!self", "Deactivate", "", 0.0, null, thrustLeft);
    DoEntFire("!self", "Deactivate", "", 0.0, null, thrustRight);
    DoEntFire("!self", "Deactivate", "", 0.0, null, thrustForward);
    DoEntFire("!self", "Deactivate", "", 0.0, null, thrustBackward);
    StopAmbientSoundOn("sfx/vehicles/police_siren02.wav", self);
    if(env_weaponfire != null)
    {
        DoEntFire("!self", "Kill", "", 0.02, null, env_weaponfire);
    }
    CatchOnFire();
    AddThinkToEnt(self, "") //since we got out of car, the car stops thinking
}

function VehicleThink()
{
    if (isDestroyed) return 1.0;

    foreach (slot, player in playersInVehicle)
    {
        if (player != null && player.IsValid())
        {
            if (player.GetButtonMask() & IN_JUMP)
            {
                GetOutVehicle(player);
            }
        }
    }

    if(NetProps.GetPropInt(breakableEntity, "m_iHealth") < 100 || breakableEntity == null)
    {
        CatchOnFire()
        return 0.05;
    }

    if (playersInVehicle.driver != null && !isDestroyed && !IsPlayerABot(playersInVehicle.driver))
    {
        if (vehicleFuel <= 0)
        {
            EmitAmbientSoundOn("ui/beep_error01.wav", 10, 150, 100, self);

            local players = GetPeopleSittingInsideCar()
            if(players != null)
            {
                foreach(player in GetPeopleSittingInsideCar())
                {
                    ClientPrint(player, 3, "\x04[VEHICLE]\x01 Out of fuel! Find a Gas Can to refill the car!");
                }
            }

            vehicleFuel = 0;
            ToggleEngine(0);
            ForceEveryoneGetOut();
        }
        else if(!lowGasWarningGiven && vehicleFuel < 30)
        {
            lowGasWarningGiven = true;
            local players = GetPeopleSittingInsideCar()
            if(players != null)
            {
                foreach(player in players)
                {
                    ClientPrint(player, 3, "\x04[VEHICLE]\x01 Warning: car will run off fuel soon!");
                }
            }
        }
    }
    else
    {
        if(GetPeopleSittingInsideCar() != null)
        {
            ForceEveryoneGetOut();
        }
        ToggleEngine(0)
    }

    if (isBurning && !isDestroyed)
    {
        currentVehicleHealth -= 0.5;
        //printl(currentVehicleHealth);
        if (currentVehicleHealth <= 0)
        {
            BlowUpVehicle();
            return -1;
        }
    }

    if(playersInVehicle.driver == null)
    {
        if(currentEnemy == null) //we dont have enemy??
        {
            currentWayPoint = null;
            local nearbyCriminal = FindEnemy();
            if(nearbyCriminal != null) 
            {
                if(nearbyCriminal.GetContext("InVehicle") == "Yes" || nearbyCriminal.GetContext("InVehicle") == null) //STOP RIGHT THERE CRIMINAL SCUM.
                {
                    currentWayPoint = nearbyCriminal.GetOrigin();
                    //DebugDrawBox(currentWayPoint, Vector(-10, -10, 10), Vector(10, 10, 10), 255, 255, 255, 255, 1.0);
                    if(AIType == 0)
                    {
                        //EmitAmbientSoundOn("sfx/vehicles/police_siren02.wav", 2, 85, RandomInt(90, 110), self); //too annoying.
                    }

                    currentEnemy = nearbyCriminal;
                    
                    return 0.05;
                }
                else if(EnemyOutsideOfCar() && EnemyNearby() && AIType == 0) //GET OUT OF THE CAR AND CHASE THEM
                {
                    SpawnInfectedAndStopTheCar();
                }
            }
            else //no new criminals either.
            {
                if(AIType == 0)
                {
                    StopAmbientSoundOn("sfx/vehicles/police_siren02.wav", self);
                }
                return 0.05;
            }
        }
        else //we have enemy and in on pursuit.
        {
            if(nextWayPointTimer <= 0)
            {
                nextWayPointTimer = 0.5;
                currentWayPoint = currentEnemy.GetOrigin();
                //DebugDrawBox(currentWayPoint, Vector(-10, -10, 10), Vector(10, 10, 10), 255, 255, 255, 255, 1.0);
            }

            local closestPlayer = null
            local nearbySurvivorFound = false;

            foreach(surv in GetSurvivors())
            {
                if(GetDistance(surv, self) <= despawnRadius)
                {
                    nearbySurvivorFound = true;
                    break;
                }
            }

            if (!nearbySurvivorFound)
            {
                printl("despawning police vehicle.");
                BlowUpVehicle();
                AddThinkToEnt(self, "");
                return;
            }

            AIUpdateNavigation()

            if(EnemyOutsideOfCar() && EnemyNearby() && AIType == 0)
            {
                SpawnInfectedAndStopTheCar();
            }
            nextWayPointTimer -= 0.05;
        }
    }

    return 0.05;
}
function SetRandomPaintJob()
{
    DoEntFire(self.GetName(), "color", paintJobs[RandomInt(0, paintJobs.len() - 1)], 0.00, null, null);
}

function SetCustomPaintJob(r = 255, g = 255, b = 255)
{
    DoEntFire(self.GetName(), "color", r.tostring() + " " + g.tostring() + " " + b.tostring(), 0.00, null, null);
}

function SetAIConfig(_ai = 0, searchRad = 1000, infected = 8, infamount = 2)
{
    AIType = _ai;
    searchRadius = searchRad; //1000 is ideal.
    infectedType = infected; //1 = SMOKER, 2 = BOOMER, 3 = HUNTER, 4 = SPITTER, 5 = JOCKEY, 6 = CHARGER, 7 = WITCH (really?), 8 = TANK
    howManyInfected = infamount; //never should be 0
}

function SetVehicleGasConfig(maxGas = 300, currentGas = 300, gasPerCan = 180)
{
    vehicleFuel = currentGas;
    maxFuel = maxGas;
    fuelPerGasCan = gasPerCan;
}

function SetVehicleHealthConfig(currentHp = 1000)
{
    NetProps.SetPropInt(breakableEntity, "m_iHealth", currentHp);
}

function SetSpeedScale(newSpeed = 8000) 
{
    //it doesn't work on left and right thrusters (fucks up the left and right controls)
    local thrusters = [Entities.FindByName(null, self.GetName() + "_forward"), Entities.FindByName(null, self.GetName() + "_backward")];
    
    foreach(thruster in thrusters)
    {
        if(thruster != null)
        {
            printl("Found phys_thruster!")
            thruster.__KeyValueFromInt("force", newSpeed);
        }   
    }
}

function DebugRemoveGas()
{
    vehicleFuel = 35;
}

AddThinkToEnt(self, "VehicleThink");