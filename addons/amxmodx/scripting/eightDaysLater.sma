#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fun>
#include <engine>
#include <fakemeta>

//Sets the sky you want for your server
#define SKYNAME "space"

//The time before zombies have leap at round start. Has to be a float/decimal
#define LEAP_CD		15.0	

#define MAX_PLAYERS 32
new bool:g_restart_attempt[MAX_PLAYERS + 1]

#define ZOMBIE_MISS 2
new miss_zombie[ZOMBIE_MISS][] = {"zombie/claw_miss1.wav", "zombie/claw_miss2.wav" }

#define ZOMBIE_HIT 3
new hit_zombie[ZOMBIE_HIT][] = {"zombie/claw_strike1.wav", "zombie/claw_strike2.wav","zombie/claw_strike3.wav" }

#define ZOMBIE_PAIN 2
new pain_zombie[ZOMBIE_PAIN][] = {"eightDaysLater/zombie_pain1.wav", "eightDaysLater/zombie_pain2.wav" }

#define Keysmenu_1 (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<9)
#define fm_find_ent_by_class(%1,%2) engfunc(EngFunc_FindEntityByString, %1, "classname", %2)

#define	SLOT_PRIMARY	1
#define	SLOT_SECONDARY	2
#define	SLOT_KNIFE	3
#define	SLOT_GRENADE	4
#define	SLOT_C4		5

#define PRIMARY_WEAPONS_BIT_SUM ((1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90))
#define SECONDARY_WEAPONS_BIT_SUM ((2<<CSW_P228)|(2<<CSW_ELITE)|(2<<CSW_FIVESEVEN)|(CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE))
stock g_WeaponSlots[] = { 0, 2, 0, 1, 4, 1, 5, 1, 1, 4, 2, 2, 1, 1, 1, 1, 2, 2, 1, 1, 1, 1, 1, 1 ,1, 4, 2, 1, 1, 3, 1 }
stock g_MaxBPAmmo[] = { 0, 52, 0, 90, 1, 32, 1, 100, 90, 1, 120, 100, 100, 90, 90, 90, 100, 120, 30, 120, 200, 21, 90, 120, 90, 2, 35, 90, 90, 0, 100 }

new bool:g_zombie[33]
new bool:buying
new bool:g_speed

new mod_name[32] = "8 Days Later"

//Pcvars...
new zomb_switch, zomb_hp,zomb_ap,zomb_speed,zomb_lightning,
zomb_leap,zomb_money,zomb_zdmg, zomb_hdmg,zomb_ammo, zomb_nvg, zomb_obj

new MODEL[256], zomb_model, use_model
new bombMap = 0
new hostageMap = 0

//The old commands
new g_autoteam, g_limitteams, g_flashlight

new hudsync

#define PLUGIN "8 Days Later"
#define VERSION "1.0"
#define AUTHOR "pandabot"

new g_ForwardSpawn;

new const g_sound_die[][] = {
	"aslave/slv_die1.wav",
	"aslave/slv_die2.wav",
	"bullchicken/bc_die1.wav",
	"bullchicken/bc_die3.wav",
	"headcrab/hc_die1.wav",
	"headcrab/hc_die2.wav"
};

