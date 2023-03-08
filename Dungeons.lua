-- Dungeons.lua
-- Dungeon tracking functionality for WOW Classic Hardcore Addon
-- Written by Frank de Jong

-- Definitions
local DT_WARN_INTERVAL = 10 					-- Warn every 10 seconds about repeated run (while in dungeon)
local DT_INSIDE_MAX_TIME = 60 					-- Maximum time inside a dungeon without it being logged (61 looks nicer than 60 in-game)
local DT_OUTSIDE_MAX_REAL_TIME = 1800 			-- If seen outside, how many seconds since last seen inside before finalization (1800 = 30m)
local DT_OUTSIDE_MAX_RUN_TIME = 21600 			-- If seen outside, how many seconds since start of run before finalization (21600 = 6 hrs)
local DT_TIME_STEP = 1 							-- Dungeon code called every 1 second
local DT_GROUP_PULSE = 30 						-- Send group pulse every 30 seconds
local DT_VERSION = 4 							-- Increasing this will trigger a full rebuild of the dungeon tracker info

-- Some local variables defined in Hardcore.lua -- Make sure these are the same as in Hardcore.lua!!
local CTL = _G.ChatThrottleLib
local COMM_NAME = "HardcoreAddon" 				-- Overwritten in DungeonTrackerInitiate()
local COMM_COMMAND_DELIM = "$" 					-- Overwritten in DungeonTrackerInitiate()
local COMM_FIELD_DELIM = "|" 					-- Overwritten in DungeonTrackerInitiate()
local DT_PULSE_COMMAND = "DTPULSE" 				-- Overwritten in DungeonTrackerInitiate()

local combat_log_frame = nil

local dt_checked_for_missing_runs = false		-- Did we check for missing runs in this session already?

-- dt_db ( = dungeon tracker database )
--
-- Contains all the info for the dungeons:
-- { instanceMapID, zoneID, "English Name", type = { "D", "R", "B", "O" }, max_players, max_runs, { max_level_era, max_level_wotlk }, { quests }, { bosses } },
-- Types: D = dungeon (5-player), R = raid, B = battleground, O = other

-- The following dungeon table was compiled with help from @Jordynna (thanks!)

