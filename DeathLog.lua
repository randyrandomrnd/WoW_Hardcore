local AceGUI = LibStub("AceGUI-3.0")

local race_to_id = {
}
local id_to_race = {
}

local class_to_id = {
}
local id_to_class = {
}

-- [checksum -> {name, guild, source, race, class, level, F's, location, last_words, location}]
local death_ping_lru_cache_tbl = {}
local death_ping_lru_cache_ll = {}
local broadcast_death_ping_queue = {}
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
C_Timer.NewTicker(.5, function()
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
  setEntry(death_ping_lru_cache_tbl["player_data"], row[20])
end


local function shouldCreateEntry(checksum)
  if death_ping_lru_cache_tbl[checksum] == nil then return end
  if death_ping_lru_cache_tbl[checksum]["in_guild"] then return true end
  if death_ping_lru_cache_tbl[checksum]["self_report"] and death_ping_lru_cache_tbl[checksum]["peer_report"] and death_ping_lru_cache_tbl[checksum]["peer_report"] > 0 then return true end
  return false
end

function deathlogReceiveGuildMessage(sender, data)
  local name, guild, race, class, level, location = decodeDeathData(data)
  if sender ~= name then return end

  local player_data = {
    ["name"] = name,
    ["guild"] = guild,
    ["race"] = race,
    ["class"] = class,
    ["level"] = level,
    ["location"] = location,
  }
  
  local checksum = fletcher16(player_data)
  if death_ping_lru_cache_tbl[checksum] == nil then
    death_ping_lru_cache_tbl[checksum] = {
      ["player_data"] = player_data,
    }
  end
  death_ping_lru_cache_tbl[checksum]["self_report"] = 1
  death_ping_lru_cache_tbl[checksum]["in_guild"] = 1
  table.insert(broadcast_death_ping_queue, checksum)
  if shouldCreateEntry(checksum) then
    createEntry(checksum)
  end
end

function deathlogReceiveChannelMessage(sender, data)
  local name, guild, race, class, level, location = decodeDeathData(data)

  local player_data = {
    ["name"] = name,
    ["guild"] = guild,
    ["race"] = race,
    ["class"] = class,
    ["level"] = level,
    ["location"] = location,
  }
  
  local checksum = fletcher16(player_data)
  if death_ping_lru_cache_tbl[checksum] == nil then
    death_ping_lru_cache_tbl[checksum] = {
      ["player_data"] = player_data,
      ["peer_report"] = 0,
    }
  end

  if sender == name then 
    death_ping_lru_cache_tbl[checksum]["self_report"] = 1
  else
    death_ping_lru_cache_tbl[checksum]["peer_report"] = death_ping_lru_cache_tbl[checksum]["peer_report"] + 1
  end
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

WorldFrame:HookScript("OnMouseDown", function(self, button)
	print("hook")
	if #broadcast_death_ping_queue < 1 then return end
	print(broadcast_death_ping_queue[1]) -- TODO broadcast
	-- encode checksum
	-- ctl send
	table.remove(broadcast_death_ping_queue, 1)
end)


-- Todo; need a ticker for updating F's