public plugin_init() {
	
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_cvar(PLUGIN,VERSION,FCVAR_SERVER)
	
	register_dictionary("eightDaysLater.txt")
	
	register_logevent("logevent_round_start",2, "1=Round_Start")
	register_logevent("logevent_round_end", 2, "1=Round_End")
	
	register_event("ResetHUD","event_hud_reset", "be")
	register_event("TextMsg","event_restart_attempt", "a", "2=#Game_will_restart_in")
	register_event("CurWeapon","event_cur_weapon","be", "1=1")
	register_event("Damage","event_damage_scream","be","2!0","3=0") 
	register_event("Damage", "event_damage", "be", "2!0","3=0","4!0")
	register_event("StatusIcon", "event_status_icon", "be", "1=1", "1=2", "2=c4")
	register_event("HLTV", "event_new_round", "a", "1=0", "2=0")
	
	register_forward(FM_ClientUserInfoChanged,"fw_info")
	register_forward(FM_PlayerPostThink,"fw_postthink")
	register_forward(FM_Touch,"fw_Touch");
	register_forward( FM_EmitSound, "fw_EmitSound" )
	register_forward(FM_CmdStart, "fw_Cmd")
	register_forward(FM_GetGameDescription,"GameDesc")
	
	register_message(get_user_msgid("Scenario"),"message_scenario");
	register_message(get_user_msgid("BombDrop"),"message_bombdrop");
	register_message(get_user_msgid("AmmoPickup"),"message_ammopickup");
	register_message(get_user_msgid("TextMsg"),"message_textmsg");
	register_message(get_user_msgid("HostagePos"),"message_hostagepos");
	
	register_clcmd("say","clcmd_say")
	
	register_menucmd(register_menuid("Buy Menu"), Keysmenu_1, "buy_menu")
	
	register_clcmd("fullupdate","clcmd_fullupdate") 
	
	register_concmd("zombie_swarm", "zsonoff", ADMIN_BAN, "<0/1> Disable/Enable Zombie Swarm")
	
	zomb_switch = register_cvar("zs_enabled","1")
	zomb_hp = register_cvar("zs_health","1000")
	zomb_ap = register_cvar("zs_armour","4000")
	zomb_speed = register_cvar("zs_speed","400")
	zomb_lightning = register_cvar("zs_lightning","0")
	zomb_leap = register_cvar("zs_leap","0")
	zomb_money = register_cvar("zs_money","1000")
	zomb_zdmg = register_cvar("zs_zdmg","55")
	zomb_hdmg = register_cvar("zs_hdmg","150")
	zomb_ammo = register_cvar("zs_ammo","0")
	zomb_nvg = register_cvar("zs_nvg","1")
	zomb_obj = register_cvar("zs_objectives","1")
	
	zomb_model = register_cvar("zs_model","eightDaysLaterZombie")
	use_model = register_cvar("zs_use","1")
	
	if(fm_find_ent_by_class(1, "info_bomb_target") || fm_find_ent_by_class(1, "func_bomb_target")) {
		bombMap = 1;
	}
		
	if(fm_find_ent_by_class(1,"hostage_entity")) {
		hostageMap = 1
	}
		
	g_autoteam = get_cvar_num("mp_autoteambalance")
	g_limitteams = get_cvar_num("mp_limitteams")
	g_flashlight = get_cvar_num("mp_flashlight")
	
	server_cmd("sv_skyname %s", SKYNAME)
	server_cmd("sv_maxspeed 1000")
	
	set_cvar_num("mp_autoteambalance",0)
	set_cvar_num("mp_limitteams", 1)
	set_cvar_num("mp_flashlight", 1)
	
	set_task(1.0, "lightning_effects")
	set_task(1.0, "ambience_loop")
  
	if(g_ForwardSpawn > 0) {
		unregister_forward(FM_Spawn, g_ForwardSpawn);
	}

	register_forward(FM_EmitSound, "Forward_EmitSound");
	
	format(mod_name, 31, "Zombie Swarm %s", VERSION)
	hudsync = CreateHudSyncObj() 
}

new const g_MapEntities[][] = {
	"info_map_parameters",
	"func_bomb_target",
	"info_bomb_target",
	"hostage_entity",
	"monster_scientist",
	"func_hostage_rescue",
	"info_hostage_rescue",
	"info_vip_start",
	"func_vip_safetyzone",
	"func_escapezone"
};

public Forward_Spawn(iEnt) {
	
	if(!pev_valid(iEnt)) {
		return FMRES_IGNORED;
	}

	static className[32];
	pev(iEnt, pev_classname, className, charsmax(className));

	for(new i = 0; i < sizeof g_MapEntities; ++i) {
		
		if(equal(className, g_MapEntities[i])) {
			remove_entity(iEnt);
			return FMRES_SUPERCEDE;
		}
	}
	return FMRES_IGNORED;
}

public plugin_precache() {
	
	precache_model("models/player/eightDaysLaterZombie/eightDaysLaterZombie.mdl")
	precache_model("models/eightDaysLater/v_knife_zombieHands.mdl")
	precache_sound("eightDaysLater/ambience.wav")
	
	new i
	
	for (i = 0; i < ZOMBIE_MISS; i++)
		precache_sound(miss_zombie[i])
	
	for (i = 0; i < ZOMBIE_HIT; i++)
		precache_sound(hit_zombie[i])
	
	for (i = 0; i < ZOMBIE_PAIN; i++)
		precache_sound(pain_zombie[i])
  
	new iNum;
	for (iNum = 0; iNum < sizeof g_sound_die; iNum++)
		precache_sound(g_sound_die[iNum]);
  
	g_ForwardSpawn = register_forward(FM_Spawn, "Forward_Spawn");
}

public client_putinserver(id) {
	g_zombie[id] = false
	g_restart_attempt[id] = false
	g_speed = false
	client_cmd(id, "stopsound")
}