local dt_db = {

	-- Era dungeons
	{ 389, 2437, "Ragefire Chasm", "D", 5, 1, { 18, 20 }, 
				{ 5728, 5761, 5722, 5723, 5725 }, 			-- All 5 quests in RFC
				{{"Bazzalan",11519}, {"Taramagan the Hungerer",11520}, {"Oggleflint",11517}, {"Jergosh the Invoker",11518}}
	},
	{ 36, 1581, "The Deadmines", "D", 5, 1, { 26, 24 }, 
				{ 2040, 166, 214, 373 }, 					-- Underground Assault, The Defias Brotherhood, Red Silk Bandanas, The Unsent Letter
				{{"Edwin VanCleef",639}, {"Rhahk'Zor",644}, {"Sneed's Shredder",642}, {"Gilnid",1763}, {"Mr. Smite",646}, {"Captain Greenskin",647}, {"Cookie",645}}
	},
	{ 43, 718, "Wailing Caverns", "D", 5, 1, { 24, 24 }, 
				{ 914, 1487, 3366 },			-- Leaders of the Fang, Deviate Eradication, The Glowing Shard
				{{"Mutanus",3654}, {"Kresh",3653}, {"Lady Anacondra",3671}, {"Lord Cobrahn",3669}, {"Lord Pythas",3670}, {"Skum",3674}, {"Lord Serpentis",3673}, {"Verdan the Everliving",5775}}
	}, 
	{ 33, 209, "Shadowfang Keep", "D", 5, 1, { 30, 25 }, 
				{ 1013, 1098, 1014 }, -- The Book of Ur, Deathstalkers in Shadowfang, Arugal Must Die
				{{"Archmage Arugal",4275}, {"Rethilgore",3914}, {"Razorclaw the Butcher",3886}, {"Baron Silverlaine",3887}, {"Commander Springvale",4278}, {"Odo the Blindwatcher",4279}, {"Fenrus the Devourer",4274}, {"Wolf Master Nandos",3927}}
	},
	{ 48, 719, "Blackfathom Deeps", "D", 5, 1, { 32, 28 }, 
				{ 971, 1198, 1199, 1275, 6565, 6921, 1200, 6561, 6922 },
				{{"Aku'mai",4829}, {"Ghamoo-ra",4887}, {"Lady Sarevess",4831}, {"Gelihast",6243}, {"Lorgus Jett",12902}, {"Baron Aquanis",12876}, {"Twilight Lord Kelris",4832}, {"Old Serra'kis",4830}}
	},				
	{ 34, 717, "The Stockade", "D", 5, 1, { 32, 29 }, 
				{ 387, 386, 378, 388, 377, 391 },
				{{"Bazil Thredd",1716}, {"Targorr the Dread",1696}, {"Kam Deepfury",1666}, {"Hamhock",1717}, {"Dextren Ward",1663}}
	},
	{ 47, 491, "Razorfen Kraul", "D", 5, 1, { 38, 31 }, 
				{ 1221, 1102, 1109, 1101, 1144, 1142, 6522 },
				{{"Charlga Razorflank",4421}, {"Roogug",6168}, {"Aggem Thorncurse",4424}, {"Death Speaker Jargba",4428}, {"Overlord Ramtusk",4420}, {"Agathelos the Raging",4422}}
	},
	{ 90, 721, "Gnomeregan", "D", 5, 1, { 38, 32 }, 
				{ 2904, 2951, 2945, 2922, 2928, 2924, 2930, 2929, 2841 },
				{{"Mekgineer Thermaplugg",7800}, {"Grubbis ",7361}, {"Viscous Fallout",7079}, {"Electrocutioner 6000",6235}, {"Crowd Pummeler 9-60",6229}}
	},
	{ 129, 722, "Razorfen Downs", "D", 5, 1, { 46, 41 }, 
				{ 3636, 3341, 3525 },
				{{"Amnennar the Coldbringer",7358}, {"Tuten'kash",7355}, {"Mordresh Fire Eye",7357}, {"Glutton",8567}}
	},
	{ 189, 796, "Scarlet Monastery", "D", 5, 1, { 45, 44 }, 
				{}, 
				{} 																-- Empty boss list allows logging of bosses in the wings (do not touch!)
	},			
	{ 18901, 79601, "Scarlet Monastery (GY)", "D", 5, 1, { 45, 44 }, 	 		-- Bit of a hack here, the 4 wings don't have a separate ID, so we fake one for them
				{},																-- No quests in GY
				{ {"Bloodmage Thalnos", 4543}, {"Interrogator Vishas", 3983} }
	}, 
	{ 18902, 79602, "Scarlet Monastery (Lib)", "D", 5, 1, { 45, 44 }, 
				{ 1050, 1053, 1049, 1048, 1160, 1951 }, 						-- 1048+1053: kill 4 bosses needs Lib+Cath+Arm
				{ {"Arcanist Doan", 6487}, {"Houndmaster Loksey", 3974} } 
	}, 
	{ 18903, 79603, "Scarlet Monastery (Cath)", "D", 5, 1, { 45, 44 },
				{ 1053, 1048 },													-- 1048+1053: kill 4 bosses needs Lib+Cath+Arm
				{ {"Scarlet Commander Mograine", 3976}, {"High Inquisitor Whitemane", 3977}, {"High Inquisitor Fairbanks", 4542 } } 
	},
	{ 18904, 79604, "Scarlet Monastery (Arm)", "D", 5, 1, { 45, 44 }, 
				{ 1053, 1048 },													-- 1048+1053: kill 4 bosses needs Lib+Cath+Arm
				{ {"Herod", 3975} } 
	},
	{ 70, 1137, "Uldaman", "D", 5, 1, { 51, 44 }, 
				{ 1360, 2240, 1139, 2204, 2278 },
				{{"Archaedas",2748}, {"Revelosh",6910}, {"Baelog",6906}, {"Ironaya",7228}, {"Obsidian Sentinel",7023}, {"Ancient Stone Keeper",7206}, {"Galgann Firehammer",7291}, {"Grimlok",4854}}
	},
	{ 209, 1176, "Zul'Farrak", "D", 5, 1, { 54, 50 }, 
				{ 3042, 2865, 2846, 2768, 2770, 3527, 2991, 2936 },
				{{"Chief Ukorz Sandscalp",7267}, {"Ruuzlu",7797}, {"Antu'sul",8127}, {"Theka the Martyr",7272}, {"Witch Doctor Zum'rah",7271}, {"Nekrum Gutchewer",7796}, {"Shadowpriest Sezz'ziz",7275}, {"Sergeant Bly",7604}, {"Hydromancer Velratha",7795}}
	},
	{ 349, 2100, "Maraudon", "D", 5, 1, { 55, 52 }, 
				{ 7041, 7029, 7065, 7064, 7067, 7044, 7046 },
				{{"Princess Theradras",12201}, {"Noxxion",13282}, {"Razorlash",12258}, {"Lord Vyletongue",12236}, {"Celebras the Cursed",12225}, {"Landslide",12203}, {"Tinkerer Gizlock",13601}, {"Rotgrip",13596}}
	},
	{ 109, 1477, "The Temple of Atal'Hakkar", "D", 5, 1, { 60, 54 }, 
				{ 3528, 3446, 3447, 3373 },  										-- 1475, 4143, 4146, removed: tablets and haze drop outside
				{{"Shade of Eranikus",5709}, {"Atal'alarion",8580}, {"Dreamscythe",5721}, {"Weaver",5720}, {"Jammal'an the Prophet",5710}, {"Ogom the Wretched",5711}, {"Morphaz",5719}, {"Hazzas",5722}, {"Avatar of Hakkar",8443}}
	},
	{ 229, 1583, "Blackrock Spire",	"D", 10, 1, { 60, 62 },	{ 4701, 5001, 4724, 4982, 4903, 4862, 4729, 4788, 4768, 4974, 4764, 5102, 6821, 7761 } }, -- UBRS and LBRS are one instance
	{ 230, 1584, "Blackrock Depths", "D", 5, 1, { 60, 60 }, { 4136, 4123, 4286, 4126, 4081, 4134 } },
	{ 289, 2057, "Scholomance", "D", 5, 1, { 60, 62 }, 
				{ 5529, 5582, 5382, 5384, 5466, 5343, 5341 },
				{{"Darkmaster Gandling",1853}, {"Kirtonos the Herald",10506}, {"Jandice Barov",10503}, {"Rattlegore",11622}, {"Marduk Blackpool",10433}, {"Vectus",10432}, {"Ras Frostwhisper",10508}, {"Instructor Malicia",10505}, {"Doctor Theolin Krastinov",11261}, {"Lorekeeper Polkelt",10901}, {"The Ravenian",10507}, {"Lord Alexei Barov",10504}, {"Lady Ilucia Barov",10502}}
	},
	{ 429, 2557, "Dire Maul", "D", 5, 1, { 60, 62 }, 
				{ 7488, 7489, 7441, 7461, 7462, 7703, 5526 },
				{ {"King Gordok",11501}, 
					{"Pusillin",14354},{"Lethendris",14327}, {"Hydrospawn",13280}, {"Zevrim Thornhoof",11490},{"Alzzin the Wildshaper",11492},
					{"Guard Mol'dar",14326},{"Stomper Kreeg",14322},{"Guard Fengus",14321},{"Guard Slip'kik",14323},{"Captain Kromcrush",14325},{"Cho'Rush the Observer",14324},
					{"Tendris Warpwood",11489},{"Magister Kalendris",11487},{"Tsu'zee",11467},{"Illyanna Ravenoak",11488},{"Immol'thar",11496},{"Prince Tortheldrin",11486},
				}
	},
	{ 329, 2017, "Stratholme", "D",	5, 1, { 60, 62 },{ 5282, 5214, 5251, 5262, 5848, 5122, 5212, 5263, 5243, 5122, 6163, 5463, 8945 } }, -- Undead / Live parts are one instance
	-- Era Raids
	{ 249, 2159, "Onyxia's Lair", "R", 40, 1000, { 1000, 1000 }, {} },
	{ 309, 1977, "Zul'Gurub", "R", 20, 1000, { 1000, 1000 }, {} },
	{ 409, 2717, "Molten Core", "R", 40, 1000, { 1000, 1000 }, {} },
	{ 469, 2677, "Blackwing Lair", "R", 40, 1000, { 1000, 1000 }, {} },
	{ 509, 3429, "Ruins of Ahn'Qiraj", "R", 20, 1000, { 1000, 1000 }, {} },
	{ 531, 3428, "Ahn'Qiraj", "R", 40, 1000, { 1000, 1000 }, {} },
	-- Era Battlegrounds
	{ 489, 3277, "Warsong Gulch", "B", 10, 1000, { 1000, 1000 }, {} },
	{ 30, 2597, "Alterac Valley", "B", 40, 1000, { 1000, 1000 }, {} },
	{ 529, 3358, "Arathi Basin", "B", 15, 1000, { 1000, 1000 }, {} },

	-- TBC dungeons
	{ 543, 3562, "Hellfire Ramparts", "D", 5, 1, { 1000, 64 }, { 9575, 9572, 9587, 9588 } },
	{ 542, 3713, "The Blood Furnace", "D", 5, 1, { 1000, 65 }, { 9607, 9608, 9589, 9590 } },
	{ 547, 3717, "The Slave Pens", "D", 5, 1, { 1000, 66 }, { 9738 } },
	{ 546, 3716, "The Underbog", "D", 5, 1, { 1000, 66 }, { 9738, 9717, 9719 } }, -- 9715 removed because also drops in Steamvault
	{ 557, 3792, "Mana-Tombs", "D", 5, 1, { 1000, 68 }, { 10216, 10218, 10165 } },
	{ 558, 3790, "Auchenai Crypts", "D", 5, 1, { 1000, 70 }, { 10164, 10167 } }, -- "All remaining TBC dungeons have a MAX level of 70"
	{ 560, 2367, "Old Hillsbrad Foothills", "D", 5, 1, { 1000, 70 }, { 10283, 10284, 10285 } },
	{ 556, 3791, "Sethekk Halls", "D", 5, 1, { 1000, 70 }, { 10097, 10098 } },
	{ 553, 3847, "The Botanica", "D", 5, 1, { 1000, 70 }, { 10704, 10257, 10897 } },
	{ 555, 3789, "Shadow Labyrinth", "D", 5, 1, { 1000, 70 }, { 10885, 10094, 10095, 10091, 10649, 10666, 9831 } },
	{ 545, 3715, "The Steamvault", "D", 5, 1, { 1000, 70 }, { 9763, 9832, 10667, 10885 } },
	{ 540, 3714, "The Shattered Halls", "D", 5, 1, { 1000, 70 }, { 9492, 9495, 9493, 9496, 10670 } },
	{ 554, 3849, "The Mechanar", "D", 5, 1, { 1000, 70 }, { 10704, 10665 } },
	{ 269, 2366, "The Black Morass", "D", 5, 1, { 1000, 70 }, { 10296, 10297, 10298, 9836, 9837, 10902 } },
	{ 552, 3848, "The Arcatraz", "D", 5, 1, { 1000, 70 }, { 9832, 10886 } },
	{ 585, 4131, "Magisters' Terrace", "D", 5, 1, { 1000, 70 }, { 11492, 11499 } },
	-- TBC Raids
	{ 532, 3457, "Karazhan", "R", 10, 1000, { 1000, 1000 }, {} },
	{ 533, 3456, "Naxxramas", "R", 40, 1000, { 1000, 1000 }, {} },
	{ 534, 3606, "Hyjal Summit", "R", 25, 1000, { 1000, 1000 }, {} },
	{ 544, 3836, "Magtheridon's Lair", "R", 25, 1000, { 1000, 1000 }, {} },
	{ 548, 3607, "Serpentshrine Cavern", "R", 25, 1000, { 1000, 1000 }, {} },
	{ 564, 3959, "Black Temple", "R", 25, 1000, { 1000, 1000 }, {} },
	{ 565, 3923, "Gruul's Lair", "R", 25, 1000, { 1000, 1000 }, {} },
	{ 568, 3805, "Zul'Aman", "R", 10, 1000, { 1000, 1000 }, {} },
	{ 580, 4075, "Sunwell Plateau", "R", 25, 1000, { 1000, 1000 }, {} },
	{ 550, 3845, "Tempest Keep", "R", 25, 1000, { 1000, 1000 }, {} },
	-- TBC Battlegrounds
	{ 566, 3820, "The Eye of the Storm", "B", 15, 1000, { 1000, 1000 }, {} },

	-- WotLK dungeons
	{ 574, 206, "Utgarde Keep", "D", 5, 1, { 1000, 74 }, { 11272, 13206, 11262, 13245, 13205, 11252 } },
	{ 576, 4265, "The Nexus", "D", 5, 1, { 1000, 75 }, { 13094, 13095, 11905, 11911, 11973, 13246 } },
	{ 601, 4277, "Azjol-Nerub", "D", 5, 1, { 1000, 76 }, { 13167, 13182, 13254 } },
	{ 619, 4494, "Ahn'kahet: The Old Kingdom", "D", 5, 1, { 1000, 77 }, { 13187, 13204, 13190, 13255 } },
	{ 600, 4196, "Drak'Tharon Keep", "D", 5, 1, { 1000, 78 }, { 12238, 12037, 13129, 13249 } },
	{ 608, 4415, "The Violet Hold", "D", 5, 1, { 1000, 79 }, { 13158, 13159, 13256 } },
	{ 604, 4416, "Gundrak", "D", 5, 1, { 1000, 80 }, { 13098, 13096, 13111, 13250 } },
	{ 599, 4264, "Halls of Stone", "D", 5, 1, { 1000, 80 }, { 13207, 13252 } },
	{ 602, 4272, "Halls of Lightning", "D", 5, 1, { 1000, 80 }, { 13109, 13108, 13244, 13253 } },
	{ 668, 4820, "Halls of Reflection", "D", 5, 1, { 1000, 80 }, { 24713, 24711, 24802, 24500, 24561, 24480 } },
	{ 595, 4100, "The Culling of Stratholme", "D", 5, 1, { 1000, 80 }, { 13151, 13149, 13240, 13251 } },
	{ 575, 1196, "Utgarde Pinnacle", "D", 5, 1, { 1000, 80 }, { 13131, 13132, 13241, 13248 } },
	{ 578, 4228, "The Oculus", "D", 5, 1, { 1000, 80 }, { 13124, 13126, 13127, 13128, 13240, 13247 } },
	{ 650, 4723, "Trial of the Champion", "D", 5, 1, { 1000, 80 }, { 14199 } },
	{ 632, 4809, "The Forge of Souls", "D", 5, 1, { 1000, 80 }, { 24506, 24510, 24511, 24499, 24682, 24683 } },
	{ 658, 4813, "Pit of Saron", "D", 5, 1, { 1000, 80 },{ 24682, 24683, 24507, 24498, 24712, 24710, 24713, 24711, 24559, 24461 }},
	-- WotLK raids
	{ 603, 4273, "Ulduar", "R", 25, 1000, { 1000, 1000 }, {} },
	{ 615, 4493, "The Obsidian Sanctum", "R", 25, 1000, { 1000, 1000 }, {} },
	{ 616, 4500, "The Eye of Eternity", "R", 25, 1000, { 1000, 1000 }, {} },
	{ 624, 4603, "Vault of Archavon", "R", 25, 1000, { 1000, 1000 }, {} },
	{ 631, 4812, "Icecrown Citadel", "R", 25, 1000, { 1000, 1000 }, {} },
	{ 649, 4722, "Trial of the Crusader", "R", 25, 1000, { 1000, 1000 }, {} },
	{ 724, 4987, "Ruby Sanctum", "R", 25, 1000, { 1000, 1000 }, {} },
	-- WotLK Battlegrounds
	{ 628, 4710, "Isle of Conquest", "B", 40, 1000, { 1000, 1000 }, {} },

	-- Other
	--{ 449, "Champion's Hall", 1000, 1000, { 1000, 1000 }, {} },
	--{ 450, "Hall of Legends", 1000, 1000, { 1000, 1000 }, {} },
	--{ , "Borean Tundra", },					-- TO BE DONE, maybe
	--{ , "Strand of the Ancients", },			-- TO BE DONE, maybe
}

