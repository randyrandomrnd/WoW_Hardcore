local AceGUI = LibStub("AceGUI-3.0")
local CTL = _G.ChatThrottleLib
local COMM_NAME = "HCDeathAlerts"
local COMM_COMMANDS = {
  ["BROADCAST_DEATH_PING"] = "1",
  ["BROADCAST_DEATH_PING_CHECKSUM"] = "2",
}
local COMM_COMMAND_DELIM = "$"
local COMM_FIELD_DELIM = "~"

local death_alerts_channel = "hcdeathalertschannel"
local death_alerts_channel_pw = "hcdeathalertschannelpw"

local race_to_id = {
}
local id_to_race = {
}

local class_to_id = {
}
local id_to_class = {
}

local function PlayerData(name, guild, source_id, race_id, class_id, level, instance_id, map_id, map_pos, date, last_words)
  return {
    ["name"] = name,
    ["guild"] = guild,
    ["source_id"] = source_id,
    ["race_id"] = race_id,
    ["class_id"] = class_id,
    ["level"] = level,
    ["instance_id"] = instance_id,
    ["map_id"] = map_id,
    ["map_pos"] = map_pos,
    ["date"] = date,
    ["last_words"] = last_words,
  }
end

-- Message: name, guild,
local function encodeMessage(name, guild, source_id, race_id, class_id, level, instance_id, map_id, map_pos)
  local loc_str = ""
  if map_pos then
    loc_str = string.format("%.4f,%.4f", map_pos.x, map_pos.y)
  end
  local comm_message = name .. COMM_FIELD_DELIM .. (guild or "") .. COMM_FIELD_DELIM .. source_id .. COMM_FIELD_DELIM .. race_id .. COMM_FIELD_DELIM .. class_id .. COMM_FIELD_DELIM .. level .. COMM_FIELD_DELIM .. (instance_id or "")  .. COMM_FIELD_DELIM .. (map_id or "") .. COMM_FIELD_DELIM .. loc_str .. COMM_FIELD_DELIM
  return comm_message
end

local function decodeMessage(msg)
  local values = {}
  for w in msg:gmatch("(.-)~") do table.insert(values, w) end
  local date = nil
  local last_words = nil
  local name = values[1]
  local guild = values[2]
  local source_id = tonumber(values[3])
  local race_id = tonumber(values[4])
  local class_id = tonumber(values[5])
  local level = tonumber(values[6])
  local instance_id = tonumber(values[7])
  local map_id = tonumber(values[8])
  local map_pos = values[9]
  local player_data = PlayerData(name, guild, source_id, race_id, class_id, level, instance_id, map_id, map_pos, date, last_words)
  return player_data
end

