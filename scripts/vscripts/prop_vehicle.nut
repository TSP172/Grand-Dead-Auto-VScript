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
2 - prop_physics_multiplayer for tires (4 of them)
3 - phys_ballsocket to attach tires to body prop
4 - phys_constraint to connect 2 tires in middle of vehicle (front and rear)
5 - phys_thruster entities to make the vehicle move (at least 4 of them) 
WARNING: ALSO NAME THEM SAME NAME AS VEHICLE BODY WITH "_forward", "_backward", "_left" "_right" PREFIXES ADDED TO LAST! CASE SENSITIVE
6 - game_ui to let players control vehicle (driver only)
7 - func_rot_button to press to make player hop in vehicle, also make it solid with clip tool brush (driver and seats)
WARNING: MAKE SURE YOU NAMED THIS SAME AS BODY PHYSICS MODEL WITH ADDING "_seat" ON NAME, LOWERCASE!
8 - phys_keepupright entity to prevent vehicle from flipping over.
9 - logic_relay with onspawn output to set values of seat origins.
10 - at least one player_weaponstrip entity named "strip_gascan" to strip gas can from player after trying to enter vehicle with gas can
11 - OPTIONAL: Sounds effects and lights for vehicle to give a nice touch.
12 - OPTIONAL: Add env_instructor_hint to explain controls or etc. (use instructorhint.nut to make visible to all players)

Rest will handled by this script.
*/

/* MUSIC TO MAYBE ADD LATER:
- Empty.
*/


//Music for players to listen to while driving a vehicle.
//musicPath = path to the music file, length = length of the music in seconds, title = title of the music track to print in chat
local staticSound = "radiomusic/radio_static.wav";
local radioTracks = [
    {musicPath = "#radiomusic/badtothebone.mp3", length = 300, title = "Bad to the Bone"},
    {musicPath = "#radiomusic/blameitoncoldone.mp3", length = 120, title = "Blame It on the Cold One"},
    {musicPath = "#radiomusic/bodies.mp3", length = 200, title = "Let the Bodies Hit the Floor"},
    {musicPath = "#radiomusic/chasingcars.mp3", length = 230, title = "Cars (Remastered 2009)"},
    {musicPath = "#radiomusic/dancehalldays.mp3", length = 235, title = "Dance Hall Days"},
    {musicPath = "#radiomusic/diedinyourarms.mp3", length = 270, title = "I Just Died in Your Arms"},
    {musicPath = "#radiomusic/dmitri_waltzno2.mp3", length = 225, title = "Dmitri Waltz No. 2"},
    {musicPath = "#radiomusic/doc_funkyenough.mp3", length = 270, title = "D.O.C. - Funky Enough"},
    {musicPath = "#radiomusic/downunder.mp3", length = 220, title = "Men at Work - Down Under"},
    {musicPath = "#radiomusic/electricavenue.mp3", length = 195, title = "Electric Avenue"},
    {musicPath = "#radiomusic/funkykingston.mp3", length = 205, title = "The Toots - Funky Kingston"},
    {musicPath = "#radiomusic/growsup_djquads.mp3", length = 210, title = "DJ Quads - Grows Up"},
    {musicPath = "#radiomusic/heyyou.mp3", length = 225, title = "Hey You - The Rock Steady Crew"},
    {musicPath = "#radiomusic/hookedonafeeling.mp3", length = 170, title = "Hooked on a Feeling"},
    {musicPath = "#radiomusic/ruletheworld.mp3", length = 250, title = "Everybody Wants to Rule the World"},
    {musicPath = "#radiomusic/michaeljackson_dontstop.mp3", length = 255, title = "Michael Jackson - Don't Stop 'Til You Get Enough"},
    {musicPath = "#radiomusic/myway.mp3", length = 275, title = "My Way"},
    {musicPath = "#radiomusic/nevertoomuch.mp3", length = 230, title = "Never Too Much"},
    {musicPath = "#radiomusic/gorillaz_2000.mp3", length = 202, title = "Gorillaz - 19 - 2000"},
    {musicPath = "#radiomusic/numanuma.mp3", length = 210, title = "Numa Numa"},
    {musicPath = "#radiomusic/paranoid.mp3", length = 165, title = "Paranoid"},
    {musicPath = "#radiomusic/gotohell.mp3", length = 310, title = "Go to Hell"},
    {musicPath = "#radiomusic/onmyway.mp3", length = 215, title = "I'm on my Way"},
    {musicPath = "#radiomusic/polkaface.mp3", length = 285, title = "Polka Face"},
    {musicPath = "#radiomusic/breakmystride.mp3", length = 180, title = "Break my Stride"},
    {musicPath = "#radiomusic/saintpepsi_better.mp3", length = 230, title = "Saint Pepsi - Better"},
    {musicPath = "#radiomusic/scatman.mp3", length = 210, title = "Scatman"},
    {musicPath = "#radiomusic/shesonfire.mp3", length = 215, title = "She's on Fire"},
    {musicPath = "#radiomusic/los_toreadors.mp3", length = 135, title = "Los toreadors"}, 
    {musicPath = "#radiomusic/symphony_no16.mp3", length = 195, title = "Symphony - No.16"}, 
    {musicPath = "#radiomusic/stayinalive.mp3", length = 240, title = "Stayin Alive"},
    {musicPath = "#radiomusic/tequila.mp3", length = 130, title = "Tequila"},
    {musicPath = "#radiomusic/vamosabailar.mp3", length = 220, title = "Vamos a Bailar"},
    {musicPath = "#radiomusic/verdilatraviata.mp3", length = 180, title = "Verdila La Traviata"},
    {musicPath = "#radiomusic/violence.mp3", length = 200, title = "Violence - Fall to Break"},
    {musicPath = "#radiomusic/wherethehoodat.mp3", length = 265, title = "Where the Hood At"},
    {musicPath = "#radiomusic/whitewedding.mp3", length = 205, title = "White Wedding"},
    {musicPath = "#radiomusic/workforweekend.mp3", length = 220, title = "Loverboy - Working for the Weekend"},
]