local dt_db_id_to_name = nil
local dt_db_max_levels = nil
local dt_db_name_to_index = nil			-- Gives index in the database of the dungeon with given name

-- DungeonTrackerInitializeHashes()
--
-- Compiles the lookup tables dt_db_* for faster lookup of specific dungeons

local function DungeonTrackerInitializeHashes()

	-- Hash from MapID to dungeon name
	if dt_db_id_to_name == nil then
		dt_db_id_to_name = {}
		for i, v in ipairs(dt_db) do
			dt_db_id_to_name[v[1]] = v[3]
		end
	end
	
	-- Hash from name to max level
	if dt_db_max_levels == nil then
		dt_db_max_levels = {}
		for i, v in ipairs(dt_db) do
			if v[7] ~= nil then
				dt_db_max_levels[v[3]] = v[7]
			else
				dt_db_max_levels[v[3]] = { 1000, 1000 }
			end
		end
	end
	
	-- Hash from name to index in the database
	if dt_db_name_to_index == nil then
		dt_db_name_to_index = {}
		for i, v in ipairs(dt_db) do
			dt_db_name_to_index[v[3]] = i
		end
	end
	
end

-- DungeonTrackerGetDungeonName( id )
--
-- Needed to get around regionalised names. We want everything in English, yo!

local function DungeonTrackerGetDungeonName(id)

	if dt_db_id_to_name == nil or dt_db_id_to_name[id] == nil then
		return "Unknown"
	end

	return dt_db_id_to_name[id]
end

-- DungeonTrackerGetDungeonMaxLevel
--
-- Returns the max level for a dungeon from the database above, or 1000 if not known

local function DungeonTrackerGetDungeonMaxLevel(name)
	local max_level = 1000 -- Default: if we can't find it, or game version not set: it doesn't have a max level

	if dt_db_max_levels ~= nil and dt_db_max_levels[name] ~= nil then
		if Hardcore_Character.game_version ~= nil then
			if Hardcore_Character.game_version == "Era" or Hardcore_Character.game_version == "SoM" then
				max_level = dt_db_max_levels[name][1]
			elseif Hardcore_Character.game_version == "WotLK" then
				max_level = dt_db_max_levels[name][2]
			end
		end
	end

	return max_level
end

-- DungeonTrackerGetAllDungeonMaxLevels()
--
-- Returns a table of dungeons and associated max levels
-- (only dungeons, not raids, not battle grounds)
-- Mostly for use in the Rules tab (so not local), called from Mainmenu.lua

function DungeonTrackerGetAllDungeonMaxLevels()
	local the_table = {}

	for i, v in pairs(dt_db) do
		if v[4] == "D" then
			local max_era_level = v[7][1]
			if max_era_level == 1000 then
				table.insert(the_table, { v[3], "--", v[7][2] })
			else
				table.insert(the_table, { v[3], max_era_level, v[7][2] })
			end
		end
	end

	return the_table
end

-- DungeonTrackerHasRun( name )
--
-- Returns true if a dungeon with the given name was found in any of .runs[], .pending[] or .current,
-- or false otherwise

local function DungeonTrackerHasRun( name )

	if Hardcore_Character.dt.runs ~= nil then
		for i, v in ipairs(Hardcore_Character.dt.runs) do
			if v.name == name then
				return true
			end
		end
	end
	
	if Hardcore_Character.dt.pending ~= nil then
		for i, v in ipairs(Hardcore_Character.dt.pending) do
			if v.name == name then
				return true
			end
		end
	end
	
	if Hardcore_Character.dt.current ~= nil then
		if Hardcore_Character.dt.current.name == name then
			return true
		end
	end
	
	return false

