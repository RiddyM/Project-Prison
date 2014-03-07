/*
	 _______________________________________________________________________________
	|                                                                               |
	|                                                                               |
	|            ************************************************				    |
	|            *                                              *                   |
	|            *         PRISON ROLEPLAY - EDITION 0.1V		*                   |
	|            *                                              *                   |
	|            *                                              *                   |
	|            ************************************************                   |
	|                                                                               |
	|                                                                               |
	|_______________________________________________________________________________|
	
*/

#include <a_samp>
#include <streamer>
#include <sscanf2>
#include <a_mysql>
#include <zcmd>
#include <foreach>

main() { }

// DEFINES

#define MAX_CELLS 50
#define MAX_CELLMATES 5

#define INVALID_NUMBER 0xFFFF


#define MYSQL_HOST "localhost"
#define MYSQL_USER "root"
#define MYSQL_PASS ""
#define MYSQL_DB "project_prison"

// DIALOG DEFINES

#define DIALOG_REGISTER 0
#define DIALOG_LOGIN 1

// VARS

new connHandle = 0;
new gCells = 0;

new Iterator:prisonCells<MAX_CELLS>;

new editingCell[MAX_PLAYERS];
new editingOpenDoor[MAX_PLAYERS];

// ENUMS

enum playerInfo 
{
	userID,
	uIP[16],
	uCell,
	Float:uXPos,
	Float:uYPos,
	Float:uZPos,
}
new AccountInfo[MAX_PLAYERS][playerInfo];

enum cInfo 
{
	cellID,
	cellRoster[MAX_PLAYER_NAME*MAX_CELLMATES],
	cellobjID,
	Float:cellDoorX,
	Float:cellDoorY,
	Float:cellDoorZ,
	Float:cellRotX,
	Float:cellRotZ,
	Float:cellRotY,
	Float:cellODoorX,
	Float:cellODoorY,
	Float:cellODoorZ,
	Float:cellORotX,
	Float:cellORotY,
	Float:cellORotZ,
	Float:cellSpeed,
	creationTime,
	cellLocked,
}
new cellInfo[MAX_CELLS][cInfo];
	
// SA-MP Callbacks

public OnGameModeInit() 
{

	connHandle = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_DB, MYSQL_PASS);

	mysql_debug(connHandle);

	LoadObject();

	mysql_tquery(connHandle, "SELECT * FROM pp_cells", "LoadCells", "");

	printf("Cells Loaded: %d", gCells);
	return 1;
}

public OnGameModeExit()
{
	foreach( new i : prisonCells)
		SaveCell(i);

	mysql_close(connHandle);
}


public OnPlayerConnect(playerid) 
{

	new query[94];
	format(query, sizeof(query), "SELECT Password FROM pp_accs WHERE Username = '%s' LIMIT 1", PlayerName(playerid));
	mysql_tquery(connHandle, query, "CheckUser", "i", playerid);
	
	RemoveBuilding(playerid);
	return 1;
}

public OnPlayerDisconnect(playerid) 
{
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[]) 
{
	if(dialogid == DIALOG_REGISTER) 
	{
		new str[25];
	    if(!response) return Kick(playerid);
	    if(strlen(inputtext) > 24 || strlen(inputtext) < 8)
			return SendClientMessage(playerid, 0xFFFFFF, "[ERR]: Password has to be atleast larger than 7 chars and lower than 24 chars");
		mysql_real_escape_string(inputtext, str, connHandle, sizeof(str));

		RegisterPlayer(playerid, str);
	}
	if(dialogid == DIALOG_LOGIN)
	{
		new query[300], str[25];
		mysql_real_escape_string(inputtext, str, connHandle, sizeof(str));
		format(query, sizeof(query), "SELECT * FROM pp_accs WHERE Username = '%s'", PlayerName(playerid));
		mysql_tquery(connHandle, query, "LoginPlayer", "si", playerid, str);
	}
	return 1;
}