function ShuffleRadio() 
{
    srand(Time());

    local len = radioTracks.len();
    if (len <= 1) return;

    for (local i = len - 1; i > 0; i--) 
    {
        local j = rand() % (i + 1);
        
        local temp = radioTracks[i];
        radioTracks[i] = radioTracks[j];
        radioTracks[j] = temp;
    }
}

function Precache()
{
    self.PrecacheScriptSound(staticSound);
    foreach (track in radioTracks)
    {
        PrecacheSound(track.musicPath);
    }
}

Precache();
ShuffleRadio();

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

//=========== RADIO STATION CONFIG ===========//
local supportsRadio = true;
local CurrentRadioIndex = -1;
local currentTrack = null;
//local nextTrackTimer = 10;
local radioSwitchDelay = 2.0; //seconds to wait before switching to next track

//=========== CONTROL CONSTANTS ===========//
const IN_JUMP = 2; //this will used to make player hop off the vehicle (inluding driver)
const IN_ATTACK2 = 2048; //this will used to make player skip to next radio track (driver only)

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

local vehicleFuel = 180.0; // Seconds of fuel remaining
local maxFuel = 300.0; //seconds of max fuel allowed
local fuelPerGasCan = 60.0; //how much gas (in seconds) will gas can gonna give us?
local isEngineRunning = false; //set this false at first to prevent gas being consumed while nobody inside car.
local lowGasWarningGiven = false;

//=========== HEALTH CONFIG ===========//

local maxVehicleHealth = 1000;
local currentVehicleHealth = 1000; //if vehicle health gets 100 or under, the catch on fire.
local isBurning = false;
local isDestroyed = false;

function SetCapacity(capacity) 
{
    if(capacity < 1 || capacity > 4) {
        printl("Vehicle capacity must be between 1 and 4");
        return;
    }
    vehicleCapacity = capacity;
}