end



-- DungeonTrackerFindMissingRunsFromQuests()
--
-- Finds any dungeons that have the flagging quests, but do not have an associated run
-- (for whatever reason, such as weird update problems).

local function DungeonTrackerFindMissingRunsFromQuests()

	local game_version_index = 1
	local game_version_max_level = 60

	-- Double check inputs
	if Hardcore_Character.dt == nil or Hardcore_Character.dt.runs == nil then
		return
	end

	-- For Era/SoM, we only look at the quests for dungeons with a max level of 60
	if Hardcore_Character.game_version == "Era" or Hardcore_Character.game_version == "SoM" then
		game_version_index = 1
		game_version_max_level = 60
	elseif Hardcore_Character.game_version == "WotLK" then
		game_version_index = 2
		game_version_max_level = 80
	else
		return
	end

	Hardcore:Debug("Looking for missing runs...")

	-- Go through the list and log a run for each dungeon for which one or more quests are flagged as completed
	for i, v in pairs(dt_db) do
		local dungeon_done = false
		local quests = v[8]
		local name = v[3]
		local map_id = v[1]
		local max_levels = v[7]
		
		if (quests ~= nil) and (max_levels ~= nil) and (max_levels[game_version_index] <= game_version_max_level) and (DungeonTrackerHasRun( name ) == false) then
			local j
			for j = 1, #quests do
				if C_QuestLog.IsQuestFlaggedCompleted(quests[j]) then
					Hardcore:Debug("Found legacy quest " .. quests[j])
					dungeon_done = true
					break
				end
			end
			if dungeon_done == true then
				DUNGEON_RUN = {}
				DUNGEON_RUN.name = name
				DUNGEON_RUN.id = map_id
				DUNGEON_RUN.date = "(legacy)"
				DUNGEON_RUN.time_inside = 0
				DUNGEON_RUN.level = 0
				DUNGEON_RUN.quest_id = quests[j]
				Hardcore:Debug("Logging missing run in " .. DUNGEON_RUN.name)
				table.insert(Hardcore_Character.dt.runs, DUNGEON_RUN)
			end
		end
	end
end


local function DungeonTrackerIsRepeatedRun(run1, run2)
	-- If one of the runs is for an unknown SM wing, we don't count this as repeated
	if run1.name == "Scarlet Monastery" or run2.name == "Scarlet Monastery" then
		return false
	end

	-- Most common case is where everything is in English; then the names should be the same
	if run1.name == run2.name then
		return true
	end

	-- Handle exceptional case for Scarlet Monastery -- there, the instanceMapID will be the same for different wings,
	-- but there is no repeated run if you do them both. The "true" must have come from the run name comparison above.
	if run1.id ~= nil and run1.id == 189 then
		return false
	end

	-- Handle more exotic cases where some of the names of the logged runs are in another language (backward compatibility)
	-- or there was somehow an update in the dungeon database which caused a small change in the name
	if run1.id ~= nil and run2.id ~= nil and run1.id == run2.id then
		return true
	end

	-- Player-friendly: we can't figure it out, so we assume it's good
	return false
end

-- DungeonTrackerUpdateInfractions()
--
-- Updates the dt.overleveled_runs and dt.repeated_runs variables
-- from the list of finalized runs. This can be called after a Mod command to
-- recalculate the infraction statistics

local function DungeonTrackerUpdateInfractions()
	local repeated = 0
	local over_leveled = 0

	for i = 1, #Hardcore_Character.dt.runs do
		-- Check overleveled run
		if Hardcore_Character.dt.runs[i].level > DungeonTrackerGetDungeonMaxLevel(Hardcore_Character.dt.runs[i].name) then
			over_leveled = over_leveled + 1
		end
		-- Check if the run is repeated further down in the array (this prevents counting runs twice when i ends up at j)
		for j = i + 1, #Hardcore_Character.dt.runs do
			if DungeonTrackerIsRepeatedRun(Hardcore_Character.dt.runs[i], Hardcore_Character.dt.runs[j]) then
				repeated = repeated + 1
			end
		end
	end

	Hardcore_Character.dt.overleveled_runs = over_leveled
	Hardcore_Character.dt.repeated_runs = repeated
end

local function DungeonTrackerWarnInfraction()

	local message

	-- We only warn if there is still chance to get out in time
	local time_left = DT_INSIDE_MAX_TIME - Hardcore_Character.dt.current.time_inside
	if time_left <= 0 then
		return
	end

	-- Don't warn too frequently
	if (Hardcore_Character.dt.current.last_warn ~= nil) and (Hardcore_Character.dt.current.time_inside - Hardcore_Character.dt.current.last_warn < DT_WARN_INTERVAL) then
		return
	end

	-- Don't warn in the first few seconds of an unidentified SM wing. The time_left will be shorter after
	-- a reconnect to an existing wing run, so then that first warning of 60s would be confusing
	if (Hardcore_Character.dt.current.name == "Scarlet Monastery") and (time_left > 50) then
		return
	end

	-- Don't warn at max level (they can do whatever dungeon then) or when the user turned warnings off
	-- /run Hardcore_Character.dt.warn_infractions=false
	if Hardcore_Character.dt.warn_infractions == false then
		return
	end

	-- Get max level to know if we should even warn
	if Hardcore_Character.game_version ~= nil then
		local max_level
		if Hardcore_Character.game_version == "Era" or Hardcore_Character.game_version == "SoM" then
			max_level = 60
		else -- if Hardcore_Character.game_version == "WotLK" or anything else
			max_level = 80
		end
		if UnitLevel("player") >= max_level then
			Hardcore_Character.dt.warn_infractions = false
			return
		end
	end

	-- See if the player's level is allowed in this dungeon
	local max_level = DungeonTrackerGetDungeonMaxLevel(Hardcore_Character.dt.current.name)
	if Hardcore_Character.dt.current.level > max_level then
		Hardcore_Character.dt.current.last_warn = Hardcore_Character.dt.current.time_inside
		message = "\124cffFF0000You are overleveled for "
			.. Hardcore_Character.dt.current.name
			.. ", max level = "
			.. max_level
			.. " -- leave the dungeon within "
			.. time_left
			.. " seconds!"
		Hardcore:Print(message)
	end

	-- See if this dungeon was already in the list of completed runs, and warn every so many seconds if that is so
	for i, v in ipairs(Hardcore_Character.dt.runs) do
		if DungeonTrackerIsRepeatedRun(v, Hardcore_Character.dt.current) then
			Hardcore_Character.dt.current.last_warn = Hardcore_Character.dt.current.time_inside
			message = "\124cffFF0000You entered "
				.. v.name
				.. " already at date "
				.. v.date
				.. " -- leave the dungeon within "
				.. time_left
				.. " seconds!"
			Hardcore:Print(message)
			break -- No need to warn about 3rd and higher entries
		end
	end

	-- See if this dungeon was already in the list of pending runs (but with a different instanceID), and warn every so many seconds if that is so
	for i, v in ipairs(Hardcore_Character.dt.pending) do
		-- We never warn about pending runs without an instanceID, they may or may not be the same as the current
		-- (However, such pending runs should not exist, as they are deleted immediately when you exit the dungeon)
		-- It is not possible for the IIDs to be the same at this point, as they would have been merged already
		if v.iid ~= nil and Hardcore_Character.dt.current.iid ~= nil then
			if DungeonTrackerIsRepeatedRun(v, Hardcore_Character.dt.current) then
				Hardcore_Character.dt.current.last_warn = Hardcore_Character.dt.current.time_inside
				message = "\124cffFF0000You entered another instance ID of "
					.. v.name
					.. " already at date "
					.. v.date
					.. " -- leave the dungeon within "
					.. time_left
					.. " seconds!"
				Hardcore:Print(message)
				break -- No need to warn about 3rd and higher entries
			end
		end
	end

end