-- [checksum -> {name, guild, source, race, class, level, F's, location, last_words, location}]
local death_ping_lru_cache_tbl = {}
local death_ping_lru_cache_ll = {}
local broadcast_death_ping_queue = {}
local death_alert_out_queue = {}
local f_log = {}

local function fletcher16(_player_data)
	local data = _player_data["name"] .. _player_data["guild"] .. _player_data["level"]
	local sum1 = 0
	local sum2 = 0
        for index=1,#data do
		sum1 = (sum1 + string.byte(string.sub(data,index,index))) % 255;
		sum2 = (sum2 + sum1) % 255;
        end
        return _player_data["name"] .. "-" .. bit.bor(bit.lshift(sum2,8), sum1)
end

local death_log_cache = {}

local death_log_frame = AceGUI:Create("Deathlog")
death_log_frame:SetTitle("Hardcore Death Log")
local subtitle_data = {{"name", 17}, {"guild", 100}, {"level", 160}, {"F's", 200}}
death_log_frame:SetSubTitle(subtitle_data)
death_log_frame:SetLayout("Fill")
death_log_frame:SetHeight(125)
death_log_frame:SetWidth(255)
death_log_frame:Show()

local scroll_frame = AceGUI:Create("ScrollFrame")
scroll_frame:SetLayout("List")
death_log_frame:AddChild(scroll_frame)

local selected = nil
local row_entry = {}
local column_offset = 17

for i=1,20 do
	row_entry[i] = AceGUI:Create("InteractiveLabel")
	local _entry = row_entry[i]
	_entry:SetHighlight("Interface\\Glues\\CharacterSelect\\Glues-CharacterSelect-Highlight")
	_entry.font_strings = {}
	local next_x = 0
	for idx,v in ipairs(subtitle_data) do 
	  _entry.font_strings[v[1]] = _entry.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	  _entry.font_strings[v[1]]:SetPoint("LEFT", _entry.frame, "LEFT", v[2] - column_offset, 0)
	  _entry.font_strings[v[1]]:SetJustifyH("LEFT")

	  if idx + 1 <= #subtitle_data then
	    _entry.font_strings[v[1]]:SetWidth(subtitle_data[idx + 1][2] - v[2])
	  end
	  _entry.font_strings[v[1]]:SetTextColor(1,1,1)
	end
	-- _entry:SetFullWidth(true)
	_entry:SetHeight(60)
	_entry:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
	_entry:SetColor(1,1,1)
	_entry:SetText(" ")
	-- _entry:SetWordWrap(false)

	function _entry:deselect()
	    for _,v in pairs(_entry.font_strings) do
	      v:SetTextColor(1,1,1)
	    end
	end

	function _entry:select()
	    selected = i
	    for _,v in pairs(_entry.font_strings) do
	      v:SetTextColor(1,1,0)
	    end
	end

	_entry:SetCallback("OnLeave", function(widget)
		if _entry.player_data == nil then return end
		GameTooltip:Hide()
	end)

	_entry:SetCallback("OnClick", function()
		if _entry.player_data == nil then return end
		local click_type = GetMouseButtonClicked()

		if click_type == "LeftButton" then
		  if selected then row_entry[selected]:deselect() end
		  _entry:select()
		elseif click_type == "RightButton" then
		  print("open dropdown options")
		end
	end)

	_entry:SetCallback("OnEnter", function(widget)
		if _entry.player_data == nil then return end
		GameTooltip_SetDefaultAnchor(GameTooltip, WorldFrame)

		if string.sub(_entry.player_data["name"], #_entry.player_data["name"]) == "s" then
		  GameTooltip:AddDoubleLine(_entry.player_data["name"] .. "' Death", "Lvl. " .. _entry.player_data["level"], 1, 1, 1, .5 ,.5, .5);

		else
		  GameTooltip:AddDoubleLine(_entry.player_data["name"] .. "'s Death", "Lvl. " .. _entry.player_data["level"], 1, 1, 1, .5 ,.5, .5);
		end
		GameTooltip:AddLine("Name: " .. _entry.player_data["name"],1,1,1)
		GameTooltip:AddLine("Guild: " .. _entry.player_data["guild"],1,1,1)
		GameTooltip:AddLine("Race: " .. _entry.player_data["race"],1,1,1)
		GameTooltip:AddLine("Class: " .. _entry.player_data["class"],1,1,1)
		GameTooltip:AddLine("Killed by: " .. "?", 1, 1, 1, true)
		GameTooltip:AddLine("Zone: " .. _entry.player_data["zone"], 1, 1, 1, true)
		GameTooltip:AddLine("Loc: " .. _entry.player_data["location"][1] .. ", " .. _entry.player_data["location"][1], 1, 1, 1, true)
		GameTooltip:AddLine("Date: " .. _entry.player_data["date"], 1, 1, 1, true)
		GameTooltip:AddLine("Last words: " .. _entry.player_data["last_words"],1,1,1,true)
		GameTooltip:Show()
	end)

	scroll_frame:SetScroll(1000000)
	scroll_frame.scrollbar:Hide()
	scroll_frame:AddChild(_entry)
end

local function setEntry(player_data, _entry)
	_entry.player_data = player_data
	for _,v in ipairs(subtitle_data) do 
	  _entry.font_strings[v[1]]:SetText(_entry.player_data[v[1]])
	end
end

local function shiftEntry(_entry_from, _entry_to)
  setEntry(_entry_from.player_data, _entry_to)
end


local i = 0
C_Timer.NewTicker(5, function()
local player_data = {
  ["name"] = "Yazpads",
  ["guild"] = "HC Elite",
  ["race"] = "Gnome",
  ["class"] = "Warlock",
  ["level"] = 12,
  ["last_words"] = '|cffdaa520"some last words,some last words,some last words,some last words,some last words,"|r',
  ["F's"] = 15,
  ["location"] = {14312.12, 1213.12},
  ["zone"] = "Elywynn Forest",
  ["date"] = date(),
}
  player_data["name"] = player_data["name"] .. i
  i = i + 1

  for i=1,19 do 
    if row_entry[i+1].player_data ~= nil then
      shiftEntry(row_entry[i+1], row_entry[i])
      if selected and selected == i+1 then
	row_entry[i+1]:deselect()
	row_entry[i]:select()
      end
    end
  end
  setEntry(player_data, row_entry[20])
end)

local function createEntry(checksum)
  for i=1,19 do 
    if row_entry[i+1].player_data ~= nil then
      shiftEntry(row_entry[i+1], row_entry[i])
      if selected and selected == i+1 then
	row_entry[i+1]:deselect()
	row_entry[i]:select()
      end
    end
  end
  setEntry(death_ping_lru_cache_tbl[checksum]["player_data"], row_entry[20])
  death_ping_lru_cache_tbl[checksum]["committed"] = 1
end


local function shouldCreateEntry(checksum)
  return true
  -- if death_ping_lru_cache_tbl[checksum] == nil then return end
  -- if death_ping_lru_cache_tbl[checksum]["in_guild"] then return true end
  -- if death_ping_lru_cache_tbl[checksum]["self_report"] and death_ping_lru_cache_tbl[checksum]["peer_report"] and death_ping_lru_cache_tbl[checksum]["peer_report"] > 0 then return true end
  -- return false
end

function selfDeathAlert(death_source_str)
	local map = C_Map.GetBestMapForUnit("player")
	local instance_id = nil
	local position = nil
	if map then 
		position = C_Map.GetPlayerMapPosition(map, "player")
		local continentID, worldPosition = C_Map.GetWorldPosFromMapPos(map, position)
		print(map, position.x)
	else
	  local _, _, _, _, _, _, _, _instance_id, _, _ = GetInstanceInfo()
	  instance_id = _instance_id
	end

	local guildName, guildRankName, guildRankIndex = GetGuildInfo("player");
	local _, _, race_id = UnitRace("player")
	local _, _, class_id = UnitClass("player")
	local death_source = "-1"
	if DeathLog_Last_Attack_Source then
	  death_source = npc_to_id[death_source_str]
	end

	msg = encodeMessage(UnitName("player"), guildName, death_source, race_id, class_id, UnitLevel("player"), instance_id, map, position)
	local commMessage = COMM_COMMANDS["BROADCAST_DEATH_PING"] .. COMM_COMMAND_DELIM .. msg
	local channel_num = GetChannelName(death_alerts_channel)

	table.insert(death_alert_out_queue, msg)
end

-- Receive a guild message. Need to send ack
function deathlogReceiveGuildMessage(sender, data)
  local decoded_player_data = decodeMessage(data)
  if sender ~= decoded_player_data["name"] then return end
  if decoded_player_data["source_id"] == nil then return end
  if decoded_player_data["race_id"] == nil then return end
  if decoded_player_data["class_id"] == nil then return end
  if decoded_player_data["level"] == nil or decoded_player_data["level"] < 0 or decoded_player_data["level"] > 80 then return end
  if decoded_player_data["instance_id"] == nil and decoded_player_data["map_id"] == nil then return end

  local valid = false
  for i = 1, GetNumGuildMembers() do
	  local name, _, _, level, class_str, _, _, _, _, _, class = GetGuildRosterInfo(i)
	  if name == sender and level == decoded_player_data["level"] then
	    valid = true
	  end
  end
  if valid == false then return end

  local checksum = fletcher16(decoded_player_data)

  if death_ping_lru_cache_tbl[checksum] == nil then
    death_ping_lru_cache_tbl[checksum] = {
      ["player_data"] = player_data,
    }
  end

  if death_ping_lru_cache_tbl[checksum]["committed"] then return end

  death_ping_lru_cache_tbl[checksum]["self_report"] = 1
  death_ping_lru_cache_tbl[checksum]["in_guild"] = 1
  table.insert(broadcast_death_ping_queue, checksum) -- Must be added to queue to be broadcasted to network
  if shouldCreateEntry(checksum) then
    createEntry(checksum)
  end
end

local function deathlogReceiveChannelMessageChecksum(sender, checksum)
  if death_ping_lru_cache_tbl[checksum] == nil then
    death_ping_lru_cache_tbl[checksum] = {}
  end

  if death_ping_lru_cache_tbl[checksum]["peer_report"] == nil then
    death_ping_lru_cache_tbl[checksum]["peer_report"] = 0
  end

  death_ping_lru_cache_tbl[checksum]["peer_report"] = death_ping_lru_cache_tbl[checksum]["peer_report"] + 1
end

local function deathlogReceiveChannelMessage(sender, data)
  local decoded_player_data = decodeMessage(data)
  if sender ~= decoded_player_data["name"] then return end
  if decoded_player_data["source_id"] == nil then return end
  if decoded_player_data["race_id"] == nil then return end
  if decoded_player_data["class_id"] == nil then return end
  if decoded_player_data["level"] == nil or decoded_player_data["level"] < 0 or decoded_player_data["level"] > 80 then return end
  if decoded_player_data["instance_id"] == nil and decoded_player_data["map_id"] == nil then return end

  local checksum = fletcher16(decoded_player_data)

  if death_ping_lru_cache_tbl[checksum] == nil then
    death_ping_lru_cache_tbl[checksum] = {}
  end

  if death_ping_lru_cache_tbl[checksum]["player_data"] == nil then
      death_ping_lru_cache_tbl[checksum]["player_data"] = decoded_player_data
  end

  if death_ping_lru_cache_tbl[checksum]["committed"] then return end

  death_ping_lru_cache_tbl[checksum]["self_report"] = 1
  if shouldCreateEntry(checksum) then
    createEntry(checksum)
  end
end

function deathlogReceiveF(sender, data)
  local checksum = decodeF()
  if f_log[checksum] == nil then
    f_log[checksum] = {
      ["num"] = 0,
    }
  end

  if f_log[checksum][sender] == nil then
    f_log[checksum][sender] = 1
    f_log[checksum]["num"] = f_log[checksum]["num"] + 1
  end
end

function deathlogJoinChannel()
        JoinChannelByName(death_alerts_channel, death_alerts_channel_pw)
	local channel_num = GetChannelName(death_alerts_channel)
        if channel_num == 0 then
	  print("Failed to join death alerts channel")
	else
	  print("Successfully joined deathlog channel.")
	end

	for i = 1, 10 do
	  if _G['ChatFrame'..i] then
	    ChatFrame_RemoveChannel(_G['ChatFrame'..i], death_alerts_channel)
	  end
	end
end

WorldFrame:HookScript("OnMouseDown", function(self, button)
	if #broadcast_death_ping_queue > 0 then 
		local channel_num = GetChannelName(death_alerts_channel)
		if channel_num == 0 then
		  deathlogJoinChannel()
		  return
		end

		local commMessage = COMM_COMMANDS["BROADCAST_DEATH_PING_CHECKSUM"] .. COMM_COMMAND_DELIM .. broadcast_death_ping_queue[1]
		CTL:SendChatMessage("BULK", COMM_NAME, commMessage, "CHANNEL", nil, channel_num)
		table.remove(broadcast_death_ping_queue, 1)
	end

	if #death_alert_out_queue > 0 then 
		local channel_num = GetChannelName(death_alerts_channel)
		if channel_num == 0 then
		  deathlogJoinChannel()
		  return
		end
		local commMessage = COMM_COMMANDS["BROADCAST_DEATH_PING"] .. COMM_COMMAND_DELIM .. death_alert_out_queue[1]
		CTL:SendChatMessage("BULK", COMM_NAME, commMessage, "CHANNEL", nil, channel_num)
		table.remove(death_alert_out_queue, 1)
	end
end)

local death_log_handler = CreateFrame("Frame")
death_log_handler:RegisterEvent("CHAT_MSG_CHANNEL")
death_log_handler:SetScript("OnEvent", function(self, event, ...)
  local arg = { ... }
  if event == "CHAT_MSG_CHANNEL" then
    local command, msg = string.split(COMM_COMMAND_DELIM, arg[1])
    if command == COMM_COMMANDS["BROADCAST_DEATH_PING_CHECKSUM"] then
      deathlogReceiveChannelMessageChecksum(sender, checksum)
      return
    end

    if command == COMM_COMMANDS["BROADCAST_DEATH_PING"] then
      local player_name_short, _ = string.split("-", arg[2])
      print(msg)
      deathlogReceiveChannelMessage(player_name_short, msg)
      return
    end
  end
end)

-- Todo; need a ticker for updating F's
--
