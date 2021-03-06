-- displays a spellbar over the head of a char

if (not gDisabledPlugins.spellbar) then 
kSpellTimeLatency = 150


RegisterListener("Hook_HUDStep",function ()
	SpellBarStep()
end)

RegisterListener("Hook_TargetMode_Start",function () 
	if (gSpellBarLastSpellSendTime) then
		local t = Client_GetTicks()
		local dt = t-gSpellBarLastSpellSendTime
		local spellid = gSpellBarLastSpellSendID
		--~ print("spellbar : timediff",dt,"C:"..GetSpellCircleByID(spellid),GetSpellNameByID(spellid))
		--~ local r,g,b = 0.5,0.5,0.5
		--~ SpellBarRiseTextOnMob(GetPlayerSerial(),r,g,b,"t:"..dt)
		
		print("############SPELLTIME",dt)
		
		gSpellBarLastSpellSendTime = nil
		SpellBarTargetCursor()
	end
end)

RegisterListener("Hook_SendSpell",function (spellid)
	if (gNoRender) then return end
	local t = Client_GetTicks()
	gSpellBarLastSpellSendTime = t
	gSpellBarLastSpellSendID = spellid
	SpellBarRiseTextOnMob(GetPlayerSerial(),1,1,1,GetSpellNameByID(spellid))
	local casttime = GetSpellCastTimeForPlayer(spellid)
	if (casttime > 0) then SpellBarStart(casttime + kSpellTimeLatency) end
end)



function SpellBarEnd ()
	if (gSpellBarGfx) then gSpellBarGfx:Destroy() gSpellBarGfx = nil end
end
function SpellBarStart (casttime)
	--~ if (gCurrentRenderer ~= Renderer2D) then return end
	SpellBarEnd()
	local t = Client_GetTicks()
	local gfx	= gRootWidget.hudfx:CreateChild("Group")
	gfx.mob		= GetPlayerMobile()
	gfx.zadd	= 10 -- above head
	gfx.startt	= t
	gfx.endt	= t + casttime
	gfx.dur		= casttime
	gfx.maxw	= 100
	gfx.h		= 10
	local w,h	= gfx.maxw,gfx.h
	local paramb = MakeSpritePanelParam_BorderPartMatrix(GetPlainTextureGUIMat("simplebutton.png"),w,h, 0,0, 0,0, 4,8,4, 4,8,4, 32,32, 1,1, false, false)
	local paramf = MakeSpritePanelParam_BorderPartMatrix(GetPlainTextureGUIMat("simplebutton.png"),0,h, 0,0, 0,0, 4,8,4, 4,8,4, 32,32, 1,1, false, false)
	local gray	= 0.2
	paramb.r = gray
	paramb.g = gray
	paramb.b = gray
	
	gfx.border	= gfx:CreateChild("Image",{gfxparam_init=paramb})
	gfx.fill	= gfx:CreateChild("Image",{gfxparam_init=paramf,bVertexBufferDynamic=true})
	gSpellBarGfx = gfx
end
function SpellBarStep ()
	--~ if (gCurrentRenderer ~= Renderer2D) then return end
	local gfx = gSpellBarGfx
	if (not gfx) then return end
	
	-- position above mob
	local mobile = gfx.mob
	local px,py = gCurrentRenderer:UOPosToPixelPos(mobile.xloc,mobile.yloc,mobile.zloc+gfx.zadd)
	if (px) then gfx:SetPos(px,py) end
	
	-- calc time and width
	local t = Client_GetTicks()
	local ft = (t - gfx.startt) / gfx.dur
	if (ft > 1) then SpellBarEnd() return end
	ft = max(0,min(1,ft))
	local w = ft * gfx.maxw
	gfx.fill:SetSize(w,gfx.h)
end
function SpellBarInterrupt ()
	SpellBarEnd()
end
function SpellBarTargetCursor ()
	SpellBarEnd()
end

function SpellBarRiseTextOnMob (serial,r,g,b,text)
	gCurrentRenderer:HUDFX_AddRisingTextOnMob(GetMobile(serial),text,r,g,b) -- see 2d.hudfx.lua
end

function SpellBarRiseTextOnPos (xloc,yloc,zloc,r,g,b,text) 
	Renderer2D:HUDFX_AddRisingTextOnPos(xloc,yloc,zloc,text,r,g,b) -- see 2d.hudfx.lua