local function DungeonTrackerLogRun(run)

	-- We don't log this run if the inside time is too small
	if run.time_inside < DT_INSIDE_MAX_TIME then
		Hardcore:Debug("Not logging short run in " .. run.name)
		return
	end

	-- We don't log this run if no instance ID was found (indicating that no mobs were attacked)
	if run.iid == nil then
		Hardcore:Debug("Not logging run without instanceID in " .. run.name)
		return
	end

	-- Warn if this is a repeated run and log
	for i, v in ipairs(Hardcore_Character.dt.runs) do
		if DungeonTrackerIsRepeatedRun(v, run) then
			if Hardcore_Character.dt.warn_infractions == true then
				Hardcore:Print(
					"\124cffFF0000Player entered "
						.. run.name
						.. " already at date "
						.. v.date
						.. " -- logging repeated run"
				)
			end
			break
		end
	end

	-- Warn if this is an overleveled run and log
	local max_level = DungeonTrackerGetDungeonMaxLevel(run.name)
	if run.level > max_level then
		if Hardcore_Character.dt.warn_infractions == true then
			Hardcore:Print("\124cffFF0000Player was overleveled for " .. run.name .. " -- logging overleveled run")
		end
	end

	-- Now actually log the run
	Hardcore:Debug("Logging run in " .. run.name)
	table.insert(Hardcore_Character.dt.runs, run)

	-- Update infraction statistics (involves a re-count)
	DungeonTrackerUpdateInfractions()
end

-- DungeonTrackerIdentifyScarletMonasteryWing( map_id, mob_type_id )
--
-- Finds the SM wing in which a certain mob_type_id is found. Only works for unique mob_ids,
-- so not for mobs that appear in more than one wing.

local function DungeonTrackerIdentifyScarletMonasteryWing( map_id, mob_type_id )

	local SM = "Scarlet Monastery" 

	-- If this is SM (=189), and we don't know the wing yet, we try to find it
	if map_id == 189 and Hardcore_Character.dt.current.name == SM then
	
		local wing_spawns = {
			{4293, "Scarlet Scryer", "GY"},
			{4306, "Scarlet Torturer", "GY"},
			{4287, "Scarlet Gallant", "Lib"},
			{4296, "Scarlet Adept", "Lib"},
			{4286, "Scarlet Soldier", "Arm"},
			{4297, "Scarlet Conjuror", "Arm"},
			{4298, "Scarlet Defender", "Cath"},
			-- One more round of deeper-in mobs
			{6427, "Haunting Phantasm", "GY"},
			{4288, "Scarlet Beastmaster", "Lib"},
			{4291, "Scarlet Diviner", "Lib"},
			{4289, "Scarlet Evoker", "Arm"},
			{4294, "Scarlet Sorceror", "Cath"},
			-- Bosses as a last resort
			{3983, "Interrogator Vishas", "GY"},
			{6490, "Azshir the Sleepless", "GY"},
			{6488, "Fallen Champion", "GY"},
			{6489, "Ironspine", "GY"},
			{3974, "Houndmaster Loksey", "Lib"},
			{6487, "Arcanist Doan", "Lib"},
			{3975, "Herod", "Arm"},
			{3976, "Scarlet Commander Mograine", "Cath"},
			{3977, "High Inquisitor Whitemane", "Cath"},
			{4542, "High Inquisitor Fairbanks", "Cath"},
		}
		
		-- See if any of the listed mobs is recognised
		for i, v in ipairs( wing_spawns ) do
			if mob_type_id == v[1] then
				Hardcore_Character.dt.current.name = SM .. " (" .. v[3] .. ")"
				Hardcore:Debug( "Identified SM wing " .. v[3] .. " from " .. v[2] )
				return
			end
		end
	end
	
	-- If not SM, or wing already known, or wing not found, we do nothing

end

-- DungeonTrackerCheckChanged(name)
--
-- Handles changes of dungeon (to do "emergency" logging or current run)
-- Also adapts the SM dungeon name to include the wing, if we know it