public zsonoff(id,level,cid) {
	
	if (!cmd_access(id,level,cid,1)) {
		return PLUGIN_HANDLED
	}

	new szArg[5]
	read_argv(1, szArg, 4)
	
	if (equali(szArg,"1") || equali(szArg,"on")) {
		
		if (get_cvar_num("zombie_swarm") == 1) {
			console_print(id, "%s is already on!", PLUGIN)
			return PLUGIN_HANDLED
		}
		
		zs_on()
		
		set_hudmessage(255, 255, 255, -1.0, 0.25, 0, 1.0, 5.0, 0.1, 0.2, -1)
		show_hudmessage(0, "%s is now ON!", PLUGIN)
		
		console_print(0,  "%s has been turned ON!", PLUGIN)
		client_print(0, print_chat, "%s has been turned ON!", PLUGIN)
		
		return PLUGIN_HANDLED
	}
	
	if (equali(szArg,"0") || equali(szArg,"off")) {
		
		if (get_cvar_num("zs_enabled") == 0) {
			console_print(id, "%s is already off!", PLUGIN)
			return PLUGIN_HANDLED
		}
		
		zs_off()
		
		set_hudmessage(255, 255, 255, -1.0, 0.25, 0, 1.0, 5.0, 0.1, 0.2, -1)
		show_hudmessage(0, "%s has been turned OFF!", PLUGIN)
		
		console_print(0,  "%s has been turned OFF!", PLUGIN)
		client_print(0, print_chat, "%s has been turned OFF!", PLUGIN)
		
		return PLUGIN_HANDLED
	}
	
	console_print(id,  "Invalid argument!")
	client_print(id, print_chat, "Invalid argument!")
	
	return PLUGIN_HANDLED
}

public zs_on() {
	
	new maxplayers = get_maxplayers()
	
	for (new i = 1; i <= maxplayers; i++) {
		g_zombie[i] = false
		g_restart_attempt[i] = false
	}
	
	set_cvar_num("zs_enabled", 1)
	
	set_task(1.0, "lightning_effects")
	set_task(1.0, "ambience_loop")
	
	set_cvar_num("mp_autoteambalance",0)
	set_cvar_num("mp_limitteams", 1)
	set_cvar_num("mp_flashlight", 1)
	
	set_cvar_num("sv_restartround", 3)
}

public zs_off() {
	
	new maxplayers = get_maxplayers()
	
	for (new i = 1; i <= maxplayers; i++) {
		g_zombie[i] = false
		g_restart_attempt[i] = false
		client_cmd(i, "stopsound")
	}
	
	set_cvar_num("zs_enabled", 0)
	
	set_lights("#OFF")
	remove_task(12175)
	
	set_cvar_num("mp_autoteambalance",g_autoteam)
	set_cvar_num("mp_limitteams", g_limitteams)
	set_cvar_num("mp_flashlight", g_flashlight)
	
	set_cvar_num("sv_restartround", 3)
}

public GameDesc() { 
	forward_return(FMV_STRING, mod_name)
	
	return FMRES_SUPERCEDE
}

public event_new_round(id) {
	
	if(hostageMap && get_pcvar_num(zomb_obj)) {
		set_task(0.1,"move_hostages")
	}
		
	buying = true
	new Float:buy_time = get_cvar_float("mp_buytime") * 60
	set_task(buy_time, "buy_false", 7294)
	
	g_speed = false
	new freeze = get_cvar_num("mp_freezetime")
	set_task(float(freeze),"allow_speed")
}

public allow_speed() {
	
	g_speed = true
	
	new players[32], num, i
	
	get_players(players, num)
	
	for (i = 0 ; i < num; i++) {
		if (g_zombie[players[i]]) {
			set_user_maxspeed(players[i], (get_pcvar_float(zomb_speed)))		
		}
	}
}

public logevent_round_start(id) {
	
	if(!get_pcvar_num(zomb_switch)) {
		return PLUGIN_HANDLED
	}
	
	if (get_pcvar_num(zomb_nvg)) {
		server_cmd("amx_restrict on nvgs")
	} else {
		server_cmd("amx_restrict off nvgs")
	}
	
	//set_task (0.5 , "team_check")
	set_task (5.0 , "StartMsg")
	
	if (g_zombie[id]) {
		set_user_maxspeed(id,(get_pcvar_float(zomb_speed)))
	}
	
	return PLUGIN_CONTINUE
}

public logevent_round_end() {
	
	if (task_exists(7294)) {
		remove_task(7294)	
	}
}

public buy_false() buying = false  

public clcmd_fullupdate() return PLUGIN_HANDLED

public event_restart_attempt() {
	
	if(!get_pcvar_num(zomb_switch)) {
		return PLUGIN_HANDLED
	}
	
	new players[32], num
	get_players(players, num, "a")
	
	for (new i; i < num; i++) {
		g_restart_attempt[players[i]] = true
	}
		
	return PLUGIN_CONTINUE
}

public event_hud_reset(id) {
	
	if(!get_pcvar_num(zomb_switch)) {
		return PLUGIN_HANDLED
	}
		
	if (g_restart_attempt[id]) {
		g_restart_attempt[id] = false
	}

	set_task(0.2,"event_player_spawn",id)
	
	return PLUGIN_CONTINUE
}