function GetBotSurvivors()
{
    for(local ent = null; ( ent = Entities.FindByClassname( ent , "player" ) ) != null; ){
        if(ent != null && ent.IsValid() && ent.GetZombieType() == 9 && IsPlayerABot(ent)){
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

    foreach (botSurvivor in GetBotSurvivors())
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
            botSurvivor.SetContext("InVehicle", "Yes", -1);
            NetProps.SetPropInt(botSurvivor, "movetype", 0);
            botSurvivor.SetOrigin(vehOrigin + passangerSeat1Offset);
            DoEntFire("!self", "SetParent", self.GetName(), 0.00, null, botSurvivor);
            printl("Bot Passenger 1 entered vehicle: " + botSurvivor.GetPlayerName());
        }
        // Seat 2
        else if (vehicleCapacity >= 3 && passangerSeat2Offset != null && playersInVehicle.passanger2 == null)
        {
            playersInVehicle.passanger2 = botSurvivor;
            botSurvivor.SetContext("InVehicle", "Yes", -1);
            NetProps.SetPropInt(botSurvivor, "movetype", 0);
            botSurvivor.SetOrigin(vehOrigin + passangerSeat2Offset);
            DoEntFire("!self", "SetParent", self.GetName(), 0.00, null, botSurvivor);
            printl("Bot Passenger 2 entered vehicle: " + botSurvivor.GetPlayerName());
        }
        // Seat 3
        else if (vehicleCapacity >= 4 && passangerSeat3Offset != null && playersInVehicle.passanger3 == null)
        {
            playersInVehicle.passanger3 = botSurvivor;
            botSurvivor.SetContext("InVehicle", "Yes", -1);
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
        DoEntFire(self.GetName() + "_gameui", "Activate", "", 0, activator, null);
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

    // Unbind Measure Movement entity and deactivate game_ui if driver
    if (foundSlot == "driver")
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
    if(GetSurvivors() != null)
    {
        foreach(survivor in GetSurvivors())
        {
            GetOutVehicle(survivor)
        }
    }
}

function CatchOnFire()
{
    if(isBurning)
    {
        return;
    }

    currentVehicleHealth = 100;

    local fireParticle = SpawnEntityFromTable("info_particle_system", {
        effect_name = "fire_jet_01",
        parent = self,
        start_active = 1,
        origin = self.GetOrigin()
    })

    DoEntFire("!self", "SetParent", self.GetName(), 0.02, null, fireParticle)

    isBurning = true;
    StopVehicleRadio()

    EmitAmbientSoundOn("ambient/fire/interior_fireclose03_mono.wav", 10, 150, 100, self);
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

    ForceEveryoneGetOut();

    DoEntFire("!self", "color", "0 0 0", 0.00, null, self);
    DoEntFire("!self", "Explode", "", 0.05, null, explosionEntity);
    DoEntFire("!self", "Kill", "0 0 0", 5, null, explosionParticleEntity);
    EntFire(self.GetName() + "_seat", "Kill", "", 0, null); //kill seat entity to prevent getting in again.

    DoEntFire("!self", "Kill", "0 0 0", 15, null, self);
    
    AddThinkToEnt(self, ""); //stop thinking.
}

function AllowTakeDamage(damageTable)
{
    local attacker = damageTable.Attacker;

    if(isBurning) return;

    printl("VEHICLE TOOK DAMAGE!")
    
    if (attacker != null && attacker.IsValid() && attacker.GetClassname() == "player")
    {
        // Check if attacker is Tank (Zombie class 8)
        if (attacker.GetZombieType() == 8)
        {
            currentVehicleHealth = 100;
            
            printl("TANK PUNCHED THE VEHICLE!");

            return true;
        }
        else if(attacker.GetZombieType() != 9)
        {
            currentVehicleHealth -= RandomInt(20, 60)
        }
    }
    else if (attacker != null && attacker.IsValid() && attacker.GetClassname() == "infected")
    {
        currentVehicleHealth -= RandomInt(5, 15)
    }
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

function CheckIfHasGasCan(survivor)
{
    if (survivor == null || !survivor.IsValid())
    {
        return false;
    }

    local activeWeapon = survivor.GetActiveWeapon();
    
    if (activeWeapon != null && activeWeapon.IsValid())
    {
        if (activeWeapon.GetClassname() == "weapon_gascan")
        {
            return true;
        }
    }

    return false;
}

function CheckNearbyGasCan()
{
    if(GetSurvivors() == null)
    {
        return false;
    }

    foreach(survivor in GetSurvivors())
    {
        local distance = (self.GetOrigin() - survivor.GetOrigin()).Length()
        if(CheckIfHasGasCan(survivor) && distance < 125)
        {
            EntFire("strip_gascan", "StripActiveWeapon", null, 0, survivor);
            RefuelVehicle();
            return true;
        }
    }
}

function ConsumeFuel()
{
    if(isEngineRunning)
    {
        vehicleFuel -= 0.05;
        //printl("Current Gas: " + vehicleFuel);
    }
}

function ToggleEngine(_value)
{
    isEngineRunning = _value == 1 ? true : false;
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
            if ((player.GetButtonMask() & IN_ATTACK2) && slot == "driver" && radioSwitchDelay <= 0)
            {
                ToggleOrNextRadioTrack();
            }
        }
    }

    CheckNearbyGasCan();

    if (playersInVehicle.driver != null && vehicleFuel > 0 && !isDestroyed && !IsPlayerABot(playersInVehicle.driver))
    {
        ConsumeFuel()

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

    if(!isBurning && currentVehicleHealth <= 100)
    {
        CatchOnFire();
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

    if(radioSwitchDelay > 0)
    {
        radioSwitchDelay -= 0.05; // Decrease delay timer
    }
    /*
    if(nextTrackTimer <= 0)
    {
        ToggleOrNextRadioTrack()
        nextTrackTimer = 10.0;
    }
    else if(currentTrack != null)
    {
        nextTrackTimer -= 0.05;
    }
    */

    return 0.05;
}

function RadioSupport(value) //toggle this with logic_relay if your vehicle supports radio or not.
{
    if(value == 1) 
    {
        supportsRadio = true;
    } 
    else 
    {
        supportsRadio = false;
    }
}

function ToggleOrNextRadioTrack()
{
    if (!supportsRadio || radioTracks.len() == 0) 
    {
        StopAmbientSoundOn(staticSound, self);
        if(currentTrack != null)
        {
            StopAmbientSoundOn(currentTrack, self);
        }
        return;
    }
    StopVehicleRadio();

    radioSwitchDelay = 2.0;
    EmitAmbientSoundOn(staticSound, 10, 150, 100, self);
    
    local staticWait = RandomFloat(0.8, 1.5);
    DoEntFire("!self", "RunScriptCode", "NextTrack()", staticWait, null, self);
}

function NextTrack()
{
    if(!supportsRadio)
    {
        return;
    }

    StopAmbientSoundOn(staticSound, self);

    if (GetCurrentOccupantCount() == 0)
    {
        StopVehicleRadio();
        return;
    }

    CurrentRadioIndex = (CurrentRadioIndex + 1) % radioTracks.len();
    local track = radioTracks[CurrentRadioIndex];
    //nextTrackTimer = track.length;
    currentTrack = track;

    EmitAmbientSoundOn(track.musicPath, 10, 150, 100, self);

    foreach (slot, player in playersInVehicle)
    {
        if (player != null && player.IsValid())
        {
            ClientPrint(player, DirectorScript.HUD_PRINTTALK, "\x04[Radio]\x05 Now Playing: \x01" + track.title);
        }
    }
}

function StopVehicleRadio()
{
    StopAmbientSoundOn(staticSound, self);
    if (currentTrack != null)
    {
        StopAmbientSoundOn(currentTrack.musicPath, self);
        currentTrack = null;
    }
}

function SetRandomPaintJob()
{
    DoEntFire(self.GetName(), "color", paintJobs[RandomInt(0, paintJobs.len() - 1)], 0.00, null, null);
}

function SetCustomPaintJob(r = 255, g = 255, b = 255)
{
    DoEntFire(self.GetName(), "color", r.tostring() + " " + g.tostring() + " " + b.tostring(), 0.00, null, null);
}

function SetVehicleGasConfig(maxGas = 300, currentGas = 300, gasPerCan = 180)
{
    vehicleFuel = currentGas;
    maxFuel = maxGas;
    fuelPerGasCan = gasPerCan;
}

function SetVehicleHealthConfig(maxHp = 1000, currentHp = 1000)
{
    maxVehicleHealth = maxHp;
    currentVehicleHealth = currentHp; 
    DoEntFire("!self", "SetHealth", maxHp.tostring(), 0.01, null, self);
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

DoEntFire("!self", "SetHealth", maxVehicleHealth.tostring(), 0.01, null, self);

AddThinkToEnt(self, "VehicleThink");