public OnPlayerEditDynamicObject(playerid, objectid, response, Float:x, Float:y, Float:z, Float:rx, Float:ry, Float:rz)
{
	foreach(new cell : prisonCells)
	{
		if(objectid == cellInfo[cell][cellobjID])
		{
			if(response == EDIT_RESPONSE_FINAL)
			{
				if(editingCell[playerid] == objectid)
				{
					cellInfo[cell][cellDoorX] = x;
					cellInfo[cell][cellDoorY] = y;
					cellInfo[cell][cellDoorZ] = z;

					cellInfo[cell][cellRotX] = rx;
					cellInfo[cell][cellRotY] = ry;
					cellInfo[cell][cellRotZ] = rz;

					editingCell[playerid] = INVALID_NUMBER;

					editingOpenDoor[playerid] = objectid;

					EditDynamicObject(playerid, objectid);

					SendClientMessage(playerid, 0xFFFFFFAA, "Set a position for the door to open to");

				}
				else if(editingOpenDoor[playerid] == objectid)
				{
					cellInfo[cell][cellODoorX] = x;
					cellInfo[cell][cellODoorY] = y;
					cellInfo[cell][cellODoorZ] = z;

					cellInfo[cell][cellORotX] = rx;
					cellInfo[cell][cellORotY] = ry;
					cellInfo[cell][cellORotZ] = rz;

					editingOpenDoor[playerid] = INVALID_NUMBER;

					SendClientMessage(playerid, 0xFFFFFFAA, "You have just set the opened position");
				}
				else return SendClientMessage(playerid, 0xFFFFFFAA, "You aren't editing the correct object");
			}
		}
	}
	return 1;
}

// COMMANDS

CMD:createcell(playerid, params[])
{
	new Float:playX, Float:playY, Float:playZ;
	GetPlayerPos(playerid, playX, playY, playZ);

	new query[300];
	format(query, sizeof(query), "INSERT INTO pp_cells (creationTime, cellDoorX, cellDoorY, cellDoorZ) VALUES (%d, %f, %f, %f)", 
	GetTickCount(),
	playX, playY, playZ);

	mysql_tquery(connHandle, query, "", "");

	new latestID = getLatestCellID();

	new index = Iter_Free(prisonCells);

	if(index == -1)
		return SendClientMessage(playerid, 0xFF00FF00, "THE CONSTANT [MAX_CELLS] HAS REACHED IT'S MAXIMUM, PLEASE INCREASE THIS!");

	Iter_Add(prisonCells, index);

	cellInfo[index][cellID] = latestID;

	cellInfo[index][cellDoorX] = playX+1.0;
	cellInfo[index][cellDoorY] = playY;
	cellInfo[index][cellDoorZ] = playZ;

	cellInfo[index][cellRotX] = 0;
	cellInfo[index][cellRotY] = 0;
	cellInfo[index][cellRotZ] = 0;

	cellInfo[index][creationTime] = GetTickCount();

	cellInfo[index][cellobjID] = CreateDynamicObject(19303, playX+1.0, playY, playZ, cellInfo[index][cellRotX], cellInfo[index][cellRotY], cellInfo[index][cellRotZ]);

	editingCell[playerid] = cellInfo[index][cellobjID];

	EditDynamicObject(playerid, cellInfo[index][cellobjID]);

	return 1;
}

// Custom Callbacks

forward getLatestCellID();
public getLatestCellID()
{
	new Cache: r = mysql_query(connHandle, "SELECT id FROM pp_cells ORDER BY id DESC LIMIT 1");
	new id;

	cache_set_active(r);

	if(cache_get_row_count(connHandle))
	{
		id = cache_get_row_int(0, 0);
	}

	cache_delete(r);

	return id;
}

//----- MySQL

// Login

forward CheckUser(playerid);
public CheckUser(playerid) 
{
    new rows, fields;
    cache_get_data(rows, fields);
    if(rows)
    {
		new query[94];
		format(query, sizeof(query), "SELECT * FROM pp_accs WHERE Username = '%s'", PlayerName(playerid));
		mysql_tquery(connHandle, query, "LoginPlayer", "i", playerid);
	}
	else 
	{
		new string[94];
		format(string, sizeof(string),
		"[**] Welcome to Project Prison Roleplay, %s[**]\n\
		Please enter a password to continue on!", PlayerName(playerid));
		ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_INPUT, "Proj Prison", string, "Ok", "Cancel");
	}
	return 1;
}