public event_player_spawn(id) {
	
	if(!is_user_alive(id)) {
		return PLUGIN_HANDLED
	}

	new CsTeams:team = cs_get_user_team(id)
	new CsArmorType:ArmorType = CS_ARMOR_VESTHELM
	
	if(team == CS_TEAM_T) {
		
		g_zombie[id] = true
		set_task(random_float(0.1,0.5), "Reset_Weapons", id) //Strips zombies if they do have guns
		set_user_health(id,get_pcvar_num(zomb_hp))
		cs_set_user_armor(id,get_pcvar_num(zomb_ap),ArmorType)
		set_user_footsteps(id, 0)
		set_user_gravity(id,0.875)
		cs_set_user_money(id,0)
		
		if (g_speed) {
			set_user_maxspeed(id,(get_pcvar_float(zomb_speed)))
		}
			
		if (!cs_get_user_nvg(id)) {
			
			cs_set_user_nvg(id,1)
			engclient_cmd(id, "nightvision")
		} 
	} else if(team == CS_TEAM_CT) {
		
		g_zombie[id] = false
		set_user_footsteps(id, 0)
		cs_set_user_money(id, cs_get_user_money(id) + get_pcvar_num(zomb_money))
		
		if (get_pcvar_num(use_model)) {
			cs_reset_user_model(id)
		}
	}
	
	ShowHUD(id)
	
	return PLUGIN_CONTINUE
}

public fw_info(id,buffer) {
	
	if (g_zombie[id]) {
		return FMRES_SUPERCEDE
	}

	return FMRES_IGNORED
}

public fw_postthink(id) {
	
	if (!is_user_alive(id) || !get_pcvar_num(use_model)) {
		return FMRES_IGNORED
	}

	if (g_zombie[id]) {
		
		new szModel[33]
		get_pcvar_string(zomb_model, MODEL, 255) 
		cs_get_user_model(id, szModel, 32)
		
		if (containi(szModel, MODEL) !=-1 )
			return FMRES_IGNORED
		
		new info = engfunc(EngFunc_GetInfoKeyBuffer, id)
		engfunc(EngFunc_SetClientKeyValue, id, info, "model", MODEL)
		
		return FMRES_IGNORED
	}
	
	return FMRES_IGNORED
}

public ShowHUD(id) {
	
	if(!is_user_alive(id)) {
		return PLUGIN_HANDLED
	}

	if(g_zombie[id]) {
		new hp = get_user_health(id)
		new ap = get_user_armor(id)
		set_hudmessage(255, 180, 0, 0.02, 0.90, 0, 0.0, 0.3, 0.0, 0.0)
		ShowSyncHudMsg(id, hudsync , "HP: %d     |AP     : %d", hp, ap)
	}
	
	set_task(0.1 , "ShowHUD" , id)
	
	return PLUGIN_CONTINUE
}

public event_cur_weapon(id) {
	
	if(!get_pcvar_num(zomb_switch)) {
		return PLUGIN_HANDLED
	}
		
	if(!is_user_alive(id)) {
		return PLUGIN_HANDLED
	}

	new weapon = read_data(2)
	new clip = read_data(3)
	
	if (g_WeaponSlots[weapon] == SLOT_PRIMARY || g_WeaponSlots[weapon] == SLOT_SECONDARY) {
		
		switch (get_pcvar_num(zomb_ammo)) {
				
			case 1: {
				
				new ammo = cs_get_user_bpammo(id, weapon)
				
				if (ammo < g_MaxBPAmmo[weapon]) {
					cs_set_user_bpammo(id, weapon, g_MaxBPAmmo[weapon])
				}
			}
			
			case 2: {
				give_ammo(id , weapon , clip)
			}
		}
	}
	
	if (g_zombie[id] && g_speed) {
		set_user_maxspeed(id,(get_pcvar_float(zomb_speed)))
	}

	if (g_zombie[id] && g_WeaponSlots[weapon] == SLOT_KNIFE) {
		set_pev(id, pev_viewmodel, engfunc(EngFunc_AllocString, "models/eightDaysLater/v_knife_zombieHands.mdl"))
	}
		
	return PLUGIN_CONTINUE
}

public give_ammo(id , weapon , clip) {
	
	if (!is_user_alive(id)) {
		return PLUGIN_HANDLED
	}
		
	if (!clip) {
		
		new weapname[33]
		get_weaponname(weapon , weapname , 32)
		new wpn = -1
		while((wpn = fm_find_ent_by_class(wpn , weapname)) != 0) {
			
			if(id == pev(wpn,pev_owner)) {
				cs_set_weapon_ammo(wpn , maxclip(weapon))
				break;
			}
		}
	}
	
	return PLUGIN_CONTINUE
}