end

     

RegisterListener("Hook_Text",function (name,plaintext,serial,data)
	if (data.packet == kPacket_Localized_Text) then return end
	if (data.bIsAutoGenerated) then return end -- label
	local r,g,b = GetHueColor(data.hue-1)
	local spellname = GetSpellNameFromMantra(plaintext)
	if (spellname) then plaintext = spellname r,g,b = 0.5,0.5,0.5 end
		
	SpellBarRiseTextOnMob(serial,r,g,b,data.unicode or plaintext)
	if (serial == 0xffffffff) then
		local a,b,attacker,victim = string.find(plaintext,"You notice (.+) attempting to peek into (.+)'s belongings.")
		if (attacker) then 
			local bOnSelf = StringContains(victim,GetPlayerName() or "?") if (bOnSelf) then r,g,b = 1,0,0 else r,g,b = 1,0.5,0 end
			SpellBarRiseTextOnMob(GetPlayerSerial(),r,g,b,sprintf("SNOOP %s:%s",attacker,victim))
			NotifyListener("Hook_Notice_Snoop",attacker,victim,bOnSelf)
		end
		local a,b,attacker,victim = string.find(plaintext,"You notice (.+) trying to steal from (.+).")
		if (attacker) then 
			local bOnSelf = StringContains(victim,GetPlayerName() or "?") if (bOnSelf) then r,g,b = 1,0,0 else r,g,b = 1,0.5,0 end
			SpellBarRiseTextOnMob(GetPlayerSerial(),r,g,b,sprintf("STEAL %s:%s",attacker,victim))
			NotifyListener("Hook_Notice_Steal",attacker,victim,bOnSelf)
		end
	end
end)

RegisterListener("Mobile_UpdateMana",			function (mobile,oldcur,oldmax,curvalue,maxvalue)
	local serial = mobile.serial
	local delta = curvalue - oldcur 
	if (delta == 1 or delta == 0) then return end
	local r,g,b = 0,0,1 -- blue
	SpellBarRiseTextOnMob(serial,r,g,b,sprintf("   %+d",delta))
	--~ print("manaused",serial,used) 
end)

-- this is only triggered by hp-health-packet, used for magery-heal, but not used when drinking a potion -> kPacket_Mobile_Stats  "Mobile_UpdateStats"
RegisterListener("Mobile_UpdateHealth",			function (mobile,oldcur,oldmax,curvalue,maxvalue)
	local serial = mobile.serial
	local delta = curvalue - oldcur 
	if (delta > 1) then 
		print("HEAL!",delta,Client_GetTicks())
		local r,g,b = 0,1,0 -- green
		SpellBarRiseTextOnMob(serial,r,g,b,sprintf("      %+d",delta))
	end
end)
	
gSpellbarEffectShortMessages = {}
gSpellbarEffectShortMessages[0x37B9 ] = {r=1,g=0,b=0,txt="reflect" } -- Magic Reflection (preaos) or parrying
	
gSpellbarAnimationShortMessages = {}
gSpellbarAnimationShortMessages[4  ] = {r=0.5,g=0.5,b=0.5,txt="swing3" } -- melee combat : swing weapon  (monster) or get hit ?
gSpellbarAnimationShortMessages[10 ] = {r=0.5,g=0.5,b=0.5,txt="swing" } -- melee combat : swing weapon  (monster)
gSpellbarAnimationShortMessages[11 ] = {r=0.5,g=0.5,b=0.5,txt="swing3" } -- melee combat : swing weapon
gSpellbarAnimationShortMessages[29 ] = {r=0.5,g=0.5,b=0.5,txt="swing4" } -- melee combat : swing weapon
gSpellbarAnimationShortMessages[20 ] = {r=0.5,g=0.5,b=0.5,txt="gethit" } -- melee combat : take damage
gSpellbarAnimationShortMessages[34 ] = {r=0.5,g=0.5,b=0.5,txt="drinkpot" }
gSpellbarAnimationShortMessages[92 ] = {r=0.8,g=0.5,b=0.5,txt="fizzle" } -- spellfail
gSpellbarAnimationShortMessages[526] = {r=0.5,g=0.5,b=0.5,txt="gate" }
gSpellbarAnimationShortMessages[508] = {r=0.5,g=0.5,b=0.5,txt="recall" }
	
