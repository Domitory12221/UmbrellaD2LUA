--[[
Ivanius51 13.07.2016 АвтоДенай крипов + подсвечивание
22.07.2016 Убрал спам атаки
04.02.2017 Переработана формула расчтеа учитвая последние патчи
25.02.2018 - 30.02.2018 Переведено на LUA, добавлено правильное предсказание, изменены настройки
-----------------------------------------------
  ______     __   _____                _        _____ _____ __ 
 |  _ \ \   / /  |_   _|              (_)      / ____| ____/_ |
 | |_) \ \_/ /     | |_   ____ _ _ __  _ _   _| (___ | |__  | |
 |  _ < \   /      | \ \ / / _` | '_ \| | | | |\___ \|___ \ | |
 | |_) | | |      _| |\ V / (_| | | | | | |_| |____) |___) || |
 |____/  |_|     |_____\_/ \__,_|_| |_|_|\__,_|_____/|____/ |_|
                                                               
http://GetScript.Net
-----------------------End---------------------
Is licensed under the
GNU General Public License v3.0

----------------------TODO---------------------
Priority creeps, by calculate PossiblyMissedDPS on DmgTime + AttackTime
--TODO: rewrite - dont calculate it, write it every...

local Game = {};
function Game.AttackTarget(target, entity, queue)
	if type(target) ~= "number" then
		error("no target");
	end;
	return Player.PrepareUnitOrders(Players.GetLocal(), Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET, target, Vector(0, 0, 0), nil, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, entity or nil, queue or false);
end;
function Game.MoveTo(xyz, entity, queue)
	if xyz == nil then
		return
	end;
	return Player.PrepareUnitOrders(Players.GetLocal(), Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, xyz, nil, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, entity or nil, queue or false);
end;
--]]

--LUA additional functions
-- Convert a lua table into a lua syntactically correct string
function table.tostring(list)
	local result = "{";
	for k, v in pairs(list) do
			-- Check the key type (ignore any numerical keys - assume its an array)
			if type(k) == "string" then
					result = result.."[\""..k.."\"]".."=";
			end;

			-- Check the value type
			if type(v) == "table" then
					result = result..table.tostring(v);
			elseif type(v) == "boolean" then
					result = result..tostring(v);
			else
					result = result.."\""..v.."\"";
			end;
			result = result..",";
	end;
	-- Remove leading commas from the result
	if result ~= "" then
			result = result:sub(1, result:len()-1);
	end;
	return result.."}";
end;

table.reduce = function (list, fn, count) 
	local acc
	for k, v in ipairs(list) do
		if 1 == k then
			acc = v;
		else
			acc = fn(acc, v);
		end; 
		if k>= count then
			break;
		end;
	end;
	return acc;
end;

function table.sum(list, count)
	if not count then
		count = #table;
	end;
	return 
		table.reduce(
			list,
			function (a, b)
				return a + b
			end,
			count
		);
end;

function RoundNumber(num, idp)
	local mult = 10^(idp or 0);
	return math.floor(num * mult + 0.5) / mult;
end

function VectorDistance (a, b)
	local diff = Vector(a:GetX() - b:GetX(), a:GetY() - b:GetY(), a:GetZ() - b:GetZ());
	return math.sqrt(math.pow(diff:GetX(), 2) + math.pow(diff:GetY(), 2) + math.pow(diff:GetZ(), 2));
end;
function NPC.Distance (a, b)
	local av = Entity.GetAbsOrigin(a);
	local bv = Entity.GetAbsOrigin(b);
	return VectorDistance(av, bv);
end;
--LUA additional functions

local HeroInfo = require("scripts.settings.HeroInfo");

local LastHitCreep = {};
LastHitCreep.Menu = {};
LastHitCreep.User = {};
LastHitCreep.Particles = {};
LastHitCreep.SkillModifiers = {
	["modifier_item_quelling_blade"]= {1.4},
	["modifier_item_bfury"] = {1.6},
	["modifier_item_iron_talon"] = {1.4},
	["modifier_bloodseeker_bloodrage"] = {1.25,1.3,1.35,1.4}
}

LastHitCreep.Menu.Path = {"Utility", "Last Hit Creep"};
LastHitCreep.Menu.Path.CreepTypes = {"Utility", "Last Hit Creep", "Creep Types"};
LastHitCreep.Menu.Enabled = Menu.AddOptionBool(LastHitCreep.Menu.Path, "Enabled", false);
LastHitCreep.Menu.Education = Menu.AddOptionBool(LastHitCreep.Menu.Path, "Education Mode", false);
LastHitCreep.Menu.AttackMove = Menu.AddOptionBool(LastHitCreep.Menu.Path, "Attack Move", false);
LastHitCreep.Menu.Prediction = Menu.AddOptionBool(LastHitCreep.Menu.Path, "Prediction", false);
LastHitCreep.Menu.LastHitKey = Menu.AddKeyOption(LastHitCreep.Menu.Path, "Last Hit Key", Enum.ButtonCode.KEY_P);
LastHitCreep.Menu.Enemys = Menu.AddOptionBool(LastHitCreep.Menu.Path.CreepTypes, "Kill Enemys", false);
LastHitCreep.Menu.Friendlys = Menu.AddOptionBool(LastHitCreep.Menu.Path.CreepTypes, "Deny Friendlys", false);
LastHitCreep.Menu.Neutrals = Menu.AddOptionBool(LastHitCreep.Menu.Path.CreepTypes, "Kill Neutrals", false);

LastHitCreep.Particles = {};
LastHitCreep.Particles.Target = {};
LastHitCreep.Creeps = nil;
LastHitCreep.CreepsDPS = {};
LastHitCreep.UpdateTime = 0.20;
LastHitCreep.DPSMult = (1 / LastHitCreep.UpdateTime);

--menu options
function LastHitCreep.isEnabled()
	return Menu.IsEnabled(LastHitCreep.Menu.Enabled);
end;
function LastHitCreep.isHitKeyDown()
	return Menu.IsKeyDown(LastHitCreep.Menu.LastHitKey);
end;
function LastHitCreep.isEducation()
	return Menu.IsEnabled(LastHitCreep.Menu.Education);
end;
function LastHitCreep.isAttackMove()
	return Menu.IsEnabled(LastHitCreep.Menu.AttackMove);
end;
function LastHitCreep.isPrediction()
	return Menu.IsEnabled(LastHitCreep.Menu.Prediction);
end;
function LastHitCreep.isKillEnemys()
	return Menu.IsEnabled(LastHitCreep.Menu.Enemys);
end;
function LastHitCreep.isDenyFriendlys()
	return Menu.IsEnabled(LastHitCreep.Menu.Friendlys);
end;
function LastHitCreep.isKillNeutrals()
	return Menu.IsEnabled(LastHitCreep.Menu.Neutrals);
end;
--end menu options

function LastHitCreep.User.Read()
	LastHitCreep.User.Hero = Heroes.GetLocal();
	if not LastHitCreep.User.Hero then
		return false;
	end;
	
	LastHitCreep.User.Name = NPC.GetUnitName(LastHitCreep.User.Hero);
	LastHitCreep.User.AttackPoint = HeroInfo[LastHitCreep.User.Name].AttackPoint + 0.05;
	LastHitCreep.User.AttackBackSwing = HeroInfo[LastHitCreep.User.Name].AttackBackSwing;
	LastHitCreep.User.AttackTime = NPC.GetAttackTime(LastHitCreep.User.Hero);-- + LastHitCreep.User.AttackPoint;-- + LastHitCreep.User.AttackBackSwing;
	LastHitCreep.User.Damage = NPC.GetTrueDamage(LastHitCreep.User.Hero);
	LastHitCreep.User.MaximumDamage = NPC.GetTrueMaximumDamage(LastHitCreep.User.Hero);
	LastHitCreep.User.ProjectileSpeed = 10000;
	if NPC.IsRanged(LastHitCreep.User.Hero) then
		LastHitCreep.User.TrueDamage = LastHitCreep.User.Damage + math.ceil((LastHitCreep.User.MaximumDamage - LastHitCreep.User.Damage) / 4);
		LastHitCreep.User.ProjectileSpeed = HeroInfo[LastHitCreep.User.Name].ProjectileSpeed;
	else
		LastHitCreep.User.TrueDamage = LastHitCreep.User.Damage-1;
		LastHitCreep.User.AttackPoint = LastHitCreep.User.AttackPoint;-- - LastHitCreep.User.AttackPoint / 2;
	end;
	LastHitCreep.User.Range = NPC.GetAttackRange(LastHitCreep.User.Hero) + NPC.GetHullRadius(LastHitCreep.User.Hero);
	LastHitCreep.User.MoveSpeed = NPC.GetMoveSpeed(LastHitCreep.User.Hero);
	return true;
end;

function LastHitCreep.Initialization()
	math.randomseed(os.time());
	LastHitCreep.User.Read();
	LastHitCreep.User.LastTarget = nil;
	LastHitCreep.User.LastAttackTime = os.clock();
	LastHitCreep.User.LastUpdateTime = os.clock();
	LastHitCreep.User.LastMoveTime = os.clock();
	for k in pairs(LastHitCreep.Particles) do
		LastHitCreep.Particles[k] = nil;
	end;
	--Log.Write(NPC.GetUnitName(LastHitCreep.User.Hero).." "..tostring(HeroInfo[NPC.GetUnitName(LastHitCreep.User.Hero)].AttackPoint));
end;

function LastHitCreep.Finalization()
	LastHitCreep.User.Hero = nil;
	for k in pairs(LastHitCreep.Particles) do
		LastHitCreep.ClearParticle(k);
	end;
end;
--particles
function LastHitCreep.CreateOverheadParticle(index, ent, name)
	if (ent == nil) then
		return false;
	end;
	if (LastHitCreep.Particles[tonumber(index)] == nil) then
		LastHitCreep.Particles[tonumber(index)] = {};
		LastHitCreep.Particles[tonumber(index)].ID = Particle.Create(name, Enum.ParticleAttachment.PATTACH_OVERHEAD_FOLLOW, ent);
		return true;
	end;
	return false;
end;

function LastHitCreep.CreateTargetingParticle(caster, target)
	if (caster == nil) or (target == nil) then
		return false;
	end;
	local newParicle = 0;
	if (LastHitCreep.Particles[caster] == nil) then
		LastHitCreep.Particles[caster] = {};
		newParicle = Particle.Create("particles/ui_mouseactions/range_finder_tower_aoe.vpcf", Enum.ParticleAttachment.PATTACH_ABSORIGIN_FOLLOW, target);
	else
		if (LastHitCreep.Particles[caster].ID ~= nil) then
			Particle.Destroy(LastHitCreep.Particles[caster].ID);
		end;
		newParicle = Particle.Create("particles/ui_mouseactions/range_finder_tower_aoe.vpcf", Enum.ParticleAttachment.PATTACH_ABSORIGIN_FOLLOW, target);
	end;
	if newParicle ~= 0 then
		Particle.SetControlPoint(newParicle, 2, Entity.GetOrigin(caster));
		Particle.SetControlPoint(newParicle, 6, Vector(1, 0, 0));
		Particle.SetControlPoint(newParicle, 7, Entity.GetOrigin(target));
		LastHitCreep.Particles[caster].ID = newParicle;
		LastHitCreep.Particles[caster].Target = target;
		return true;
	end;
	return false;
end;

function LastHitCreep.ClearParticle(index)
	if (LastHitCreep.Particles[tonumber(index)] ~= nil) then
		Particle.Destroy(LastHitCreep.Particles[tonumber(index)].ID);
		LastHitCreep.Particles[tonumber(index)] = nil;
	end;
end;
--end particles

--[[
function LastHitCreep.GetMeleeCreepTarget(hero, creep)

	if not hero or not creep or not Entity.IsNPC(creep) or not NPC.IsLaneCreep(creep) or not Entity.IsAlive(creep) then 
		return 
	end;

	if NPC.IsRanged(creep) then return end;

	local creepRotation = Entity.GetRotation(creep):GetForward():Normalized();
	
	local targets = Entity.GetUnitsInRadius(creep, 148, Enum.TeamType.TEAM_ENEMY)
		if next(targets) == nil then 
			return; 
		end;
		if #targets < 1 then 
			return; 
		end;

	if #targets == 1 then
		if Entity.IsNPC(targets[1]) and NPC.IsLaneCreep(targets[1]) then
			return targets[1];
		end;
	else
		local adjustedHullSize = 20;
		for i, npc in ipairs(targets) do
			if npc and Entity.IsNPC(npc) and NPC.IsLaneCreep(npc) and Entity.IsAlive(npc) then
				local npcpos = Entity.GetAbsOrigin(npc);
				local npcposZ = npcpos:GetZ();
				local pos = Entity.GetAbsOrigin(creep);
				for i = 1, 9 do
					local searchPos = pos + creepRotation:Scaled(25*(9-i));
					searchPos:SetZ(npcposZ);
					if NPC.IsPositionInRange(npc, searchPos, adjustedHullSize, 0) then
						return npc;
					end;
				end;
			end;
		end;
	end;
	return;
end;
]]--

function LastHitCreep.CalcAttackTime()
	local increasedAS = NPC.GetIncreasedAttackSpeed(LastHitCreep.User.Hero);
	local attackTime = LastHitCreep.User.AttackTime;
	local attackPoint = LastHitCreep.User.AttackPoint;
	local attackSpeed = attackPoint / (1 + (increasedAS/100));
	local attackTime = attackSpeed + (attackPoint * 0.17);
	return attackTime;
end;

function LastHitCreep.OnUpdate()
	if not LastHitCreep.isEnabled() then
		return;
	end;
	LastHitCreep.User.Hero = Heroes.GetLocal();
	if (LastHitCreep.User.Hero == nil) or not Entity.IsAlive(LastHitCreep.User.Hero) then 
		return;
	end;

	--
	if ((os.clock() - LastHitCreep.User.LastUpdateTime) > LastHitCreep.UpdateTime) then
		--update user data
		if not LastHitCreep.User.Read() then
			return;
		end;
		--calculate DPS
		--TODO: rewrite - dont calculate it, write it every...
		LastHitCreep.User.LastUpdateTime = os.clock();
		LastHitCreep.Creeps = Entity.GetUnitsInRadius(LastHitCreep.User.Hero, LastHitCreep.User.Range + 350, Enum.TeamType.TEAM_BOTH);
		for k, npc in ipairs(LastHitCreep.Creeps) do
			if Entity.IsAlive(npc) and NPC.IsLaneCreep(npc) then
				--todo incapsulate it
				if LastHitCreep.CreepsDPS[npc] == nil then
					LastHitCreep.CreepsDPS[npc] = {};
					LastHitCreep.CreepsDPS[npc].CurHP = math.floor(Entity.GetHealth(npc) + NPC.GetHealthRegen(npc));
					LastHitCreep.CreepsDPS[npc].OldHP = LastHitCreep.CreepsDPS[npc].CurHP;
					LastHitCreep.CreepsDPS[npc].DPS = -1; 
					LastHitCreep.CreepsDPS[npc].Damage = {}; 
				else
					LastHitCreep.CreepsDPS[npc].OldHP = LastHitCreep.CreepsDPS[npc].CurHP;
					LastHitCreep.CreepsDPS[npc].CurHP = math.floor(Entity.GetHealth(npc) + NPC.GetHealthRegen(npc));
					local curDPS = (LastHitCreep.CreepsDPS[npc].OldHP-LastHitCreep.CreepsDPS[npc].CurHP);
					--if curDPS then
						table.insert(LastHitCreep.CreepsDPS[npc].Damage, curDPS);
					--end;
					if (#LastHitCreep.CreepsDPS[npc].Damage > (LastHitCreep.DPSMult * 2)) then
						table.remove(LastHitCreep.CreepsDPS[npc].Damage,1);
					end;
					--[[
					curDPS = math.ceil(curDPS * LastHitCreep.DPSMult);
					if (LastHitCreep.CreepsDPS[npc].DPS == -1) then
						LastHitCreep.CreepsDPS[npc].DPS = curDPS;
					else
						--dps move to current dps
						--if curDPS~=0 then
							LastHitCreep.CreepsDPS[npc].DPS = math.floor((LastHitCreep.CreepsDPS[npc].DPS + curDPS) / 2);
						--end;
					end;
					]]
				end;
			end;
		end;
		--find creep to kill
	end;
	
	if ((os.clock() - LastHitCreep.User.LastAttackTime) > LastHitCreep.User.AttackTime) then
		if (LastHitCreep.isEducation()) then
			LastHitCreep.User.AttackTime = 0.05;
		else
			LastHitCreep.User.AttackTime = NPC.GetAttackTime(LastHitCreep.User.Hero);
		end;
		LastHitCreep.Creeps = Entity.GetUnitsInRadius(LastHitCreep.User.Hero, LastHitCreep.User.Range + 350, Enum.TeamType.TEAM_BOTH);
		
		--check last target
		if LastHitCreep.User.LastTarget and Entity.IsEntity(LastHitCreep.User.LastTarget) and Entity.IsAlive(LastHitCreep.User.LastTarget) then
			Log.Write("LT HP Next="..math.floor(Entity.GetHealth(LastHitCreep.User.LastTarget) + NPC.GetHealthRegen(LastHitCreep.User.LastTarget)));
		end;
		--find "right" npc to kill
		for k, npc in ipairs(LastHitCreep.Creeps) do
			if Entity.IsEntity(npc) and Entity.IsAlive(npc) and NPC.IsLaneCreep(npc) and
			( (not Entity.IsSameTeam(npc, LastHitCreep.User.Hero)and LastHitCreep.isKillEnemys()) or (Entity.IsSameTeam(npc, LastHitCreep.User.Hero) and LastHitCreep.isDenyFriendlys()) )
			 then
				local TrueDMG = math.floor(math.floor(NPC.GetDamageMultiplierVersus(LastHitCreep.User.Hero, npc) * ((LastHitCreep.User.Damage + NPC.GetBonusDamage(LastHitCreep.User.Hero)) * NPC.GetArmorDamageMultiplier(npc))) * 0.975);
				--math.ceil(NPC.GetArmorDamageMultiplier(npc) * LastHitCreep.User.TrueDamage);--
				--
				if not Entity.IsSameTeam(npc, LastHitCreep.User.Hero) then
					--TrueDMG = TrueDMG * NPC.GetDamageMultiplierVersus(LastHitCreep.User.Hero, npc)
			 	end;
				local dist =  NPC.Distance(npc, LastHitCreep.User.Hero);
				local DMGStartTime = NPC.GetTimeToFace(LastHitCreep.User.Hero, npc);
				local DMGEndTime = LastHitCreep.User.AttackPoint;
				local DPS =  1;

				if NPC.IsRanged(LastHitCreep.User.Hero) then
					DMGStartTime = DMGStartTime;-- + 0.05; 
				else
					DMGStartTime = DMGStartTime;-- + 0.01;
				end;
				if (dist>LastHitCreep.User.Range) then
					DMGStartTime = DMGStartTime + (math.ceil(dist-LastHitCreep.User.Range)/LastHitCreep.User.MoveSpeed);
					dist = LastHitCreep.User.Range;
				end;
				if NPC.IsRanged(LastHitCreep.User.Hero) then
					DMGEndTime = DMGEndTime + (dist / LastHitCreep.User.ProjectileSpeed);
					local DPS =  35;
				else
					DMGEndTime = LastHitCreep.CalcAttackTime() + 0.1;
					local DPS =  25;
				end;
				local DMGTime = DMGStartTime + DMGEndTime;
				local HP = math.floor(Entity.GetHealth(npc) + NPC.GetHealthRegen(npc) * DMGTime);
				
				local PossiblyMissedDPS = math.floor(DPS * DMGTime);
				if LastHitCreep.isPrediction() and LastHitCreep.CreepsDPS[npc] and LastHitCreep.CreepsDPS[npc].Damage and (#LastHitCreep.CreepsDPS[npc].Damage >= LastHitCreep.DPSMult) then
					DPS = math.floor(table.sum(LastHitCreep.CreepsDPS[npc].Damage) / 2);--LastHitCreep.CreepsDPS[npc].DPS;
					PossiblyMissedDPS = table.sum(LastHitCreep.CreepsDPS[npc].Damage,(RoundNumber(DMGTime,1) * LastHitCreep.DPSMult) );
				end;
				if ( (HP < (TrueDMG + PossiblyMissedDPS)) ) then
					--Log.Write("HP="..HP.." DMG="..TrueDMG.." PMD="..PossiblyMissedDPS.." DPS="..table.sum(LastHitCreep.CreepsDPS[npc].Damage).." "..table.tostring(LastHitCreep.CreepsDPS[npc].Damage));
					--Log.Write("HP="..HP.." Dist="..dist.." DMG="..TrueDMG.." PMD="..PossiblyMissedDPS.." PrepareTime="..(os.clock()+DMGTime));
					if (LastHitCreep.isEducation() and not LastHitCreep.isHitKeyDown()) then
						--LastHitCreep.ClearParticle(npc);
						LastHitCreep.CreateOverheadParticle(npc, npc, "particles/units/heroes/hero_sniper/sniper_crosshair.vpcf");
					else
						Player.AttackTarget(Players.GetLocal(), LastHitCreep.User.Hero, npc)
					end;
					LastHitCreep.User.LastAttackTime = os.clock() + 0.05;
					LastHitCreep.User.LastMoveTime = LastHitCreep.User.LastAttackTime + 0.5;
					LastHitCreep.User.LastTarget = npc;
					break;
				end;
			end;
		end;
	end;
	
	--must be sort and check list 
	--1) if (HP <= TrueDMG)
	--2) if (HP <= TrueDMG + PossiblyMissedDPS)
	--3) if (HP <= MaxHP\4) AND (DPS < 20))--why 20?
	--Attack Move Block
	if LastHitCreep.isAttackMove() then
		if NPC.IsTurning(LastHitCreep.User.Hero) or NPC.IsRunning(LastHitCreep.User.Hero) then
			LastHitCreep.User.LastMoveTime = os.clock() + 2;
		else
			if ((os.clock() - LastHitCreep.User.LastAttackTime) > (LastHitCreep.User.AttackPoint + 0.05)) and ((os.clock() - LastHitCreep.User.LastMoveTime) > 0.45)  then
				--Log.Write("Attack Move");
				local position = Entity.GetAbsOrigin(LastHitCreep.User.Hero);
				movevec = position:__add(Vector(math.random(-70,70),math.random(-70,70),0));--magic number for range move
				NPC.MoveTo(LastHitCreep.User.Hero, movevec, false);
				LastHitCreep.User.LastMoveTime = os.clock() + 3 + (VectorDistance(position,movevec)/LastHitCreep.User.MoveSpeed);--magic numbers for time delay
			end;
		end;
	end;
	
	--[[
		-- check 
				if (NPC.IsLaneCreep(npc) and (LastHitCreep.User.LastTarget ~= npc) and ) then
	]]
end;

function LastHitCreep.OnUnitDie(ent)
	Log.Write(NPC.GetUnitName(ent));
end;

function LastHitCreep.OnUnitAnimation(animation)
	if not animation or not LastHitCreep.isEnabled() then 
		return;
	end;
	
	if (NPC.GetUnitName(animation.unit) == LastHitCreep.User.Name) then
		if LastHitCreep.User.LastTarget and Entity.IsEntity(LastHitCreep.User.LastTarget) then
			--Log.Write("LT HP Start="..math.floor(Entity.GetHealth(LastHitCreep.User.LastTarget) + NPC.GetHealthRegen(LastHitCreep.User.LastTarget)));
		end;
		--[[
		local increasedAS = NPC.GetIncreasedAttackSpeed(animation.unit);
		local attackTime = LastHitCreep.User.AttackTime;
		local attackPoint = LastHitCreep.User.AttackPoint;
		local attackSpeed = attackPoint / (1 + (increasedAS/100));
		local attackTime = GameRules.GetGameTime() + attackSpeed + (attackPoint * 0.75);
		Log.Write("R_StartAttack="..GameRules.GetGameTime().." EndAttack="..attackTime);
		]]
	end;
	--[[
	--try find\test facing, but it not right
	if animation.unit and Entity.IsNPC(animation.unit) and NPC.IsLaneCreep(animation.unit) and (Entity.IsSameTeam(LastHitCreep.User.Hero, animation.unit)) and (animation.type == 1) then
		local attackRange = NPC.GetAttackRange(animation.unit);
		if NPC.IsRanged(animation.unit) then
			attackRange = attackRange + 64;--magin number 64???
		else
			attackRange = attackRange + 55;--magin number 55???
		end;
		local facing = NPC.FindFacingNPC(animation.unit);
		if (facing and Entity.IsEntity(facing) and Entity.IsNPC(facing) and NPC.IsEntityInRange(animation.unit, facing, attackRange)) then
			LastHitCreep.CreateTargetingParticle(animation.unit, facing);
		end;
	end;
	]]
end;

function LastHitCreep.OnUnitAnimationEnd(animation)
	if not animation or not LastHitCreep.isEnabled() then 
		return;
	end;

	if (NPC.GetUnitName(animation.unit) == LastHitCreep.User.Name) then
		if LastHitCreep.User.LastTarget and Entity.IsEntity(LastHitCreep.User.LastTarget) then
			--Log.Write("LT HP END="..math.floor(Entity.GetHealth(LastHitCreep.User.LastTarget) + NPC.GetHealthRegen(LastHitCreep.User.LastTarget)));
		end;
		--Log.Write("R_EndAttack="..GameRules.GetGameTime());
	end;

end;

function LastHitCreep.OnModifierCreate(ent, mod)
	if not LastHitCreep.isEnabled() then
		return;
	end;

end;

function LastHitCreep.OnModifierDestroy(ent, mod)
	if not LastHitCreep.isEnabled() then
		return;
	end;

end;

function LastHitCreep.OnGameStart()
	LastHitCreep.Initialization();
end

function LastHitCreep.OnGameEnd()
	LastHitCreep.Finalization();
end

function LastHitCreep.OnMenuOptionChange(option, oldValue, newValue)

end;

LastHitCreep.Initialization();

return LastHitCreep