public event_status_icon(id) {
	
	if(!get_pcvar_num(zomb_switch)) {
		return PLUGIN_HANDLED
	}

	engclient_cmd(id, "drop", "weapon_c4")
	set_task(0.1, "delete_c4")
	
	return PLUGIN_CONTINUE
}

public delete_c4() {
	
	new ent = find_ent_by_class(-1, "weaponbox")
	
	while (ent > 0) {
		
		new model[33]
		entity_get_string(ent, EV_SZ_model, model, 32)
		
		if (equali(model, "models/w_backpack.mdl")) {
			remove_entity(ent)
			return PLUGIN_CONTINUE
		}
		
		ent = find_ent_by_class(ent, "weaponbox")
	}
	return PLUGIN_CONTINUE
}

public Reset_Weapons(id) {
	
	if(!is_user_alive(id)) {
		return PLUGIN_HANDLED
	}
		
	if(g_zombie[id]) {
		
		strip_user_weapons(id)
		give_item(id,"weapon_knife")
		
		if (is_user_bot(id)) {
			return PLUGIN_HANDLED
		} else if (get_pcvar_num(zomb_leap)) {
			set_task(LEAP_CD,"cooldown_begin",id)
			set_hudmessage(255, 255, 255, -1.0, 0.40, 0, 6.0, 14.0)
			show_hudmessage(id, "%L",LANG_PLAYER,"LEAP_WAIT",floatround(LEAP_CD))
		}
	}
	
	return PLUGIN_CONTINUE
} 

public cooldown_begin(id) {
	
	if (!is_user_alive(id)) {
		return PLUGIN_HANDLED
	}

	if (g_zombie[id]) {
		set_hudmessage(255, 255, 255, -1.0, 0.40, 0, 6.0, 5.0)
		show_hudmessage(id, "%L",LANG_PLAYER,"LEAP_READY")
		give_item(id, "item_longjump")
	}
	
	return PLUGIN_CONTINUE
}

public team_check() {
	
	new players[32],num,i,id
	get_players(players,num,"d")
	
	for(i = 0; i < num; i++) {
		id = players[i]
		if (!g_zombie[id]) {
			user_silentkill(id)
			cs_set_user_team(id,CS_TEAM_T)
		}
	}
	return PLUGIN_HANDLED
}

public StartMsg(id) {
	//client_print(0,print_chat,"%L",LANG_PLAYER,"WELCOME_MSG", VERSION)
	//client_print(0,print_chat,"%L",LANG_PLAYER,"ZOMBIE_MSG", get_pcvar_num(zomb_hp), get_pcvar_num(zomb_ap), get_pcvar_num(zomb_speed))
	//client_print(0,print_chat,"%L",LANG_PLAYER,"HELP_MSG")
}

public lightning_effects() {
	
	if(!get_pcvar_num(zomb_switch)) {
		return PLUGIN_HANDLED
	}

	if (get_pcvar_num(zomb_lightning) == 0) {	
		set_lights("#OFF")
		remove_task(12175)
		set_task(20.0,"lightning_effects")
	} else if (get_pcvar_num(zomb_lightning) == 1) {
		//set_lights("a")
		//set_lights("b")
		set_lights("c")
		set_task(random_float(10.0,17.0),"thunder_clap",12175)
	} else if (get_pcvar_num(zomb_lightning) == 2) {
		set_lights("b")
		remove_task(12175)
		set_task(20.0,"lightning_effects")
	}
	
	return PLUGIN_CONTINUE
}

public thunder_clap() {
	
	if(!get_pcvar_num(zomb_switch)) {
		return PLUGIN_HANDLED
	}

	set_lights("p")
	client_cmd(0,"speak ambience/thunder_clap.wav")
	
	set_task(1.25,"lightning_effects",12175)
	
	return PLUGIN_CONTINUE
}

public ambience_loop() {
	
	if(!get_pcvar_num(zomb_switch)) {
		return PLUGIN_HANDLED
	}

	client_cmd(0,"spk eightDaysLater/ambience.wav")
	
	set_task(17.0,"ambience_loop")
	
	return PLUGIN_CONTINUE
}

public fw_Touch(pToucher, pTouched) {

	if(!get_pcvar_num(zomb_switch)) {
		return FMRES_IGNORED
	}

	if ( !pev_valid(pToucher) || !pev_valid(pTouched) ) {
		return FMRES_IGNORED
	}

	if ( !is_user_connected(pTouched) ) {
		return FMRES_IGNORED
	}

	if ( !g_zombie[pTouched] ) {
		return FMRES_IGNORED
	}

	new className[32]
	pev(pToucher, pev_classname, className, 31)
	
	if ( equal(className, "weaponbox") || equal(className, "armoury_entity" ) || equal(className, "weapon_shield" ) ) {
		return FMRES_SUPERCEDE
	}
		
	return FMRES_IGNORED
}  