gSpellbarSoundShortMessages = {}

gSpellbarShortMessages = {}
gSpellbarShortMessages[502642 ] = {r=1,g=0,b=0,txt="already casting"	}-- You are already casting a spell.	

gSpellbarShortMessages[500946 ] = {r=1,g=0,b=0,txt="cannot cast in town",bInterrupt=true} -- You cannot cast this in town!							
gSpellbarShortMessages[502632 ] = {r=1,g=0,b=0,txt="fizzle"				,bInterrupt=true} -- The spell fizzles.										
gSpellbarShortMessages[500641 ] = {r=1,g=0,b=0,txt="disturbed"			,bInterrupt=true} -- Your concentration is disturbed, thus ruining thy spell.	
gSpellbarShortMessages[502625 ] = {r=1,g=0,b=0,txt="no mana"			,bInterrupt=true} -- Insufficient mana for this spell.						
gSpellbarShortMessages[1049645] = {r=1,g=0,b=0,txt="too many followers"	,bInterrupt=true} -- You have too many followers to summon that creature.  	   
gSpellbarShortMessages[500015 ] = {r=1,g=0,b=0,txt="don't have spell"	,bInterrupt=true} -- You do not have that spell!
gSpellbarShortMessages[502630 ] = {r=1,g=0,b=0,txt="regs"				,bInterrupt=true} -- More reagents are needed for this spell.
gSpellbarShortMessages[502644 ] = {r=1,g=0,b=0,txt="recover"			,bInterrupt=true} -- You have not yet recovered from casting a spell.
gSpellbarShortMessages[1061091 ] = {r=1,g=0,b=0,txt="form"				,bInterrupt=true} -- You cannot cast that spell in this form.
gSpellbarShortMessages[1061605 ] = {r=1,g=0,b=0,txt="already"			,bInterrupt=true} -- You already have a familiar.
gSpellbarShortMessages[1005385 ] = {r=1,g=0,b=0,txt="will not adhere"	,bInterrupt=true} -- The spell will not adhere to you at this time. (preaos,reactive armor or spellresist still active)
gSpellbarShortMessages[1005559 ] = {r=1,g=0,b=0,txt="already"			,bInterrupt=true} -- This spell is already in effect.
gSpellbarShortMessages[1005561 ] = {r=1,g=0,b=0,txt="crime"				,bInterrupt=true} -- Thou'rt a criminal and cannot escape so easily...
gSpellbarShortMessages[1005564 ] = {r=1,g=0,b=0,txt="crimeB"			,bInterrupt=true} -- Wouldst thou flee during the heat of battle??
gSpellbarShortMessages[502359  ] = {r=1,g=0,b=0,txt="encumb"			,bInterrupt=true} -- Thou art too encumbered to move. (tele,recall)
gSpellbarShortMessages[501802  ] = {r=1,g=0,b=0,txt="spellblock"		,bInterrupt=true} -- Thy spell doth not appear to work...   (dungeon-recall)





for k,v in pairs(gSpellbarShortMessages) do if (v.bInterrupt) then gSpellInterruptMessages[k] = true end end

-- weapon specials
gSpellbarShortMessages[1060163] = {r=0.5,g=0.5,b=0.5,txt="PARABLOW"			}--~ You deliver a paralyzing blow!  
gSpellbarShortMessages[1061923] = {r=0.5,g=0.5,b=0.5,txt="already frozen"	}--~ The target is already frozen.   
gSpellbarShortMessages[1070804] = {r=0.5,g=0.5,b=0.5,txt="para-resist"		}--~ Your target resists paralysis.  
gSpellbarShortMessages[1060849] = {r=0.5,g=0.5,b=0.5,txt="already unarmed"	}--~ Your target is already unarmed! 
gSpellbarShortMessages[1060092] = {r=0.5,g=0.5,b=0.5,txt="DISARM"			}--~ You disarm their weapon!        

