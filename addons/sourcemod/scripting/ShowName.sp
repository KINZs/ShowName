#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <clientprefs>
#include <colors_csgo>
#undef REQUIRE_PLUGIN
#include <zombiereloaded>
#define REQUIRE_PLUGIN

Handle hShowNameCookie;
bool bClientShowHUD[MAXPLAYERS] = {false, ...};

bool bLateLoad = false;
bool bValid_zombiereloaded = false;

public Plugin myinfo = {
	name = "[CS:GO] Simple Show Name",
	description = "Show name of aimed target under the crosshair",
	author = "SHUFEN from POSSESSION.tokyo",
	version = "1.0",
	url = "https://possession.tokyo"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	RegPluginLibrary("ShowName");

	bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart() {
	LoadTranslations("common.phrases");
	LoadTranslations("ShowName.phrases");

	RegConsoleCmd("sm_showname", Command_ShowHud);
	hShowNameCookie = RegClientCookie("showname_cookie", "ShowName", CookieAccess_Protected);

	SetCookieMenuItem(PrefMenu, 0, "");

	if(bLateLoad) {
		for(int i = 1; i <= MaxClients; i++) {
			if(IsClientInGame(i)) {
				if(AreClientCookiesCached(i))
					OnClientCookiesCached(i);
				OnClientPutInServer(i);
			}
		}
	}
}

public void OnAllPluginsLoaded() {
	bValid_zombiereloaded = LibraryExists("zombiereloaded");
}

public void OnClientCookiesCached(int client) {
	char sCookieValue[2];
	GetClientCookie(client, hShowNameCookie, sCookieValue, sizeof(sCookieValue));
	if(sCookieValue[0] == '\0') {
		SetClientCookie(client, hShowNameCookie, "1");
		strcopy(sCookieValue, sizeof(sCookieValue), "1");
	}
	bClientShowHUD[client] = view_as<bool>(StringToInt(sCookieValue));
}

public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
}

public void OnClientDisconnect(int client) {
	SDKUnhook(client, SDKHook_PostThinkPost, OnPostThinkPost);
	bClientShowHUD[client] = false;
}

public void PrefMenu(int client, CookieMenuAction actions, any info, char[] buffer, int maxlen) {
	if (actions == CookieMenuAction_DisplayOption) {
		FormatEx(buffer, maxlen, "%T: %T", "ShowName", client, bClientShowHUD[client] ? "Enabled" : "Disabled", client);
	}

	if (actions == CookieMenuAction_SelectOption) {
		if(bClientShowHUD[client]) {
			bClientShowHUD[client] = false;
			CPrintToChat(client, "\x10[\x09ShowName\x10]\x05 ShowName has been \x04Disabled\x05.");
		} else {
			bClientShowHUD[client] = true;
			CPrintToChat(client, "\x10[\x09ShowName\x10]\x05 ShowName has been \x04Enabled\x05.");
		}

		char sCookieValue[2];
		IntToString(view_as<int>(bClientShowHUD[client]), sCookieValue, sizeof(sCookieValue));
		SetClientCookie(client, hShowNameCookie, sCookieValue);
		ShowCookieMenu(client);
	}
}

public Action Command_ShowHud(int client, int args) {
	if(!AreClientCookiesCached(client)) {
		CReplyToCommand(client, "\x10[\x09ShowName\x10]\x05 Please wait. Your settings are still loading.");
		return Plugin_Handled;
	}
	
	if(bClientShowHUD[client]) {
		bClientShowHUD[client] = false;
		CReplyToCommand(client, "\x10[\x09ShowName\x10]\x05 ShowName has been \x04Disabled\x05.");
	} else {
		bClientShowHUD[client] = true;
		CReplyToCommand(client, "\x10[\x09ShowName\x10]\x05 ShowName has been \x04Enabled\x05.");
	}
	
	char sCookieValue[2];
	IntToString(view_as<int>(bClientShowHUD[client]), sCookieValue, sizeof(sCookieValue));
	SetClientCookie(client, hShowNameCookie, sCookieValue);
	
	return Plugin_Handled;
}