public fw_EmitSound(id, channel, sample[]) {
	
	if(!get_pcvar_num(zomb_switch)) {
		return FMRES_IGNORED
	}

	if ( !is_user_alive(id) || !g_zombie[id] ) {
		return FMRES_IGNORED
	}

	if ( sample[0] == 'w' && sample[1] == 'e' && sample[8] == 'k' && sample[9] == 'n' ) {
		
		switch(sample[17]) {
			
			case 'l': {
				return FMRES_SUPERCEDE
			}
				
			case 's', 'w': {				
				emit_sound(id, CHAN_WEAPON, miss_zombie[random_num(0, ZOMBIE_MISS - 1)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)	
				return FMRES_SUPERCEDE
			}
			
			case 'b', '1', '2', '3', '4': {
				emit_sound(id, CHAN_WEAPON, hit_zombie[random_num(0, ZOMBIE_HIT - 1)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
				return FMRES_SUPERCEDE
			}
		}
	} else if (equal(sample,"items/nvg_on.wav") || (equal(sample,"items/nvg_off.wav"))) {
		return FMRES_SUPERCEDE
	}

	return FMRES_IGNORED
}

public fw_Cmd(id, handle, seed) {
	
	new impulse = get_uc(handle, UC_Impulse)
	if (impulse == 100 && g_zombie[id]) {
		set_uc(handle, UC_Impulse, 0)
	}
	return FMRES_HANDLED
}

public event_damage_scream(id) {
	
	if(!get_pcvar_num(zomb_switch)) {
		return PLUGIN_HANDLED
	}

	if(!is_user_alive(id)) {
		return PLUGIN_HANDLED
	}

	if (g_zombie[id]) {
		emit_sound(id, CHAN_VOICE, pain_zombie[random_num(0, ZOMBIE_PAIN - 1)], 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
	
	return PLUGIN_HANDLED
}

public event_damage(id) {

	if(!get_pcvar_num(zomb_switch)) {
		return PLUGIN_HANDLED
	}

	if(!is_user_alive(id)) {
		return PLUGIN_HANDLED
	}

	new damage = read_data(2)
	new weapon, hitzone
	new attacker = get_user_attacker(id, weapon, hitzone)
	
	new Float:Random_Float[3]
	for(new i = 0; i < 3; i++) {
		Random_Float[i] = random_float(100.0, 125.0)
	}
	
	new current_hp = get_user_health(attacker)
	new max_hp = get_pcvar_num(zomb_hp)
	new zdmg = get_pcvar_num(zomb_zdmg)
	new hdmg = get_pcvar_num(zomb_hdmg)
	
	current_hp += damage
	
	if (attacker > sizeof g_zombie) {
		return PLUGIN_CONTINUE
	}


	if ( g_zombie[attacker] && weapon == CSW_KNIFE ) {
		
		if (zdmg <= 0) {
			return PLUGIN_CONTINUE
		} else if (damage >= zdmg) {
			Punch_View(id, Random_Float)
		}

		if ( current_hp >= max_hp ) {
			set_user_health(attacker, max_hp)
		} else { 
			set_user_health(attacker, current_hp)	
		}
	} else if ( !g_zombie[attacker] && hitzone == HIT_HEAD) {
		
		if (hdmg <= 0) {
			return PLUGIN_CONTINUE
		} else if (damage >= hdmg) {
			Punch_View(id, Random_Float)
		}
	}

	return PLUGIN_HANDLED
}

public clcmd_say(id) {
	
	if(!get_pcvar_num(zomb_switch)) {
		return PLUGIN_HANDLED
	}

	static ARGS[15]
	read_args(ARGS,14)
	
	remove_quotes(ARGS)
	
	if(equali(ARGS,"/help")) {
		zombie_help(id)
	} else if (equali(ARGS,"/bm")) {
		
		if ( !is_user_alive(id) ) {
			client_print(id, print_center, "%L", id, "BUY_ALIVE")
			return PLUGIN_HANDLED
		} else if ( g_zombie[id] ) {
			client_print(id, print_center, "%L", id, "BUY_HUMAN")
			return PLUGIN_HANDLED
		} else if ( !cs_get_user_buyzone(id) ) {
			client_print(id, print_center, "%L", id, "BUY_BUYZONE")
			return PLUGIN_HANDLED
		} else if (!buying) {
			new Float:time_buy = get_cvar_float("mp_buytime") * 60
			client_print(id, print_center, "%L", id, "BUY_TIME", floatround(time_buy))
			return PLUGIN_HANDLED
		} else {
			show_menu(id, Keysmenu_1, "\yBuy Menu\w^n^n1. .40 Dual Elites     \y($800)\w^n2. INGRAM MAC-10     \y($1400)\w^n3. IDF Defender     \y($2000)\w^n4. CV-47     \y($2500)\w^n5. KREIG 552     \y($3500)\w^n6. D3/AU-1     \y($5000)\w^n^n0. Exit") 
		}
		
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}

public zombie_help(id) {
	
	new help_title[64], len
	static msg[2047]
	format(help_title,63,"%L",id,"HELP_HEADER")
	len = format(msg,2046,"<body bgcolor=#f5f5f5><font color=#000000><br>")
	len += format(msg[len],2046-len,"<center><h2>%L</h2><br><table><tr><td><p><b><font color=#000000>",id,"HELP_TITLE")
	len += format(msg[len],2046-len,"<h2>%L</h2>",id,"HELP_OBJECTIVE")
	len += format(msg[len],2046-len,"%L<br>",id,"HELP_ZOMBIE")
	
	len += format(msg[len],2046-len,"%L<br>",id,"HELP_ZOMBIE_KNIFE")
	len += format(msg[len],2046-len,"%L<br>",id,"HELP_ZOMBIE_NVG")
	
	if (get_pcvar_num(zomb_leap)) {
		len += format(msg[len],2046-len,"%L<br>",id,"HELP_ZOMBIE_LEAP")
	}
		
	if (get_pcvar_num(zomb_zdmg) >= 1) {
		len += format(msg[len],2046-len,"%L<br>",id,"HELP_ZOMBIE_HIT",get_pcvar_num(zomb_zdmg))
	}

	len += format(msg[len],2046-len,"<h2>%L</h2>",id,"HELP_HUMAN")
	len += format(msg[len],2046-len,"%L<br>",id,"HELP_HUMAN_GUNS")
	
	if (get_pcvar_num(zomb_nvg)) {
		len += format(msg[len],2046-len,"%L<br>",id,"HELP_HUMAN_NVG")
	}
		
	if (get_pcvar_num(zomb_hdmg) >= 1) {
		len += format(msg[len],2046-len,"%L<br>",id,"HELP_HUMAN_HIT",get_pcvar_num(zomb_hdmg))
	}

	len += format(msg[len],2046-len,"<h2>%L</h2>",id,"HELP_TIPS")
	len += format(msg[len],2046-len,"%L<br>",id,"HELP_TIPS_ONE")
	len += format(msg[len],2046-len,"%L<br>",id,"HELP_TIPS_TWO")
	
	len += format(msg[len],2046-len,"%L<br>",id,"HELP_ENJOY")
	len += format(msg[len],2046-len,"</b><br></td></tr></table><br>Mini_Midget</center>")
	show_motd(id,msg,help_title)
}

public buy_menu(id, key) {
	
	new money = cs_get_user_money(id)
	
	new dualcost = 800
	new mac10cost = 1400
	new idfcost = 2000
	new akcost = 2500
	new kreigcost = 3500
	new D3cost = 5000
	
	switch (key) {
		
		case 0: {
			if(money < dualcost) {
				client_print(id, print_center, "%L",id, "BUY_MONEY", dualcost)
			} else {
				drop_sec(id)
				cs_set_user_money(id, money - dualcost)  
				give_item(id,"weapon_elite")
			}
		}
		
		case 1: {
			
			if(money < mac10cost) {
				client_print(id, print_center, "%L",id, "BUY_MONEY", mac10cost)
			} else {
				drop_prim(id)
				cs_set_user_money(id, money - mac10cost)  
				give_item(id,"weapon_mac10")
			}
		}
		
		case 2: {
			
			if(money < idfcost) {
				client_print(id, print_center, "%L",id, "BUY_MONEY", idfcost)
			} else {
				drop_prim(id)
				cs_set_user_money(id, money - idfcost)  
				give_item(id,"weapon_galil")
			}
		}
		
		case 3: {
			
			if(money < akcost) {
				client_print(id, print_center, "%L",id, "BUY_MONEY", akcost)
			} else {
				drop_prim(id)
				cs_set_user_money(id, money - akcost)  
				give_item(id,"weapon_ak47")
			}
		}
		
		case 4: {
			
			if(money < kreigcost) {
				client_print(id, print_center, "%L",id, "BUY_MONEY", kreigcost)
			} else {
				drop_prim(id)
				cs_set_user_money(id, money - kreigcost)  
				give_item(id,"weapon_sg552")
			}
		}
		
		case 5: {
			
			if(money < D3cost) {
				client_print(id, print_center, "%L",id, "BUY_MONEY", D3cost)
			} else {
				drop_prim(id)
				cs_set_user_money(id, money - D3cost)  
				give_item(id,"weapon_g3sg1")
			}
		}
		
		case 9: {
			return PLUGIN_HANDLED
		}
	}
	
	return PLUGIN_HANDLED 
}

public message_hostagepos(msg_id,msg_dest,msg_entity) {
	
	if(!get_pcvar_num(zomb_obj)) {
		return PLUGIN_CONTINUE
	}

	return PLUGIN_HANDLED;
}

public message_textmsg(msg_id,msg_dest,msg_entity) {
	
	if(!bombMap || !get_pcvar_num(zomb_obj)) {
		return PLUGIN_CONTINUE;
	}

	static message[16];
	get_msg_arg_string(2, message, 15);

	if(equal(message,"#Game_bomb_drop")) {
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public message_ammopickup(msg_id,msg_dest,msg_entity) {
	
	if(!bombMap || !get_pcvar_num(zomb_obj)) {
		return PLUGIN_CONTINUE;
	}

	if(get_msg_arg_int(1) == 14) { // C4
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public message_bombdrop(msg_id,msg_dest,msg_entity) {
	
	if(!get_pcvar_num(zomb_obj)) {
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public message_scenario(msg_id,msg_dest,msg_entity) {

	if(get_msg_args() > 1 && get_pcvar_num(zomb_obj)) {
		
		new sprite[8];
		get_msg_arg_string(2, sprite, 7);

		if(equal(sprite,"hostage")) {
			return PLUGIN_HANDLED;
		}
	}

	return PLUGIN_CONTINUE;
}

public move_hostages() {
	
	new ent;
	while((ent = fm_find_ent_by_class(ent,"hostage_entity")) != 0)
		set_pev(ent, pev_origin, Float:{8192.0,8192.0,8192.0});
}

public Forward_EmitSound(id, channel, sample[], Float:volume, Float:attn, flag, pitch) {

	if(!is_user_connected(id)) {
		return FMRES_IGNORED;
	}

	if(g_zombie[id]) {
  
    if (sample[7] == 'd' && (sample[8] == 'i' && sample[9] == 'e' || sample[12] == '6')) {
			emit_sound(id, CHAN_VOICE, g_sound_die[random(sizeof g_sound_die)], volume, attn, flag, pitch);
			return FMRES_SUPERCEDE;
		}
  }

	return FMRES_IGNORED;
}


//Stocks by VEN
stock drop_prim(id) {
	
	new weapons[32], num
	
	get_user_weapons(id, weapons, num)
	
	for (new i = 0; i < num; i++) {
		
		if (PRIMARY_WEAPONS_BIT_SUM & (1<<weapons[i])) {
			static wname[32]
			get_weaponname(weapons[i], wname, sizeof wname - 1)
			engclient_cmd(id, "drop", wname)
		}
	}
}

stock drop_sec(id) {
	
	new weapons[32], num
	get_user_weapons(id, weapons, num)
	
	for (new i = 0; i < num; i++) {
		
		if (SECONDARY_WEAPONS_BIT_SUM & (2<<weapons[i])) {
			static wname[32]
			get_weaponname(weapons[i], wname, sizeof wname - 1)
			engclient_cmd(id, "drop", wname)
		}
	}
}

//Stock by Cheap_Suit
stock Punch_View(id, Float:ViewAngle[3]) {
	entity_set_vector(id, EV_VEC_punchangle, ViewAngle)
}

//Stock by v3x
stock maxclip(weapon) {
	
	new ca = 0
	
	switch (weapon) {
		case CSW_P228 : ca = 13
		case CSW_SCOUT : ca = 10
		case CSW_HEGRENADE : ca = 0
		case CSW_XM1014 : ca = 7
		case CSW_C4 : ca = 0
		case CSW_MAC10 : ca = 30
		case CSW_AUG : ca = 30
		case CSW_SMOKEGRENADE : ca = 0
		case CSW_ELITE : ca = 30
		case CSW_FIVESEVEN : ca = 20
		case CSW_UMP45 : ca = 25
		case CSW_SG550 : ca = 30
		case CSW_GALI : ca = 35
		case CSW_FAMAS : ca = 25
		case CSW_USP : ca = 12
		case CSW_GLOCK18 : ca = 20
		case CSW_AWP : ca = 10
		case CSW_MP5NAVY : ca = 30
		case CSW_M249 : ca = 100
		case CSW_M3 : ca = 8
		case CSW_M4A1 : ca = 30
		case CSW_TMP : ca = 30
		case CSW_G3SG1 : ca = 20
		case CSW_FLASHBANG : ca = 0;
		case CSW_DEAGLE    : ca = 7
		case CSW_SG552 : ca = 30
		case CSW_AK47 : ca = 30
		case CSW_P90 : ca = 50
	}
	return ca;
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ ansicpg1252\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang5129\\ f0\\ fs16 \n\\ par }
*/