-- other system messages
gSpellbarShortMessages[500112] = {r=0,g=0.5,b=0,txt="goardzone on"			} -- You are now under the protection of the town guards. 
gSpellbarShortMessages[500113] = {r=0.5,g=0,b=0,txt="goardzone off"			} -- You have left the protection of the town guards.     
gSpellbarShortMessages[501942] = {r=0.5,g=0.5,b=0.5,txt="location blocked"	} -- That location is blocked.           
gSpellbarShortMessages[500119] = {r=0.5,g=0.5,b=0.5,txt="actionwait"		} -- You must wait to perform another action.     
gSpellbarShortMessages[500118] = {r=0.5,g=0.5,b=0.5,txt="skillwait"			} -- You must wait a few moments to use another skill.  
gSpellbarShortMessages[500446] = {r=0.5,g=0.5,b=0.5,txt="too far"			} -- That is too far away. 
gSpellbarShortMessages[500616] = {r=0.5,g=0.5,b=0.5,txt="peace"				} -- You hear lovely music, and forget to continue battling!
 
gSpellbarShortMessages[1019043] = {r=1.0,g=0.0,b=0.0,txt="!!shove-invis!!" } -- Being perfectly rested, you shove something invisible out of the way.

gSpellbarShortMessages[501284] = {r=0.5,g=0.0,b=0.0,txt="You may not enter." } -- You may not enter.
gSpellbarShortMessages[500111] = {r=0.5,g=0.0,b=0.0,txt="frozen" 			} -- You are frozen and cannot move. 
gSpellbarShortMessages[502381] = {r=1.0,g=0.0,b=0.0,txt="cannot move!" 		} -- You cannot move!
gSpellbarShortMessages[502382] = {r=0.0,g=0.5,b=0.0,txt="can move!" 		} -- You can move!
gSpellbarShortMessages[1060160] = {r=1.0,g=0.0,b=0.0,txt="bleed" 			} -- You are bleeding!  (serial=0xfff)
gSpellbarShortMessages[1060757] = {r=1.0,g=0.0,b=0.0,txt="bleedstart" 		} -- You are bleeding profusely  (serial=self=899675)
gSpellbarShortMessages[1060167] = {r=0.0,g=0.5,b=0.0,txt="bleedstop" 		} -- The bleeding wounds have healed, you are no longer bleeding!
gSpellbarShortMessages[1042809] = {r=1,g=0.5,b=0.0,txt="EscortDone"			} -- We have arrived! I thank thee, CHARNAME! I have no further need of thy services. Here is thy pay.
gSpellbarShortMessages[500969] = {r=0,g=1,b=0.0,txt="BandaDone"				} -- You finish applying the bandages.


gSpellbarShortMessages[500498] = {r=0,g=1,b=0.0,txt="log"				} -- You put some logs into your backpack.   
gSpellbarShortMessages[500493] = {r=1,g=0,b=0.0,txt="empty"				} -- There's not enough wood here to harvest.        
gSpellbarShortMessages[500495] = {r=1,g=1,b=0.0,txt="fail"				} -- You hack at the tree for a while, but fail to produce any useable wood. 
--~ gSpellbarShortMessages[] = {r=0,g=1,b=0.0,txt=""				} -- 

gSpellbarShortMessages[501863]	= {r=1,g=0,b=0.0,txt="can't mine that"	} -- You can't mine that.
gSpellbarShortMessages[503040]	= {r=1,g=0,b=0.0,txt="empty"			} -- There is no metal here to mine.
gSpellbarShortMessages[503043]	= {r=1,g=1,b=0.0,txt="fail"				} -- You loosen some rocks but fail to find any useable ore.
gSpellbarShortMessages[1007072]	= {r=0,g=1,b=0.0,txt="1:iron"			} -- You dig some iron ore and put it in your backpack.
gSpellbarShortMessages[1007073]	= {r=0,g=1,b=0.0,txt="2:dullcopper"		} -- You dig some dull copper ore and put it in your backpack.
gSpellbarShortMessages[1007074]	= {r=0,g=1,b=0.0,txt="3:shadow iron"	} -- You dig some shadow iron ore and put it in your backpack.
gSpellbarShortMessages[1007075]	= {r=0,g=1,b=0.0,txt="4:copper"			} -- You dig some copper ore and put it in your backpack.
gSpellbarShortMessages[1007076]	= {r=0,g=1,b=0.0,txt="5:bronze"			} -- You dig some bronze ore and put it in your backpack.
gSpellbarShortMessages[1007077]	= {r=0,g=1,b=0.0,txt="6:golden"			} -- You dig some golden ore and put it in your backpack.
gSpellbarShortMessages[1007078]	= {r=0,g=1,b=0.0,txt="7:agapite"		} -- You dig some agapite ore and put it in your backpack.
gSpellbarShortMessages[1007080]	= {r=0,g=1,b=0.0,txt="9:valorite"		} -- You dig some valorite ore and put it in your backpack.