local function DungeonTrackerCheckChanged(name)

	-- If there is no current, there is no change
	if not next(Hardcore_Character.dt.current) then
		return name
	end

	local SM = "Scarlet Monastery"

	-- If this is Scarlet Monastery (any wing), we need to check if the wing changed
	if name == SM then
		-- If we don't know which wing we are in, try to identify any of the dungeon wing's mobs
		if Hardcore_Character.dt.current.name ~= SM then
			-- We already know our wing -- just copy over what we already had
			name = Hardcore_Character.dt.current.name
		end

		-- At this point, either dt.current.name is "SM", or it is "SM (Wing)".
		-- If it's "SM", the name can only be "SM", too. This happens if no door spawn was found yet.
		-- If it's "SM (Wing)", then "name" has a wing too, which is either the same or different
	end

	-- Now check if the name changed (whether it's SM or RFC or whatever)
	-- This should normally not happen, as once we're outside, the current dungeon is queued
	-- But it could happen if people disable the addon inside a dungeon, and re-enable it in another
	if Hardcore_Character.dt.current.name ~= name then
		-- Change to the new dungeon, but we store only if we spent enough time
		Hardcore:Print("Left dungeon " .. Hardcore_Character.dt.current.name .. " for dungeon " .. name)
		DungeonTrackerLogRun(Hardcore_Character.dt.current)
		Hardcore_Character.dt.current = {}
	end

	return name
end

-- DungeonTrackerReceivePulse( data, sender )
--
-- Receives a group pulse, storing the time in the message and the sender in the associated pending run
-- Not a local function, called from Hardcore.lua

function DungeonTrackerReceivePulse(data, sender)
	local short_name
	local version
	local ping_time
	local dungeon_name
	local dungeon_id
	local iid

	short_name, version, ping_time, dungeon_name, dungeon_id, iid = string.split(COMM_FIELD_DELIM, data)
	-- Handle malformed pulse that breaks the script
	if dungeon_id == nil then
		return
	else
		dungeon_id = tonumber(dungeon_id)
	end
	-- Old version of the pulse does not have instance ID, so set it to 0
	if iid == nil then
		iid = 0
	else
		iid = tonumber(iid)
	end	
	ping_time = tonumber(ping_time)

	Hardcore:Debug(
		"Received dungeon group pulse from "
			.. sender
			.. ", data = "
			.. short_name
			.. ", "
			.. ping_time
			.. ", "
			.. dungeon_name
			.. ", "
			.. iid
	)

	-- Check for errors, dt might not be set right now (if it just got reset for some weird reason)
	if (Hardcore_Character.dt == nil) or (not next(Hardcore_Character.dt)) or (not next(Hardcore_Character.dt.pending)) then
		return
	end

	-- Update the latest ping time in the idle runs only (no need to do it in current run)
	for i, v in pairs(Hardcore_Character.dt.pending) do

		-- We only update the pulse time if the instanceIDs from pending and party member aren't known, or when they are the same
		if v.iid == nil or iid == 0 or v.iid == iid then
			local run_name
			-- If we receive a pulse from "Scarlet Monastery" (without wing), then we have no choice but
			-- to store that pulse in all idle SM runs (the inside party member might be standing on the
			-- doorstep of a partly cleared wing, and see no door mobs).
			-- So then we don't care about the wing of the pending run, and just update them all
			if dungeon_name == "Scarlet Monastery" then
				run_name = string.sub(v.name, 1, 17) -- This also cuts "The Temple of Atal'Hakkar" to "The Temple of Ata", but that's okay
			else
				run_name = v.name
			end

			-- If this is the run from which the ping originated, and the ping time is later than we already have, store it
			if run_name == dungeon_name then
				if ping_time > v.last_seen then
					v.last_seen = ping_time
				end

				-- Add the ping sender to the party members, if not already there
				if string.find(v.party, short_name) == nil then
					v.party = v.party .. "," .. short_name
				end
			end
		end
	end
end

-- DungeonTrackerSendPulse( now )
--
-- Sends a group pulse, if the time out is expired

local function DungeonTrackerSendPulse(now)
	-- Don't send too many pulses, one every 30 seconds is enough
	if (Hardcore_Character.dt.sent_pulse ~= nil) and (now - Hardcore_Character.dt.sent_pulse < DT_GROUP_PULSE) then
		return
	end
	Hardcore_Character.dt.sent_pulse = now

	-- Send my own info to the party (=name + server time + dungeon)
	if CTL then
		local name = UnitName("player")
		local iid = 0
		if Hardcore_Character.dt.current.iid ~= nil then
			iid = Hardcore_Character.dt.current.iid
		end
		local data = name
			.. COMM_FIELD_DELIM
			.. GetAddOnMetadata("Hardcore", "Version")
			.. COMM_FIELD_DELIM
			.. now
			.. COMM_FIELD_DELIM
			.. Hardcore_Character.dt.current.name
			.. COMM_FIELD_DELIM
			.. Hardcore_Character.dt.current.id
			.. COMM_FIELD_DELIM
			.. iid
		local comm_msg = DT_PULSE_COMMAND .. COMM_COMMAND_DELIM .. data
		Hardcore:Debug("Sending dungeon group pulse: " .. comm_msg)
		CTL:SendAddonMessage("NORMAL", COMM_NAME, comm_msg, "PARTY")

		-- For debug purposes, set this to true to simulate a send
		if false then
			DungeonTrackerReceivePulse(data, name .. "-TestServer")
		end
	end
end


-- DungeonTrackerDatabaseHasBossInfo( name )
--
-- Queries the dungeon database to see if the boss info is set for this dungeon,
-- basically to cover the period in which we gather the boss info
-- returning true or false

local function DungeonTrackerDatabaseHasBossInfo( name )

	if dt_db_name_to_index ~= nil and dt_db_name_to_index[ name ] ~= nil then
		local index = dt_db_name_to_index[ name ]
		local record = dt_db[ index ]
		if record[9] ~= nil then
			return true
		end
	end
	
	-- Error or not found
	return false

end


-- DungeonTrackerIsBoss( name, mob_id )
--
-- Queries the dungeon database to see if the mob_id was a boss,
-- returning true or false

local function DungeonTrackerIsBoss( name, mob_id )

	if dt_db_name_to_index ~= nil and dt_db_name_to_index[ name ] ~= nil then
		local index = dt_db_name_to_index[ name ]
		local record = dt_db[ index ]
		if record[9] ~= nil then
			local boss_list = record[9]
			for i, v in ipairs( boss_list ) do
				if v[2] ~= nil and v[2] == mob_id then
					return true
				end
			end
		end
	end
	
	-- Error or not found
	return false

end


-- DungeonTrackerLogKill( dst_guid, dst_name )
--
-- Logs the killing of specific units

local function DungeonTrackerLogKill( mob_type_id )

	-- Check if it's a boss
	if DungeonTrackerIsBoss( Hardcore_Character.dt.current.name, mob_type_id ) then
		-- Add it to the list of bosses we've killed
		if Hardcore_Character.dt.current.bosses == nil then
			Hardcore_Character.dt.current.bosses = {}
		end
		if Hardcore_Character.dt.current.bosses[ mob_type_id ] == nil then
			Hardcore_Character.dt.current.bosses[ mob_type_id ] = GetServerTime()
		else
			-- This should not happen, so we log it here
			Hardcore:Debug( "Warning -- repeated boss kill ignored" )
			Hardcore_Character.dt.current.repeated_boss_kill = true
		end
	end
	
	-- Add it to the list of NPCs we've killed
	if Hardcore_Character.dt.current.num_kills == nil then
		Hardcore_Character.dt.current.num_kills = 0
	end
	Hardcore_Character.dt.current.num_kills = Hardcore_Character.dt.current.num_kills + 1

end

-- CombatLogEventHandler
--
-- Handler for combat events inside the dungeon
-- Retrieves the mapID (fixed for each dungeon), instanceID (dynamic) and NPCID (fixed) from combat events
-- and updates the dungeon log accordingly. 

local function CombatLogEventHandler( self, event )

	-- Bail out right away if we don't have an active run (shouldn't happen, but could)
	if not next( Hardcore_Character.dt.current ) then
		return
	end

	-- Get the combat log data
	local time_stamp, subevent, _, src_guid, src_name, _, _, dst_guid, dst_name = CombatLogGetCurrentEventInfo()

	-- Combat events have a source and a destination (doing and getting the damage). We don't care which one is the NPC.
	-- If it's an NPC, we'll take it.
	local mob_guid = nil
	local mob_name = nil
	if src_guid ~= nil then
		local mob_type = string.split("-", src_guid)
		if mob_type == "Creature" then
			mob_guid = src_guid
			mob_name = src_name
		end
	end
	if mob_guid == nil and dst_guid ~= nil then
		local mob_type = string.split("-", dst_guid)
		if mob_type == "Creature" then
			mob_guid = dst_guid
			mob_name = dst_name
		end
	end
	
	-- Return immediately if no NPC guid was found
	if mob_guid == nil then
		return		
	end

	--print( mob_guid )
	
	-- Split the GUID
	local mob_type, _, server, map_id, instance_id, mob_type_id = string.split("-", mob_guid)
	map_id = tonumber( map_id )
	instance_id = tonumber( instance_id )
	mob_type_id = tonumber( mob_type_id )
	
	-- Get the spawn time data from the GUID
	--local mob_spawn_index = bit.rshift( bit.band(tonumber(string.sub(mob_guid[7], 1, 5), 16), 0xFFF8), 3 )
	
	-- Do some checks, to eliminate unexpected results
	if map_id ~= Hardcore_Character.dt.current.id then
		Hardcore:Debug( "Error: Got a combat log message witn an NPC " .. mob_name .. " (" .. mob_type_id .. ") in wrong dungeon map " .. map_id .. " -- bailing out!" )
		return
	end

	-- Store the instanceID (the dynamic one)
	-- To be thread-safe and fast, the reconnecting happens in the main timer routine
	Hardcore_Character.dt.current.iid = instance_id
		
	-- Pass this mob to the SM wing identifier. This will update dt.current.name if possible. 
	DungeonTrackerIdentifyScarletMonasteryWing( map_id, mob_type_id )

	-- If this is a kill, log it (including boss kills)
	if subevent == "UNIT_DIED" then
		DungeonTrackerLogKill( mob_type_id )
	end
	
end

-- DungeonTrackerGetBossKillDataForRun( run )
--
-- Called from MainMenu.lua to populate the dungeon log (boss column)

function DungeonTrackerGetBossKillDataForRun( run )

	local main_boss = nil
	local main_boss_time = 0
	local num_bosses = 0
	local max_bosses = -1
	
	-- If there are no killed bosses (as in legacy runs) for this run, we return immediately
	if run == nil or run.bosses == nil then
		return -1, -1, 0
	end
			
	-- Get main boss for this run
	if dt_db_name_to_index[ run.name ] ~= nil then
		local index = dt_db_name_to_index[ run.name ]
		local fields = dt_db[ index ]
		if fields[9] ~= nil then
			local boss_list = fields[9]
			max_bosses = #boss_list
			if max_bosses > 0 then
				main_boss = boss_list[1]			-- e.g. {"Bloodmage Thalnos", 4543}
			end
		end
	end
	
	-- Now find the main boss kill time
	if main_boss ~= nil then
		local main_boss_id = main_boss[2]

		-- Look for the boss kill time with this id
		if run.bosses[ main_boss_id ] ~= nil then
			main_boss_time = run.bosses[ main_boss_id ] - run.start
		end
	end
	
	-- Count the number of killed bosses
	for i,v in pairs( run.bosses ) do
		num_bosses = num_bosses + 1
	end

	-- Now return the number of bosses and the main boss time
	return num_bosses, max_bosses, main_boss_time

end

-- DungeonTrackerUpgradeLogVersion3()
-- 
-- Upgrades and cleans up the dungeon log from a version 3 client

