#pragma semicolon 1
#pragma tabsize 0
#define DEBUG

#define PREFIX " \x04[Bounty-System]\x01"
#define MENUPREFIX "[Bounty Menu]"
#include <sourcemod>
#include <sdktools>
#include <store>
#include <multicolors>


#pragma newdecls required
ConVar g_cvMinAmount;
ConVar g_cvMaxAmount;
ConVar g_cvInfiniteUse;
ConVar g_cvColoredBounty;
ConVar g_cvMinPlayers;
ConVar g_cvBountyOnT;
ConVar g_cvBountyOnCT;
int g_iManualAmount[MAXPLAYERS + 1] = 0;
bool g_bTypingAmount[MAXPLAYERS + 1] = false;
bool g_bounted[MAXPLAYERS + 1] = false;
bool g_usedandtarget[MAXPLAYERS + 1][MAXPLAYERS + 1];
int g_bountyamount[MAXPLAYERS + 1] = 0;
int g_setbountyamount[MAXPLAYERS + 1] = 0;
bool g_alreadyused[MAXPLAYERS + 1] = false;
int playeramount = 0;
int availableplayers = 0;
public Plugin myinfo = 
{
	name = "Bounty System - Zephyrus Store",
	author = "SheriF",
	description = "Set Bounty on a player using Zephyrus Store credits",
	version = "1.00",
	url = ""
};