gSpellbarShortMessages[1049527]	= {r=1,g=0.5,b=0.0,txt="peace:already"	} -- That creature is already being calmed.
gSpellbarShortMessages[1049537]	= {r=1,g=0.5,b=0.0,txt="disco:already"	} -- That creature is already in discord.
gSpellbarShortMessages[500612]	= {r=1,g=1,b=0.0,txt="musi:fail"		} -- You play poorly, and there is no effect. 
gSpellbarShortMessages[1049540]	= {r=1,g=1,b=0.0,txt="disco:fail"		} -- You attempt to disrupt your target, but fail.
gSpellbarShortMessages[1049539]	= {r=0,g=1,b=0.0,txt="disco:success"	} -- You play jarring music, suppressing your target's strength.
gSpellbarShortMessages[1049532]	= {r=0,g=1,b=0.0,txt="peace:success"	} -- You play hypnotic music, calming your target.
gSpellbarShortMessages[501602]	= {r=0,g=1,b=0.0,txt="provo:success"	} -- Your music succeeds, as you start a fight.  
gSpellbarShortMessages[501589]	= {r=1,g=0,b=0.0,txt="provo:invalid"	} -- You can't incite that!  501589  0
gSpellbarShortMessages[501593]	= {r=1,g=0,b=0.0,txt="provo:noself"		} -- You can't tell someone to attack themselves!    501593  0
gSpellbarShortMessages[1049450]	= {r=1,g=0,b=0.0,txt="provo:toofar"		} -- The creatures you are trying to provoke are too far away from each other for your music to have an effect. 1049450  0
gSpellbarShortMessages[501599]	= {r=1,g=1,b=0.0,txt="provo:fail"		} -- Your music fails to incite enough anger.        501599  0





--[[

Hook_Packet_Localized_Text      4294967295      Being perfectly rested, you shove them out of the way.  1019042
Hook_Packet_Localized_Text      4294967295      You begin to move quietly.      502730


Hook_Packet_Localized_Text      4294967295      You feel yourself resisting magical energy.     501783
Hook_Packet_Localized_Text      4294967295      You begin applying the bandages.        500956
Hook_Packet_Localized_Text      4294967295      Your Blood Oath has been broken.        1061620
Hook_Packet_Localized_Text      4294967295      You fall off of your mount and take damage!     1060083
Hook_Packet_Localized_Text      4294967295      You are still too dazed from being knocked off your mount to ride!      1040024
Hook_Packet_Localized_Text      4294967295      You feel your life force being stolen away!     1070848
Hook_Packet_Localized_Text      4294967295      You have cured the target of all poisons!       1010058
Hook_Packet_Localized_Text      4294967295      You are already at full health. 1049547  potion ? 
Hook_Packet_Localized_Text      4294967295      The essence of garlic burns you!        1061651   some spells in necro form

Hook_Packet_Localized_Text      899675  		* You begin to feel pain throughout your body! *        1042861
Hook_Packet_Localized_Text      407630  		* The poison seems to have no effect. * 1005534
Hook_Packet_Localized_Text      326218  * Otsu is wracked with extreme pain. *  1042864

Hook_Packet_Localized_Text      4294967295      You prepare to hit your opponent with a Death Strike.   1063091
Hook_Packet_Localized_Text      4294967295      You inflict a Death Strike upon your opponent!  1063094  (different message for 2nd..)
Hook_Packet_Localized_Text      4294967295      You missed your opponent with a Death Strike.   1070779  


]]--


RegisterListener("Hook_Spell_Interrupt",function () SpellBarInterrupt() end)

gSpellBarLoadRevision = (gSpellBarLoadRevision or 0) + 1
 local myrev = gSpellBarLoadRevision