local function DungeonTrackerUpgradeLogVersion3()

	-- Fix up pending runs without an instance ID, or they will get dropped
	-- Also get rid of the unnecessary non-boss kills info list, replace it with just total number
	if Hardcore_Character.dt.pending ~= nil then
		for i, v in ipairs( Hardcore_Character.dt.pending ) do
			if v.iid == nil and v.time_inside >= DT_INSIDE_MAX_TIME then
				v.iid = 0
			end					
			if v.kills ~= nil then
				v.num_kills = 0
				for j, w in pairs( v.kills ) do
					v.num_kills = v.num_kills + w
				end
				v.kills = nil
			end
			v.log_now = true
		end
	end
	if Hardcore_Character.dt.runs ~= nil then
		for i, v in ipairs( Hardcore_Character.dt.runs ) do
			if v.kills ~= nil then
				v.num_kills = 0
				for j, w in pairs( v.kills ) do
					v.num_kills = v.num_kills + w
				end
				v.kills = nil
			end
		end
	end
	if Hardcore_Character.dt.current ~= nil and next(Hardcore_Character.dt.current) then
		if Hardcore_Character.dt.current.iid == nil and Hardcore_Character.dt.current.time_inside >= DT_INSIDE_MAX_TIME then
			Hardcore_Character.dt.current.iid = 0			-- Will probably be overwritten by a later kill, but if not, then user can't reconnect later. So be it.
		end					
		if Hardcore_Character.dt.current.kills ~= nil then
			Hardcore_Character.dt.current.num_kills = 0
			for j, w in pairs( Hardcore_Character.dt.current.kills ) do
				Hardcore_Character.dt.current.num_kills = Hardcore_Character.dt.current.num_kills + w
			end
			Hardcore_Character.dt.current.kills = nil
		end
	end

	-- Get rid of some old data associated with the old way of doing legacy quest identification
	Hardcore_Character.dt.legacy_runs_imported = nil

end


-- DungeonTracker
--
-- Main interface function for the dungeon tracker, called on a 1s second timer

