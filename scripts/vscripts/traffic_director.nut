//=======================================================================\\
//		Copyright TSP172 || https://steamcommunity.com/id/tsp172/        \\
// 		You can freely modify and use this script in any of your maps    \\
// 		        Made for L4D2, credit is appreciated				     \\
//=======================================================================\\

SPAWN_DIST_MIN <- 1000;
SPAWN_DIST_MAX <- 3500;

MAX_ALLOWED_VEHICLES <- 10;
CURRENT_VEHICLE_COUNT <- 0;
DESPAWN_IF_TOO_FAR <- false;
SLEEP_IF_TOO_FAR <- false;
DESPAWN_RADIUS <- 50000;
SLEEP_RADIUS <- 20000;
WAIT_TIME_TO_SPAWN_VEHICLE <- 2.0;
::VEHICLE_SPAWNERS <- []; //env_entity_makers go here

::AddToTheSpawnersList <- function()
{
    if (!("VEHICLE_SPAWNERS" in getroottable()))
    {
        VEHICLE_SPAWNERS <- [];
    }
    
    if (self != null && self.IsValid() && self.GetClassname() == "env_entity_maker")
    {
        VEHICLE_SPAWNERS.push(self);
    }
}


function AddOrRemoveFromTraffic(_number)
{
    CURRENT_VEHICLE_COUNT += _number
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

function GetAllVehicles() //ONLY VEHICLES THAT AITYPE IS 4 (Neutral / Civil)
{
    local ent = null;
    local vehicles = [];
    while ((ent = Entities.FindByClassname(ent, "prop_physics_multiplayer")) != null)
    {
        if (ent.IsValid() && ent.ValidateScriptScope())
        {
            local vehicleScope = ent.GetScriptScope();
            
            if (vehicleScope != null && ent.GetContext("VehicleAIMode") == "4")
            {
                vehicles.push(ent);
            }
        }
    }
    return vehicles;
}

function DeleteVehicles()
{
    foreach(vehicle in GetAllVehicles())
    {
        if (vehicle != null && vehicle.IsValid())
        {
            local vehicleScope = vehicle.GetScriptScope();
            
            if (vehicleScope != null)
            {
                if ("DeleteMe" in vehicleScope)
                {
                    DoEntFire("!self", "FireUser1", "", 0.00, null, vehicle);
                    DoEntFire("!self", "RunScriptCode", "DeleteMe()", 0.02, null, vehicle);
                }
            }
        }
    }
    CURRENT_VEHICLE_COUNT = 0; 
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
            
        if (dist >= minDistance && dist <= maxDistance && !navmesh.HasSpawnAttributes(1 << 19)) //navs marked with NO_THREAT is forbidden.
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

function TrafficThink()
{
    local nearestSpawnPoint = SelectRandomNavFromDistance(SPAWN_DIST_MIN, SPAWN_DIST_MAX, GetRandomSurvivor())
    if(CURRENT_VEHICLE_COUNT <= MAX_ALLOWED_VEHICLES && nearestSpawnPoint != null)
    {
        if (CURRENT_VEHICLE_COUNT >= MAX_ALLOWED_VEHICLES) return;

        if (VEHICLE_SPAWNERS.len() == 0) return;

        local selectedSpawner = VEHICLE_SPAWNERS[RandomInt(0, VEHICLE_SPAWNERS.len() - 1)];

        if (selectedSpawner != null && selectedSpawner.IsValid())
        {
            selectedSpawner.SetOrigin(nearestSpawnPoint.GetCenter() + Vector(0, 0, 10));
            //selectedSpawner.SetAngles(QAngle(0, RandomInt(0, 360), 0)); //<- this fucks up the thrusters...
            DoEntFire("!self", "ForceSpawn", "", 0.02, null, selectedSpawner);
            CURRENT_VEHICLE_COUNT++;
        }
    }

    local allVehicles = GetAllVehicles();

    if(allVehicles != null)
    {
        foreach(veh in allVehicles)
        {
            local closestPlayer = Entities.FindByClassnameNearest("player", veh.GetOrigin(), 9999999);

            if((veh.GetOrigin() - closestPlayer.GetOrigin()).Length() >= DESPAWN_RADIUS && DESPAWN_IF_TOO_FAR)
            {
                DoEntFire("!self", "FireUser1", "", 0.00, null, veh);
                DoEntFire("!self", "RunScriptCode", "DeleteMe()", 0.02, null, veh);
                CURRENT_VEHICLE_COUNT--
            }
            else if ((veh.GetOrigin() - closestPlayer.GetOrigin()).Length() >= SLEEP_RADIUS && SLEEP_IF_TOO_FAR)
            {
                DoEntFire("!self", "RunScriptCode", "SetAIState(0)", 0.00, null, veh);
            }
            else if((veh.GetOrigin() - closestPlayer.GetOrigin()).Length() <= SLEEP_RADIUS || !SLEEP_IF_TOO_FAR)
            {
                DoEntFire("!self", "RunScriptCode", "SetAIState(1)", 0.00, null, veh);
            }
        }
    }
    
    return WAIT_TIME_TO_SPAWN_VEHICLE;
}

function TrafficStart()
{
    AddThinkToEnt(self, "TrafficThink");
}

function TrafficStop()
{
    AddThinkToEnt(self, "");
}

function Configure(maxVehicles = 10, despawn = 0, sleep = 1, despawnRad = 50000, sleepRad = 20000, thinkTime = 2.0)
{
    MAX_ALLOWED_VEHICLES <- maxVehicles;
    DESPAWN_IF_TOO_FAR <- despawn == 1 ? true : false;
    SLEEP_IF_TOO_FAR <- sleep == 1 ? true : false;
    DESPAWN_RADIUS <- despawnRad;
    SLEEP_RADIUS <- sleepRad;
    WAIT_TIME_TO_SPAWN_VEHICLE <- thinkTime;
}

function ConfigureSpawnRadius(minRad = 1000, maxRad = 3500)
{
    SPAWN_DIST_MIN = minRad;
    SPAWN_DIST_MAX = maxRad;
}

function DebugGetActiveList()
{
    foreach(spawner in VEHICLE_SPAWNERS)
    {
        printl(spawner);
    }
}