--~ NotifyListener("Hook_Text",unitext_name,unitext_message) -- kPacket_Text_Unicode
RegisterListener("Hook_Packet_Localized_Text",	function (serial,plaintext,text_messagenum,texttype,data)
	if (myrev ~= gSpellBarLoadRevision) then return true end
	--~ if (texttype == kTextType_Label) then return end
	if (data.bIsAutoGenerated) then return end
	local short = gSpellbarShortMessages[text_messagenum]
	if (short) then SpellBarRiseTextOnMob(GetPlayerSerial(),short.r,short.g,short.b,short.txt) end
	--~ if (not short) then print("Hook_Packet_Localized_Text",serial,plaintext,text_messagenum) end
	-- and serial == 0xFFFFFFFF
	if (serial ~= 0xFFFFFFFF) then
		local r,g,b = 1,1,0 -- yellow
		SpellBarRiseTextOnMob(serial,r,g,b,plaintext)
	end
end)

RegisterListener("Hook_Packet_Hued_FX",	function (effect)
	local short = gSpellbarEffectShortMessages[effect.itemid] 
	if (short) then SpellBarRiseTextOnMob(effect.sourceserial,short.r,short.g,short.b,short.txt) end
end)

RegisterListener("Hook_Packet_Animation",	function (animdata)
	local short = gSpellbarAnimationShortMessages[animdata.m_animation] 
	if (short) then SpellBarRiseTextOnMob(animdata.mobileserial,short.r,short.g,short.b,short.txt) end
	if ((not short) and gDebugSpellbarAnim) then SpellBarRiseTextOnMob(animdata.mobileserial,0.5,0.5,0.5,"Anim:"..animdata.m_animation) end
end)

RegisterListener("Hook_Packet_Sound",	function (sounddata)
	local short = gSpellbarSoundShortMessages[sounddata.effectid] 
	if (short) then SpellBarRiseTextOnPos(sounddata.xloc,sounddata.yloc,sounddata.zloc,short.r,short.g,short.b,short.txt) end
	if ((not short) and gDebugSpellbarSound) then SpellBarRiseTextOnPos(sounddata.xloc,sounddata.yloc,sounddata.zloc,0.5,0.5,0.5,"Sound:"..sounddata.effectid) print("spellbar:sound:",sounddata.effectid) end
end)
	
--[[
Hook_Packet_Localized_Text      382928   a Crane        1050045
spellbar:Hook_SendSpell 57      Earthquake
Hook_Packet_Text        899675  In Vas Por
spellbar:Hook_SendSpell 57      Earthquake
Hook_Packet_Text        899675  In Vas Por
Hook_Packet_Localized_Text      382928   a Crane        1050045
spellbar:Hook_SendSpell 57      Earthquake
Hook_Packet_Localized_Text      4294967295=0xFFFFFFFF      You are already casting a spell.        502642
Hook_Packet_Localized_Text      899675  The spell fizzles.      502632
	899675 = 0xDBA5B
	4294967295 = 0xFFFFFFFF

Hook_Packet_Localized_Text      4294967295=0xFFFFFFFF      Your concentration is disturbed, thus ruining thy spell.    500641

	-- Macro_ShowTimeout

	if timeout > 0 then
		local params = {
			gfxparam_bar = MakeSpritePanelParam_BorderPartMatrix(GetPlainTextureGUIMat("ray_border.png"),32,32, 0,0, 0,0, 1,30,1, 1,30,1, 32,32, 1,1, false, false),
			gfxparam_background = MakeSpritePanelParam_BorderPartMatrix(GetPlainTextureGUIMat("ray_border_black.png"),32,32, 0,0, 0,0, 1,30,1, 1,30,1, 32,32, 1,1, false, false),
		}
		
		local progress = GetDesktopWidget():CreateChild("Bar",params)
		progress:SetLeftTop(x,y)
		progress:SetSize(w,h)
		progress:SetProgress(0)
		progress:CreateContentChild("UOText",{text="<BASEFONT COLOR="..color..">"..text.."</BASEFONT>",x=5,y=-2,width=w,height=h,background=0,scrollbar=0,bold=false,crop=false,html=true})
		
		local startt = Client_GetTicks()
		
		job.create(function()
			local p = 0
			repeat
				p = Clamp((Client_GetTicks() - startt) / timeout, 0, 1)
				progress:SetProgress(p)
				job.wait(10)
			until p == 1
			progress:Destroy()
		end)
	end
	
	
]]--

end
