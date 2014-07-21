-- Script Name: Just Riven
-- Script Ver.: 1.4
-- Author     : Skeem

--[[ Changelog:
	1.0 -Initial Release
	1.1 - Smoothen up combo
	    - Fixed Error Spamming
	1.2 - Smoothen up Orbwalking
	    - Added some packet checks
	1.3 - Remade orbwalker completely packet based now
	    - Combo should be a lot faster
	    - Added Menu Options for max stacks to use in combo
	1.4 - Whole new combo system
		- Added Selector make sure to have latest (http://iuser99.com/scripts/Selector.lua)
		- Removed Max Stacks in combo from menu (let me know if you want this back, i don't think its need anymore)
	    - Added menu to cancel anims with laugh/movement
	    - Added tiamat cancel AA anim -> W cancel tiamat anim -> Q cancel w Anim
	    - Added option to disable orbwalk in combo
	    - Fixed 'chasing target' when using combo
	    - Changed R Menu (Now in Combo Options) & Fixed Path Lib error with R
	    - Added R Damage logic based on skills available and option to use in combo
	    - Fixed Auto Ignite & Nil error spamming when not having it
]]--

if myHero.charName ~= 'Riven' then return end

require 'VPrediction'
require 'Selector'

	Spells = {
		Q = {key = _Q, string = 'Q', name = 'Broken Wings',   range = 280, ready = false, data = nil, color = 0x663300},
		W = {key = _W, string = 'W', name = 'Ki Burst',       range = 260, ready = false, data = nil, color = 0x333300},
		E = {key = _E, string = 'E', name = 'Valor',          range = 390, ready = false, data = nil, color = 0x666600},
		R = {key = _R, string = 'R', name = 'Blade of Exile', range = 900, ready = false, data = nil, color = 0x993300}
	}

	Ignite = (myHero:GetSpellData(SUMMONER_1).name:find("SummonerDot") and SUMMONER_1) or (myHero:GetSpellData(SUMMONER_2).name:find("SummonerDot") and SUMMONER_2) or nil

	Items = {
		YGB	   = {id = 3142, range = 350, ready = false},
		BRK    = {id = 3153, range = 500, ready = false},
		HYDRA  = {id = 3074, range = 400, ready = false},
		TIAMAT = {id = 3077, range = 400, ready = false}
	}

	BuffInfo = {
		P = {stacks = 0},
		Q = {stage  = 0}
	}

	vPred = VPrediction()

	Orbwalking = {
		lastAA     = 0,
	}

	RivenMenu = scriptConfig('~[Just Riven]~', 'Riven')
		RivenMenu:addSubMenu('~[Skill Settings]~', 'skills')
			RivenMenu.skills:addParam('', '--[ W Options ]--', SCRIPT_PARAM_INFO, '')
			RivenMenu.skills:addParam('autoW', 'Auto W Close Enemies', SCRIPT_PARAM_ONOFF, false)
		RivenMenu:addSubMenu('~[Combo Settings]~', 'combo')
			RivenMenu.combo:addParam('forceAAs', 'Force AAs with Passive',    SCRIPT_PARAM_ONOFF, true)
			RivenMenu.combo:addParam('orbwalk',  'Orbwalk in Combo',          SCRIPT_PARAM_ONOFF, true)
			RivenMenu.combo:addParam('ulti',     'Use R for Potential Kills', SCRIPT_PARAM_ONOFF, true)
			RivenMenu.combo:addParam('anim',     'Cancel Animation With:',    SCRIPT_PARAM_LIST, 1, {"Laugh", "Movement"})

		RivenMenu:addSubMenu('~[Kill Settings]~', 'kill')
			RivenMenu.kill:addParam('enabled', 'Enable KillSteal',    SCRIPT_PARAM_ONOFF, true)
			RivenMenu.kill:addParam('killQ',   'GapClose Q to KS',    SCRIPT_PARAM_ONOFF, true)
			RivenMenu.kill:addParam('killR',   'KillSteal with R',    SCRIPT_PARAM_LIST, 1, {"When R Already Used", "Always", "Never"})
			RivenMenu.kill:addParam('killW',   'KillSteal with W',    SCRIPT_PARAM_ONOFF, true)
			RivenMenu.kill:addParam('Ignite',  'Auto Ignite Enemies', SCRIPT_PARAM_ONOFF, true)

		RivenMenu:addSubMenu('~[Draw Ranges]~', 'draw')
			for _, spell in pairs(Spells) do
				RivenMenu.draw:addParam(spell.string, 'Draw '..spell.name..' ('..spell.string..')', SCRIPT_PARAM_ONOFF, true)
			end		
		RivenMenu:addParam('comboKey', 'Combo Key X', SCRIPT_PARAM_ONKEYDOWN, false, 88)

PrintChat("<font color='#663300'>Just Riven 1.4 Loaded</font>")

function OnTick()
	Target = GetTarget()

	for _, spell in pairs(Spells) do
		spell.ready = myHero:CanUseSpell(spell.key) == READY
		spell.data  = myHero:GetSpellData(spell.key)
	end

	for _, item in pairs(Items) do
		item.ready = GetInventoryItemIsCastable(item.id)
	end

	if RivenMenu.comboKey then
		if RivenMenu.combo.orbwalk then
			Orb(Target)
		end
		CastCombo(Target)
	end
	if RivenMenu.skills.autoW and Spells.W.ready and Target then
		Cast(_W, Target, Spells.W.range)
	end
	if RivenMenu.kill.enabled then
		KillSteal()
	end
end 

function OnDraw()
	for _, spell in pairs(Spells) do
		if spell.ready and RivenMenu.draw[spell.string] then
			DrawCircle(myHero.x, myHero.y, myHero.z, spell.range, spell.color)
		end
	end
end

function OnGainBuff(unit, buff)
	if unit.isMe then
		if buff.name == 'rivenpassiveaaboost' then
			BuffInfo.P.stacks = 1
		end
		if buff.name == 'riventricleavesoundone' then
			BuffInfo.Q.stage  = 1
		end
		if buff.name == 'riventricleavesoundtwo' then
			BuffInfo.Q.stage  = 2
		end
	end
end

function OnLoseBuff(unit, buff)
	if unit.isMe then
		if buff.name == 'rivenpassiveaaboost' then
			BuffInfo.P.stacks = 0
		end
		if buff.name == 'RivenTriCleave' then
			BuffInfo.Q.stage  = 0
		end
	end
end

function OnUpdateBuff(unit, buff)
	if unit.isMe then
		if buff.name == 'rivenpassiveaaboost' then
			BuffInfo.P.stacks = buff.stack
		end
	end
end

function OnSendPacket(packet)
	local p = Packet(packet)
	if p:get('name') == 'S_CAST' and p:get('sourceNetworkId') == myHero.networkID then
		DelayAction(function() CancelAnimation() end, .1)
		if Target then
			if p:get('spellId') == 0 then
				Orbwalking.lastAA = 0
			elseif p:get('spellId') > 3 then
				DelayAction(function() Cast(_W, Target, Spells.W.range) end, .13)
			elseif p:get('spellId') == 1 and Spells.Q.ready then
				DelayAction(function() Cast(_Q, Target, Spells.Q.range) end, .17)
			end
		end
	end
end

function OnRecvPacket(packet)
	if packet.header == 0x34 then
		packet.pos = 1
		if packet:DecodeF() == myHero.networkID then
			packet.pos = 9
			if packet:Decode1() == 0x11 then
				Orbwalking.lastAA = 0
			end
		end
	end
	-- Thanks to Bilbao :3 --
	if packet.header == 0x65 then
  		packet.pos = 5
  		local dmgType  = packet:Decode1()
  		local targetId = packet:DecodeF()
  		local souceId  = packet:DecodeF()
  		if souceId == myHero.networkID and dmgType == (12 or 3) then
  			if RivenMenu.comboKey and Target then
				UseItems(Target)
  				if Spells.Q.ready then
  					Cast(_Q, Target, Spells.Q.range)
  				end
			end
			Orbwalking.lastAA = 0
  		end
 	end
end

function GetTarget()
	return Selector.GetTarget(LESSCASTADVANCED, 'AD', {distance = Spells.R.range})
end


function CastCombo(target)
	if target then
		local distance  = GetDistanceSqr(target)
		local EQRange   = Spells.E.ready and Spells.Q.ready and Spells.E.range + Spells.Q.range
		local EWRange   = Spells.E.ready and Spells.Q.ready and Spells.E.range + Spells.W.range
		if RivenMenu.combo.ulti and Ult(target) and Spells.R.ready and InRange(target) then
			CastSpell(_R)
		end
		if EQ then
			Cast(_E, target, EQRange)
		elseif EW then
			Cast(_E, target, EWRange)
		else
			Cast(_E, target, Spells.E.range)
		end		
		if RivenMenu.combo.forceAAs then
			if BuffInfo.P.stacks < 1 then
				if not CanAttack() or not InRange(target) then
					Cast(_Q, target, Spells.Q.range)
				end
			end
		else
			Cast(_Q, target, Spells.Q.range)
		end
		if not Items.TIAMAT.ready or Items.HYDRA.ready then 
			Cast(_W, target, Spells.W.range)
		end
	end
end

function Ult(target)
	local Dmg = {P = getDmg('P',  target, myHero),
				 A = getDmg('AD', target, myHero),
				 Q = Spells.Q.ready and getDmg('Q', target, myHero) or 0,
				 W = Spells.W.ready and getDmg('W', target, myHero) or 0,
				 R = Spells.R.ready and getDmg('R', target, myHero) or 0}

	return ((Dmg.P*3) + (Dmg.A*3) + (Dmg.Q*3) + Dmg.W + Dmg.R) > target.health
end



function CancelAnimation()
	return RivenMenu.combo.anim == 1 and SendChat('/l') or Packet('S_MOVE', { x = mousePos.x, y = mousePos.z }):send()
end

function KillSteal()
	for _, enemy in pairs(GetEnemyHeroes()) do
		if ValidTarget(enemy) then
			if Spells.R.ready then
				if RivenMenu.kill.killR == 1 then
					if enemy.health < getDmg("R", enemy, myHero) and Spells.R.data.name ~= 'RivenFengShuiEngine' then
						Cast(_R, enemy, Spells.R.range)
					end
				elseif RivenMenu.kill.killR == 2 then
					if ValidTarget(enemy, Spells.R.range) and enemy.health < getDmg("R", enemy, myHero) then
						Cast(_R, enemy, Spells.R.range)
					end	
				end
			end
			if Ignite ~= nil and RivenMenu.kill.Ignite and GetDistanceSqr(enemy) < 600 * 600 then
				IgniteCheck(enemy)
			end
			if RivenMenu.kill.killW and enemy.health < getDmg("W", enemy, myHero) then
				Cast(_W, enemy, Spells.W.range)
			end
		end
	end
end

function IgniteCheck(target)
	return  target.health < getDmg("IGNITE", target, myHero) and CastSpell(Ignite, target)
end

function Cast(spell, target, range)
	return GetDistanceSqr(target) < range * range and CastSpell(spell, target.x, target.z)
end

function UseItems(enemy)
	if enemy and enemy.type == myHero.type then
		for _, item in pairs(Items) do
			if item.ready and GetDistanceSqr(enemy) <= item.range*item.range then
      			CastItem(item.id, enemy)
    		end
		end
	end
end

function Orb(target)
    if target and CanAttack() and InRange(target) then
      	Attack(target)
    else
    	local MovePos = Vector(myHero) + 400 * (Vector(mousePos) - Vector(myHero)):normalized()
        Packet('S_MOVE', { x = MovePos.x, y = MovePos.z }):send()
    end
end

function CanAttack()
	return os.clock() > Orbwalking.lastAA
end

function AARange(target)
	return myHero.range + vPred:GetHitBox(myHero) + vPred:GetHitBox(target)
end

function InRange(target)
	return GetDistanceSqr(target.visionPos, myHero.visionPos) < AARange(target) * AARange(target)
end

function Attack(target)
	Orbwalking.lastAA = os.clock()
	Packet('S_MOVE', {type = 3, targetNetworkId = target.networkID}):send()
end