forward LoginPlayer(playerid, password[]);
public LoginPlayer(playerid, password[]) 
{
	new rows, fields;
	cache_get_data(rows, fields);
	if(rows) 
	{
	    AccountInfo[playerid][userID] = cache_get_row_int(0, 0);
	    AccountInfo[playerid][uCell] = cache_get_row_int(0, 4);
		AccountInfo[playerid][uXPos] = cache_get_row_float(0, 5);
		AccountInfo[playerid][uYPos] = cache_get_row_float(0, 6);
		AccountInfo[playerid][uZPos] = cache_get_row_float(0, 7);
	}
	return 1;
}

forward RegisterPlayer(playerid, password[]);
public RegisterPlayer(playerid, password[])
{
	new query[300];
	format(query, sizeof(query), "INSERT INTO pp_accounts (Username, Password) VALUES ('%s', '%s')",
	PlayerName(playerid),
	password);

	mysql_tquery(connHandle, query, "", "");

	return 1;
}

// Cells

forward LoadCells();
public LoadCells() 
{
	new rows, fields;
	cache_get_data(rows, fields);
	if(rows)
	{
	    for(new i = 0; i < rows; i++)
	    {
	    	new index = Iter_Free(prisonCells);

	        cellInfo[i][cellID] = cache_get_row_int(i, 0);
			cellInfo[i][cellDoorX] = cache_get_row_float(i, 1);
			cellInfo[i][cellDoorY] = cache_get_row_float(i, 2);
			cellInfo[i][cellDoorZ] = cache_get_row_float(i, 3);
			cellInfo[i][cellRotX] = cache_get_row_float(i, 4);
			cellInfo[i][cellRotY] = cache_get_row_float(i, 5);
			cellInfo[i][cellRotZ] = cache_get_row_float(i, 6);
			cellInfo[i][cellODoorX] = cache_get_row_float(i, 7);
			cellInfo[i][cellODoorY] = cache_get_row_float(i, 8);
			cellInfo[i][cellODoorZ] = cache_get_row_float(i, 9);
			cellInfo[i][cellORotX] = cache_get_row_float(i, 10);
			cellInfo[i][cellORotY] = cache_get_row_float(i, 11);
			cellInfo[i][cellORotZ] = cache_get_row_float(i, 12);
			cellInfo[i][cellSpeed] = cache_get_row_float(i, 13);
			cellInfo[i][cellLocked] = cache_get_row_int(i, 14);

			Iter_Add(prisonCells, index);

			cellInfo[i][cellobjID] = 
				CreateDynamicObject(19303, cellInfo[i][cellDoorX], cellInfo[i][cellDoorY], cellInfo[i][cellDoorZ], cellInfo[i][cellODoorX],cellInfo[i][cellODoorY], cellInfo[i][cellODoorZ]);
		}
		
		gCells = rows;
	}
	return 1;
}

stock SaveCell(cell) 
{
	new string[300];
	format(string, sizeof(string), 
	"UPDATE pp_cells SET cellDoorX = %f, cellDoorY = %f, cellDoorZ = %f, cellODoorX = %f, cellRotX = %f, cellRotY = %f, cellRotZ = %f,\
	cellODoorX = %f, cellODoorY = %f, cellODoorZ = %f, cellORotX = %f, cellORotY = %f, cellORotZ = %f, cellSpeed = %f, cellLocked = %d\
	WHERE cID = %d",
	cellInfo[cell][cellDoorX],
	cellInfo[cell][cellDoorY],
	cellInfo[cell][cellDoorZ],
	cellInfo[cell][cellRotX],
	cellInfo[cell][cellRotY],
	cellInfo[cell][cellRotZ],
	cellInfo[cell][cellODoorX],
	cellInfo[cell][cellODoorY],
	cellInfo[cell][cellODoorZ],
	cellInfo[cell][cellORotX],
	cellInfo[cell][cellORotY],
	cellInfo[cell][cellORotZ],
	cellInfo[cell][cellLocked],
	cellInfo[cell][cellSpeed],
	cellInfo[cell][cellID]);

	mysql_tquery(connHandle, string, "", "");
}


// Stocks

stock PlayerName(playerid) 
{
	new name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, sizeof(name));
	return name;
}

stock LoadObject() 
{
	return 1;
}