local function DungeonTracker()
	-- Era/Ogrimmar = Kalimdor, none, 0, , 0, 0, false, 1, 0, {nil}
	-- Era/RFC = Ragefire Chasm, party, 1, Normal, 5, 0, false, 389, 5, {nil}
	-- Note that the name is locale-dependent (and will be overrided below)
	local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceMapID, instanceGroupSize, LfgDungeonID =
		GetInstanceInfo()

	-- Handle invalid or legacy data files, or version upgrade (triggers full rebuild of dungeon database)
	if (Hardcore_Character.dt == nil) 						-- no DT yet
		or (Hardcore_Character.dt.version == nil) 			-- initial DT version without a version number
		or (Hardcore_Character.dt.version == 1)				-- older version, needs rebuild
		or (Hardcore_Character.dt.version == 2)				-- older version, needs rebuild
	then 
		Hardcore_Character.dt = {}
	end
	if not next(Hardcore_Character.dt) then
		Hardcore_Character.dt.current = {}
		Hardcore_Character.dt.runs = {}
		Hardcore_Character.dt.pending = {}
		Hardcore_Character.dt.repeated_runs = 0
		Hardcore_Character.dt.overleveled_runs = 0
		Hardcore_Character.dt.warn_infractions = true
		Hardcore_Character.dt.version = DT_VERSION
		Hardcore_Character.dt.sent_pulse = 0 -- Never sent out a pulse (yet)
	end
	if Hardcore_Character.dt.version ~= nil and Hardcore_Character.dt.version == 3 then
		Hardcore_Character.dt.version = DT_VERSION
		DungeonTrackerUpgradeLogVersion3()
	end

	-- Sometimes, runs don't get logged correctly, like when they are pending and the addon is updated to a version
	-- with a different format or when runs are deleted through appeal commands. In those cases, runs might disappear
	-- entirely, while they should be there. We check for any missing runs exactly once per session. 
	if dt_checked_for_missing_runs == false then
		dt_checked_for_missing_runs = true
		C_Timer.After(5, function()
			DungeonTrackerFindMissingRunsFromQuests()
		end)
	end

	-- Quick check to see if there is no work to be done (i.e. we are outside and there are no pending or current runs)
	-- We also store the group composition for later (only works outside the instance)
	if instanceType == "none" then
		Hardcore_Character.dt.group_members = GetHomePartyInfo()
		if (not next(Hardcore_Character.dt.current)) and (not next(Hardcore_Character.dt.pending)) then
			return
		end
	end

	-- At this point, we are either in a dungeon, or we just left one (dt.current is still valid)
	-- If we just left a dungeon, move current to pending, and update timeouts
	if instanceType ~= "party" then
	
		-- Move current to pending
		if next(Hardcore_Character.dt.current) then
			-- If we didn't find an instance ID yet, we drop this "ghost" run immediately (there is no point in keeping it)
			if Hardcore_Character.dt.current.iid == nil then
				Hardcore:Debug("Dropping active run without instanceID in " .. Hardcore_Character.dt.current.name)
			elseif Hardcore_Character.dt.current.name == "Scarlet Monastery" then
				-- If we didn't find the SM wing, we drop this run as well.
				Hardcore:Debug("Dropping active Scarlet Monastery run without identified wing")
			else
				Hardcore:Debug("Queuing active run in " .. Hardcore_Character.dt.current.name)
				table.insert(Hardcore_Character.dt.pending, Hardcore_Character.dt.current)
			end
			Hardcore_Character.dt.current = {}
			
			-- We don't need the combat log anymore
			if combat_log_frame ~= nil then
				combat_log_frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
				combat_log_frame.dtcl_script_registered = nil			-- trigger re-registering later
			end				
		end
	end

	-- Finalize any pending runs for which more than the timeout has passed and for which no recent party pulse was received
	-- Do this backwards so deleting an element is safe.
	local now = GetServerTime()
	for i = #Hardcore_Character.dt.pending, 1, -1 do
		-- Update idle time (=time since we left or got last group pulse)
		Hardcore_Character.dt.pending[i].idle = now - Hardcore_Character.dt.pending[i].last_seen

		-- Calculate remaining time; it's the smallest of the two outside time outs
		local idle_time_left = min(DT_OUTSIDE_MAX_REAL_TIME - Hardcore_Character.dt.pending[i].idle, 
						DT_OUTSIDE_MAX_RUN_TIME - (now - Hardcore_Character.dt.pending[i].start))

		-- Log it if it expired, or if it was flagged by the log version upgrade code
		if idle_time_left <= 0 or Hardcore_Character.dt.pending[i].log_now ~= nil then
			Hardcore_Character.dt.pending[i].log_now = nil			-- clean up
			DungeonTrackerLogRun(Hardcore_Character.dt.pending[i])
			table.remove(Hardcore_Character.dt.pending, i)
		end
	end

	-- nothing more to be done when outside (or in raid, battleground, or arena)
	if instanceType ~= "party" then
		return
	end

	-- Start the combat log event handler to get the instance ID, SM wing identification and mob kills
	if combat_log_frame == nil then
		combat_log_frame = CreateFrame("Frame")
	end
	if combat_log_frame.dtcl_script_registered == nil then
		combat_log_frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		combat_log_frame:SetScript("OnEvent", CombatLogEventHandler )
		combat_log_frame.dtcl_script_registered = true
	end

	-- Override the name, we don't want to use the local language versions (unless we can't find the name)
	local EN_name = DungeonTrackerGetDungeonName(instanceMapID)
	if EN_name ~= "Unknown" then
		name = EN_name
	end

	-- Check if we are in a new dungeon (this has the special handling of Scarlet Monastery, which changes
	-- the name to the name including the wing, if it has been identified)
	name = DungeonTrackerCheckChanged(name)

	-- See if we can reconnect to a pending run (this forgets the current run, which is probably in an unidentified SM wing)
	-- We do this only if the current run and the pending run have the same name and the same instance ID
	for i = 1, #Hardcore_Character.dt.pending do
		if Hardcore_Character.dt.pending[i].name == name then
			if Hardcore_Character.dt.pending[i].iid ~= nil 			-- Should never happen, but yeah...
				and Hardcore_Character.dt.current.iid ~= nil
				and Hardcore_Character.dt.pending[i].iid == Hardcore_Character.dt.current.iid 
			then
				-- Add the inside time of the current run (should be defined since the iid has been found
				Hardcore_Character.dt.pending[i].time_inside = Hardcore_Character.dt.pending[i].time_inside + Hardcore_Character.dt.current.time_inside
				Hardcore_Character.dt.current = Hardcore_Character.dt.pending[i]
				table.remove(Hardcore_Character.dt.pending, i)
				Hardcore:Debug("Reconnected to pending run in " .. Hardcore_Character.dt.current.name)
				break
			else
				-- User did a "reset all instances", probably, or the current didn't have an IID yet.
				-- In the former case, a warning will be a given further down
			end
		end
	end

	-- If we don't have a current run at this point (reconnected or not), start a new run
	if not next(Hardcore_Character.dt.current) then
		DUNGEON_RUN = {}
		DUNGEON_RUN.name = name
		DUNGEON_RUN.id = instanceMapID
		DUNGEON_RUN.date = date("%m/%d/%y %H:%M:%S")
		DUNGEON_RUN.time_inside = 0
		DUNGEON_RUN.start = now
		DUNGEON_RUN.last_seen = now
		DUNGEON_RUN.idle = 0
		DUNGEON_RUN.level = UnitLevel("player")
		local group_composition = UnitName("player")
		if Hardcore_Character.dt.group_members ~= nil then
			for index, player in ipairs(Hardcore_Character.dt.group_members) do
				group_composition = group_composition .. "," .. player
			end
		end
		DUNGEON_RUN.party = group_composition

		-- Having a nil bosses list means we didn't track the bosses; while an empty list 
		-- means we simply didn't kill any. This depends on whether any boss info is in the database
		if DungeonTrackerDatabaseHasBossInfo( name ) then
			DUNGEON_RUN.bosses = {}
		end
		
		Hardcore_Character.dt.current = DUNGEON_RUN
		Hardcore:Debug("Starting new run in " .. Hardcore_Character.dt.current.name)
	end

	-- Extend the current run (reconnected or new) by another time step and update the last_seen time
	Hardcore_Character.dt.current.time_inside = Hardcore_Character.dt.current.time_inside + DT_TIME_STEP
	Hardcore_Character.dt.current.last_seen = now

	-- Send out pings to group members
	DungeonTrackerSendPulse(now)

	-- Warn the user if he is repeating this run or is overleveled
	DungeonTrackerWarnInfraction()
end

-- DungeonTrackerInitiate()
--
-- Function to get our timer going
-- Called from Hardcore.lua as follows:
--		DungeonTrackerInitiate(COMM_NAME, COMM_COMMANDS[15], COMM_COMMAND_DELIM, COMM_FIELD_DELIM )

function DungeonTrackerInitiate(comm_name, pulse_cmd, cmd_delim, field_delim)
	-- Copy over Hardcore.lua locals needed for communication
	COMM_NAME = comm_name
	DT_PULSE_COMMAND = pulse_cmd
	COMM_COMMAND_DELIM = cmd_delim
	COMM_FIELD_DELIM = field_delim

	-- Compile some hash tables from the database
	DungeonTrackerInitializeHashes()

	-- Start the timer
	C_Timer.NewTicker(DT_TIME_STEP, function()
		DungeonTracker()
	end)
	
end

-- DungeonTrackerHandleAppealCode()
--
-- Handle a Mod command received through a coded string in chat
-- Specifying the date is only necessary when multiple dungeons are given
--
-- /hc AppealDungeonCode <hash> <cmd> <"dungeon name"> <"date">
--
-- /hc AppealDungeonCode <hash> delete <"dungeon name"> ["date"]
-- /hc AppealDungeonCode <hash> merge  <"dungeon name"> <"date"> <"dungeon name"> <"date">
--
-- This function uses a proprietory cryptographic hash (yes, I know I shouldn't)
-- different from djb2() in Hardcore.lua, because that one doesn't work for long strings

local function GetCryptoHash(str)
	local a = 0
	local b = 0
	local dictionary = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 /:"

	for i = 1, #str do
		local x, y = string.find(dictionary, str:sub(i, i), 1, true)
		if x == nil then
			x = #dictionary
		end
		for i = 1, 17 do
			a = (a * -6 + b + 0x74FA - x) % 4096
			b = (math.floor(b / 3) + a + 0x81BE - x) % 4096
		end
	end
	return (a * 4096) + b
end

local function GetDungeonAppealCode(dungeon, date_str)
	local str = UnitName("player") .. UnitLevel("player") .. dungeon .. date_str
	return GetCryptoHash(str)
end

-- DungeonTrackerHandleAppealCode( args )
--
-- Called from Hardcore.lua when user types /hc AppealDungeonCode

function DungeonTrackerHandleAppealCode(args)
	local usage = "Usage: /hc AppealDungeonCode <code> <cmd> <args>\nwhere <cmd> = delete or reset"
	local usage1 = '/hc AppealDungeonCode <code> delete "dungeon name" "date"'
	--local usage2 = "/hc AppealDungeonCode <code> merge  <\"dungeon name\"> <\"date\"> <\"dungeon name\"> <\"date\">"
	local code = nil
	local cmd = nil
	local quoted_args = {}

	-- Check and retrieve code and command
	for substring in args:gmatch("%S+") do
		if code == nil then
			code = substring
		elseif cmd == nil then
			cmd = substring
		end
	end
	if code == nil then
		Hardcore:Print("Wrong syntax: Missing <code> argument")
		Hardcore:Print(usage)
		return
	end
	if cmd == nil then
		Hardcore:Print("Wrong syntax: Missing <cmd> argument")
		Hardcore:Print(usage)
		return
	end

	-- Handle reset command (which doesn't need arguments)
	if cmd == "reset" then
		local appeal_code = GetDungeonAppealCode("", "")
		if tonumber(code) ~= tonumber(appeal_code) then
			Hardcore:Print("Incorrect code. Double check with a moderator.")
			return
		end
		Hardcore_Character.dt = nil
		Hardcore:Print("Dungeon log reset")
		return
	end

	-- Retrieve arguments in quotes, chuck away the code and command and space between
	for arg in args:gmatch('[^"]+') do
		table.insert(quoted_args, arg)
	end
	table.remove(quoted_args, 1) -- Remove the code and command
	table.remove(quoted_args, 2) -- Remove the empty space

	if cmd == "delete" then
		if #quoted_args < 2 then
			Hardcore:Print("Wrong syntax: delete cmd should be followed by dungeon name and date string (both in quotes)")
			Hardcore:Print(usage1)
			return
		else
			-- Look for the run with that dungeon and date
			local run_found = false
			local index = 0
			for i, v in ipairs(Hardcore_Character.dt.runs) do
				if
					Hardcore_Character.dt.runs[i].name == quoted_args[1]
					and Hardcore_Character.dt.runs[i].date == quoted_args[2]
				then
					run_found = true
					index = i
				end
			end

			-- If we find multiple matches, we don't do anything
			if run_found == true then
				-- Check if the hash code is correct
				local appeal_code =
					GetDungeonAppealCode(Hardcore_Character.dt.runs[index].name, Hardcore_Character.dt.runs[index].date)

				if tonumber(code) ~= tonumber(appeal_code) then
					Hardcore:Print("Incorrect code. Double check with a moderator.")
					return
				end

				-- Delete the run
				Hardcore:Print(
					"Removed dungeon run "
						.. Hardcore_Character.dt.runs[index].name
						.. " of "
						.. Hardcore_Character.dt.runs[index].date
				)
				table.remove(Hardcore_Character.dt.runs, index)
				DungeonTrackerUpdateInfractions()
				return
			else
				local message = "Dungeon run in " .. quoted_args[1]
				if #quoted_args == 2 then
					message = message .. " of " .. quoted_args[2]
				end
				Hardcore:Print(message .. " not found!")
				return
			end
		end
	elseif cmd == "merge" then
		Hardcore:Print("Merge command not yet implemented!")
		return
	else
		Hardcore:Print("Unknown command: " .. cmd)
		Hardcore:Print(usage)
		return
	end
end