public void OnPluginStart()
{
	g_cvMinAmount = CreateConVar("sm_bounty_min_amount", "50", "The minimum amount of Credits to use the bounty system");
	g_cvMaxAmount = CreateConVar("sm_bounty_max_amount", "500", "The maximum amount of Credits to use the bounty system");
	g_cvInfiniteUse = CreateConVar("sm_infiniteuse_bounty", "0", "1-Enable 0-Disable infinite use of bounty per round");
	g_cvColoredBounty = CreateConVar("sm_coloredbounty", "1", "1-Enable 0-Disable colored bounty player");
	g_cvMinPlayers = CreateConVar("sm_min_players_required", "1", "The amount of players in the server that required to use the bounty system");
	g_cvBountyOnT = CreateConVar("sm_bounty_on_t", "1", "1-Enable 0-Disable the bounty on Terrorists");
	g_cvBountyOnCT = CreateConVar("sm_bounty_on_ct", "1", "1-Enable 0-Disable the bounty on Counter - Terrorists");
	RegConsoleCmd("sm_bounty", bounty);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_end", Event_RoundEnd);
	AutoExecConfig(true, "store_bounty");
	LoadTranslations("common.phrases.txt");
}
public Action bounty(int client,int args)
{
	for(int i = 1; i <= MaxClients;i++)
	{
		if(IsClientInGame(i)&&!IsFakeClient(i))
		playeramount++;
	}
	if(IsClientInGame(client)&&!IsFakeClient(client)&&g_cvMinPlayers.IntValue<=playeramount)
	ShowMainMenu(client);
	else
	CPrintToChat(client,"%s The minimum amount of players required to set bounty is \x07%d\x01 players", PREFIX, g_cvMinPlayers.IntValue);
	return Plugin_Handled;
}
public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int userid = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	for (int i = 1; i <= MaxClients;i++)
	{	if(IsClientInGame(i)&&!IsFakeClient(i))
		{
			if(userid==attacker && g_usedandtarget[i][attacker] &&i!=attacker)
			{
				CPrintToChatAll("%s Since \x0C%N\x01 suicided. \x0C%N\x01 got the bounty he set on \x0C%N\x01.", PREFIX, attacker, i, attacker);
				Store_SetClientCredits(i, Store_GetClientCredits(i) +g_setbountyamount[i]);
				g_usedandtarget[i][attacker] = false;
			}
			else if(userid==attacker && g_usedandtarget[i][i])
			{
				CPrintToChat(i,"%s Since you suicided. You got the bounty back.", PREFIX);
				Store_SetClientCredits(i, Store_GetClientCredits(i) +g_setbountyamount[i]);
				g_usedandtarget[i][i] = false;
			}
		}	
	}
	if(g_bounted[userid]&&userid!=attacker)
	{
		Store_SetClientCredits(attacker, Store_GetClientCredits(attacker) + g_bountyamount[userid]);
		CPrintToChatAll("%s \x0C%N\x01 won the bounty on \x0C%N\x01. He got \x10%d\x01 Credits", PREFIX, attacker, userid, g_bountyamount[userid]);
	}
	return Plugin_Handled;
}
public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients;i++)
	{
		if(g_bounted[i]&&IsClientInGame(i)&&!IsFakeClient(i)&&IsPlayerAlive(i))
		{
			Store_SetClientCredits(i, Store_GetClientCredits(i) + g_bountyamount[i]);
			CPrintToChatAll("%s \x0C%N\x01 won the bounty that set on him. He got \x10%d\x01 Credits", PREFIX, i, g_bountyamount[i]);
		}
		if(g_alreadyused[i])
		{
			g_alreadyused[i] = false;
		}
		g_bounted[i] = false;
	}
}
void ShowMainMenu(int client)
{
	Menu BountyMenu = new Menu(menuHandler_BountyMenu);
	BountyMenu.SetTitle("%s", MENUPREFIX);
	char szItem1[64];
	Format(szItem1, sizeof(szItem1), "Current Amount : %i\n[Press to Change]", g_iManualAmount[client]);
	BountyMenu.AddItem("", szItem1);
	BountyMenu.AddItem("", "Select a player");
	BountyMenu.ExitButton = true;
	BountyMenu.Display(client, MENU_TIME_FOREVER);
}
public int menuHandler_BountyMenu(Menu menu, MenuAction action, int client, int itemNUM)
{
	if (action == MenuAction_Select)
	{
		switch (itemNUM)
		{
			case 0:
			{
				g_bTypingAmount[client] = true;
				CPrintToChat(client, "%s Please type an amount of credits in chat",PREFIX);
			}
			case 1:
			{
				if (Store_GetClientCredits(client) < g_iManualAmount[client])
					CPrintToChat(client, "%s You dont have enough credits to set a bounty on a player",PREFIX);
				else
				{
					Menu BountyMenu1 = new Menu(menuHandler_BountyMenu1);
		 			for (int i = 1; i <= MaxClients; i++)
					{
						if(IsClientInGame(i)&&!IsFakeClient(i)&&IsPlayerAlive(i)&&g_cvBountyOnT.IntValue==1&&GetClientTeam(i)==2)
						{
        					char szItem1[64];
							Format(szItem1, sizeof(szItem1),"%N",i);
        					BountyMenu1.AddItem(szItem1,szItem1);
        					availableplayers++;
        				}
        				if(IsClientInGame(i)&&!IsFakeClient(i)&&IsPlayerAlive(i)&&g_cvBountyOnCT.IntValue==1&&GetClientTeam(i)==3)
						{
        					char szItem1[64];
							Format(szItem1, sizeof(szItem1),"%N",i);
        					BountyMenu1.AddItem(szItem1,szItem1);
        					availableplayers++;
        				}
   					}
						if(availableplayers==0)
						{
							CPrintToChat(client, "%s There are not available players to set a bounty on",PREFIX);
						}					
						BountyMenu1.SetTitle("%s Alive players", MENUPREFIX);
						BountyMenu1.ExitButton = false;
						BountyMenu1.Display(client, MENU_TIME_FOREVER);
						availableplayers = 0;
				}
			}
		}
	}
}
public int menuHandler_BountyMenu1 (Menu menu, MenuAction action, int client, int ItemNum)
{
	if (action == MenuAction_Select)
	{
		if(g_cvInfiniteUse.IntValue==1)
		{
			g_alreadyused[client] = false;
		}
		if(g_alreadyused[client])
		{
		CPrintToChat(client,"%s You can use the bounty system once in a round", PREFIX);
		}
		else if(g_iManualAmount[client]==0)
		{
			CPrintToChat(client, "%s Minimum amount of Credits is \x10%i", PREFIX, g_cvMinAmount.IntValue);
		}
		else
		{
		char sztarget[MAX_NAME_LENGTH];
		menu.GetItem(ItemNum,sztarget, sizeof(sztarget));
		int itarget = FindTarget(client, sztarget, true, false);
		g_usedandtarget[client][itarget]=true;
		g_bounted[itarget] = true;
		g_alreadyused[client] = true;
		if(g_cvColoredBounty.IntValue==1)
		{
			SetEntityRenderColor(itarget,255, 0, 0, 0);
		}
		CPrintToChatAll("%s \x0C%N\x01 set a bounty on \x0C%N\x01 of \x10%d\x01 Credits", PREFIX, client, itarget, g_iManualAmount[client]);
		Store_SetClientCredits(client, Store_GetClientCredits(client) - g_iManualAmount[client]);
		g_bountyamount[itarget] = g_iManualAmount[client];
		g_setbountyamount[client] = g_iManualAmount[client];
		}
	}
}
public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if (g_bTypingAmount[client])
	{
		if (IsNumeric(sArgs))
		{
			int iMinAmount = g_cvMinAmount.IntValue;
			int iMaxAmount = g_cvMaxAmount.IntValue;
			int iAmount = StringToInt(sArgs);
			if (iAmount < iMinAmount)
			{
				CPrintToChat(client, "%s Minimum amount of Credits is \x10%i", PREFIX, iMinAmount);
				return Plugin_Handled;
			}
			else if (iAmount > iMaxAmount)
			{
				CPrintToChat(client, "%s Maximum amount of Credits is \x10%i", PREFIX, iMaxAmount);
				return Plugin_Handled;
			}
			g_iManualAmount[client] = iAmount;
			CPrintToChat(client, "%s You chose \x10%i\x01 Credits to play with", PREFIX, iAmount);
		}
		else
			PrintToChat(client, "%s You can type only numbers..", PREFIX);
		
		ShowMainMenu(client);
		g_bTypingAmount[client] = false;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}
stock bool IsNumeric(const char[] buffer)
{
	int iLen = strlen(buffer);
	for (int i = 0; i < iLen; i++)
	{
		if (!IsCharNumeric(buffer[i]))
			return false;
	}
	return true;
}