public void OnPostThinkPost(int client) {
	if (bClientShowHUD[client] && IsClientInGame(client)) {
		int iClientTeam = GetClientTeam(client);
		int target = GetClientAimTarget2(client);
		if(target > 0 && target <= MaxClients && IsClientInGame(target) && IsPlayerAlive(target)) {
			if(bValid_zombiereloaded) {
				bool bIsClientHuman = false;
				if((IsPlayerAlive(client) && ZR_IsClientHuman(client)) || iClientTeam == CS_TEAM_CT) bIsClientHuman = true;
				bool bIsTargetHuman = ZR_IsClientHuman(target);
				if(bIsTargetHuman) {
					if(iClientTeam > 1 && iClientTeam <= CS_TEAM_CT)
						ShowName(client, "Human", {154, 205, 255, 255}, target, bIsClientHuman);
					else {
						char client_specmode[10];
						GetClientInfo(client, "cl_spec_mode", client_specmode, 9);
						if(StringToInt(client_specmode) == 6)
							ShowName(client, "Human", {154, 205, 255, 255}, target, true);
					}
				} else {
					if(iClientTeam > 1 && iClientTeam <= CS_TEAM_CT)
						ShowName(client, "Zombie", {255, 62, 62, 255}, target, !bIsClientHuman);
					else {
						char client_specmode[10];
						GetClientInfo(client, "cl_spec_mode", client_specmode, 9);
						if(StringToInt(client_specmode) == 6)
							ShowName(client, "Zombie", {255, 62, 62, 255}, target, true);
					}
				}
			} else {
				int iTargetTeam = GetClientTeam(target);
				if(iTargetTeam == CS_TEAM_CT) {
					if(iClientTeam == iTargetTeam)
						ShowName(client, "Friend", {154, 205, 255, 255}, target, true);
					else if(iClientTeam > 1 && iClientTeam <= CS_TEAM_CT)
						ShowName(client, "Enemy", {154, 205, 255, 255}, target, false);
					else {
						char client_specmode[10];
						GetClientInfo(client, "cl_spec_mode", client_specmode, 9);
						if(StringToInt(client_specmode) == 6)
							ShowName(client, "", {154, 205, 255, 255}, target, true);
					}
				}
				else {
					if(iClientTeam == iTargetTeam)
						ShowName(client, "Friend", {255, 62, 62, 255}, target, true);
					else if(iClientTeam > 1 && iClientTeam <= CS_TEAM_CT)
						ShowName(client, "Enemy", {255, 62, 62, 255}, target, false);
					else {
						char client_specmode[10];
						GetClientInfo(client, "cl_spec_mode", client_specmode, 9);
						if(StringToInt(client_specmode) == 6)
							ShowName(client, "", {255, 62, 62, 255}, target, true);
					}
				}
			}
		}
	}
}

stock int GetClientAimTarget2(int client) {
	float fPosition[3];
	float fAngles[3];
	GetClientEyePosition(client, fPosition);
	GetClientEyeAngles(client, fAngles);

	Handle hTrace = TR_TraceRayFilterEx(fPosition, fAngles, MASK_SOLID, RayType_Infinite, TraceRayFilter, client);

	if(TR_DidHit(hTrace)) {
		int entity = TR_GetEntityIndex(hTrace);
		delete hTrace;
		return entity;
	}

	delete hTrace;
	return -1;
}

public bool TraceRayFilter(int entity, int mask, any client) {
	if(entity == client)
		return false;

	return true;
}

void ShowName(int client, char[] sPhrase, int iColor[4], int target, bool bShowHealth) {
	SetHudTextParamsEx(-1.0, 0.52, 0.2, iColor, {0, 0, 0, 255}, 0, 0.0, 0.0, 0.0);
	char sBuffer[128];
	if(sPhrase[0] == '\0')
		FormatEx(sBuffer, sizeof(sBuffer), "%N %T: #%i %T: %i", target, "UserID", client, GetClientUserId(target), "Health", client, GetClientHealth(target));
	else if(bShowHealth)
		FormatEx(sBuffer, sizeof(sBuffer), "%T: %N %T: #%i %T: %i", sPhrase, client, target, "UserID", client, GetClientUserId(target), "Health", client, GetClientHealth(target));
	else
		FormatEx(sBuffer, sizeof(sBuffer), "%T: %N %T: #%i", sPhrase, client, target, "UserID", client, GetClientUserId(target));
	ShowHudText(client, 5, sBuffer);
}