stock RemoveBuilding(playerid) 
{
    RemoveBuildingForPlayer(playerid, 11010, -2113.3203, -186.7969, 40.2813, 0.25);
	RemoveBuildingForPlayer(playerid, 11012, -2166.8672, -236.5078, 40.8672, 0.25);
	RemoveBuildingForPlayer(playerid, 11048, -2113.3203, -186.7969, 40.2813, 0.25);
	RemoveBuildingForPlayer(playerid, 11088, -2166.8750, -236.5156, 40.8594, 0.25);
	RemoveBuildingForPlayer(playerid, 11091, -2133.5547, -132.7031, 36.1328, 0.25);
	RemoveBuildingForPlayer(playerid, 11270, -2166.8672, -236.5078, 40.8672, 0.25);
	RemoveBuildingForPlayer(playerid, 11271, -2127.5469, -269.9609, 41.0000, 0.25);
	RemoveBuildingForPlayer(playerid, 11282, -2166.8750, -236.5156, 40.8594, 0.25);
	RemoveBuildingForPlayer(playerid, 11376, -2144.3516, -132.9609, 38.3359, 0.25);
	RemoveBuildingForPlayer(playerid, 11081, -2127.5469, -269.9609, 41.0000, 0.25);
	RemoveBuildingForPlayer(playerid, 11011, -2144.3516, -132.9609, 38.3359, 0.25);
	RemoveBuildingForPlayer(playerid, 11009, -2128.5391, -142.8438, 39.1406, 0.25);
	RemoveBuildingForPlayer(playerid, 11007, -2164.4531, -248.0000, 40.7813, 0.25);
	RemoveBuildingForPlayer(playerid, 11085, -2164.4531, -237.6172, 41.4063, 0.25);
	RemoveBuildingForPlayer(playerid, 11086, -2164.4531, -237.3906, 43.4219, 0.25);
	RemoveBuildingForPlayer(playerid, 11087, -2143.2266, -261.2422, 38.0938, 0.25);
	RemoveBuildingForPlayer(playerid, 11089, -2185.5234, -263.9297, 38.7656, 0.25);
	RemoveBuildingForPlayer(playerid, 11090, -2158.8203, -266.2344, 36.2266, 0.25);
	RemoveBuildingForPlayer(playerid, 1432, -2144.8281, -244.7656, 35.6250, 0.25);
	RemoveBuildingForPlayer(playerid, 1438, -2188.6953, -218.3828, 35.5078, 0.25);
	RemoveBuildingForPlayer(playerid, 1441, -2184.6484, -226.8750, 36.1641, 0.25);
	RemoveBuildingForPlayer(playerid, 1449, -2160.6406, -226.3516, 36.0234, 0.25);
	RemoveBuildingForPlayer(playerid, 1450, -2189.4375, -220.4922, 36.0859, 0.25);
	RemoveBuildingForPlayer(playerid, 1518, -2147.1797, -241.8750, 36.7422, 0.25);
	RemoveBuildingForPlayer(playerid, 918, -2182.4453, -237.6953, 35.8750, 0.25);
	RemoveBuildingForPlayer(playerid, 931, -2154.2031, -254.2422, 36.5781, 0.25);
	RemoveBuildingForPlayer(playerid, 936, -2139.5078, -244.7813, 35.9922, 0.25);
	RemoveBuildingForPlayer(playerid, 937, -2147.2109, -242.0156, 35.9922, 0.25);
	RemoveBuildingForPlayer(playerid, 939, -2179.3359, -239.0859, 37.9609, 0.25);
	RemoveBuildingForPlayer(playerid, 941, -2175.0547, -248.0469, 35.9922, 0.25);
	RemoveBuildingForPlayer(playerid, 942, -2159.0625, -239.0625, 37.9609, 0.25);
	RemoveBuildingForPlayer(playerid, 941, -2171.5000, -248.0469, 35.9922, 0.25);
	RemoveBuildingForPlayer(playerid, 941, -2167.9688, -248.0469, 35.9922, 0.25);
	RemoveBuildingForPlayer(playerid, 941, -2164.3281, -248.0469, 35.9922, 0.25);
	RemoveBuildingForPlayer(playerid, 941, -2161.0156, -248.0469, 35.9922, 0.25);
	RemoveBuildingForPlayer(playerid, 941, -2157.4453, -248.0469, 35.9922, 0.25);
	RemoveBuildingForPlayer(playerid, 920, -2139.6172, -252.0859, 35.9922, 0.25);
	RemoveBuildingForPlayer(playerid, 943, -2156.0703, -227.7500, 36.2813, 0.25);
	RemoveBuildingForPlayer(playerid, 944, -2188.5234, -236.8047, 36.3984, 0.25);
	RemoveBuildingForPlayer(playerid, 942, -2174.8281, -235.5625, 37.9609, 0.25);
	RemoveBuildingForPlayer(playerid, 944, -2153.7969, -229.0391, 36.3984, 0.25);
	RemoveBuildingForPlayer(playerid, 944, -2146.2656, -238.4063, 36.3984, 0.25);
	RemoveBuildingForPlayer(playerid, 942, -2140.3359, -229.1484, 37.9609, 0.25);
	RemoveBuildingForPlayer(playerid, 939, -2140.2266, -237.5078, 37.9609, 0.25);
	RemoveBuildingForPlayer(playerid, 944, -2171.1016, -235.7031, 36.3984, 0.25);
	RemoveBuildingForPlayer(playerid, 944, -2145.1641, -234.1719, 36.3984, 0.25);
	RemoveBuildingForPlayer(playerid, 944, -2146.0234, -228.5000, 36.3984, 0.25);
	RemoveBuildingForPlayer(playerid, 944, -2149.8750, -229.7188, 36.3984, 0.25);
	RemoveBuildingForPlayer(playerid, 942, -2164.2031, -236.0234, 37.9609, 0.25);
	RemoveBuildingForPlayer(playerid, 931, -2142.5547, -241.9375, 36.5781, 0.25);
	RemoveBuildingForPlayer(playerid, 918, -2153.0859, -256.2734, 35.8750, 0.25);
	RemoveBuildingForPlayer(playerid, 944, -2177.5391, -259.8281, 36.3984, 0.25);
	RemoveBuildingForPlayer(playerid, 944, -2175.7500, -266.3359, 36.3984, 0.25);
	RemoveBuildingForPlayer(playerid, 943, -2150.5078, -266.3594, 36.2813, 0.25);
	RemoveBuildingForPlayer(playerid, 945, -2157.1563, -248.0078, 45.1328, 0.25);
	RemoveBuildingForPlayer(playerid, 945, -2164.1016, -248.0078, 45.1328, 0.25);
	RemoveBuildingForPlayer(playerid, 945, -2167.7813, -248.0078, 45.1328, 0.25);
	RemoveBuildingForPlayer(playerid, 945, -2171.2266, -248.0078, 45.1328, 0.25);
	RemoveBuildingForPlayer(playerid, 945, -2174.7969, -248.0078, 45.1328, 0.25);
	RemoveBuildingForPlayer(playerid, 945, -2160.7031, -248.0078, 45.1328, 0.25);
	RemoveBuildingForPlayer(playerid, 1438, -2164.2188, -231.1563, 35.5078, 0.25);
	RemoveBuildingForPlayer(playerid, 944, -2146.0625, -251.0078, 36.3984, 0.25);
	RemoveBuildingForPlayer(playerid, 944, -2180.3906, -247.4609, 36.3984, 0.25);
	RemoveBuildingForPlayer(playerid, 918, -2173.5938, -268.0781, 40.0781, 0.25);
	RemoveBuildingForPlayer(playerid, 918, -2148.4922, -230.8047, 35.8750, 0.25);
	RemoveBuildingForPlayer(playerid, 918, -2143.4688, -230.3438, 35.8750, 0.25);
	RemoveBuildingForPlayer(playerid, 918, -2167.8281, -246.0859, 35.8750, 0.25);
	RemoveBuildingForPlayer(playerid, 11103, -2180.7031, -218.0391, 37.9766, 0.25);
	RemoveBuildingForPlayer(playerid, 11233, -2164.4531, -255.3906, 38.1250, 0.25);
	RemoveBuildingForPlayer(playerid, 11234, -2180.4531, -251.4688, 37.9922, 0.25);
	RemoveBuildingForPlayer(playerid, 11235, -2180.4531, -261.2891, 37.9922, 0.25);
	RemoveBuildingForPlayer(playerid, 11236, -2164.4531, -255.3906, 38.1250, 0.25);
	return 1;
}
