local IPanel = CreateFrame("Frame", nil, CharacterFrame)
IPanel:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", -50, -200)
IPanel:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", -200, 0)
local I_f = CreateFrame("Frame", "YourFrameName", IPanel)
I_f:SetSize(400, 400)
I_f:SetPoint("CENTER")
I_f:Hide()

local I_t = I_f:CreateTexture(nil, "HIGH")
I_t:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopLeft")
I_t:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 2, -1)
I_t:SetWidth(256)
I_t:SetHeight(256)

local I_tr = I_f:CreateTexture(nil, "HIGH")
I_tr:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopRight")
I_tr:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 258, -1)
I_tr:SetWidth(128)
I_tr:SetHeight(256)

local I_bl = I_f:CreateTexture(nil, "HIGH")
I_bl:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-BottomLeft")
I_bl:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 2, -257)
I_bl:SetWidth(256)
I_bl:SetHeight(256)

local I_br = I_f:CreateTexture(nil, "HIGH")
I_br:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-BottomRight")
I_br:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 258, -257)
I_br:SetWidth(128)
I_br:SetHeight(256)

local title_text = I_f:CreateFontString(nil,"ARTWORK")
title_text:SetFont("Interface\\Addons\\Hardcore\\Media\\BreatheFire.ttf", 22)
title_text:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 150, -45)
title_text:SetTextColor(1,.82,0)
title_text:SetText("Hardcore")

IPanel:SetPoint("CENTER", 0, 0)
IPanel:Hide()

local AceGUI = LibStub("AceGUI-3.0")
local I_f2 = AceGUI:Create("HardcoreFrameEmpty")
I_f2:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 8, -38)
I_f2:SetWidth(360)
I_f2:SetHeight(350)
I_f2:Hide()

function ShowInspectHC(_hardcore_character, other_name, version)
	IPanel:SetParent(InspectFrame)
	IPanel:SetPoint("TOPLEFT", InspectFrame, "TOPLEFT", -50, -200)
	IPanel:SetPoint("BOTTOMRIGHT", InspectFrame, "BOTTOMRIGHT", -200, 0)
	I_t:SetPoint("TOPLEFT", InspectFrame, "TOPLEFT", 2, -1)
	I_tr:SetPoint("TOPLEFT", InspectFrame, "TOPLEFT", 258, -1)
	I_bl:SetPoint("TOPLEFT", InspectFrame, "TOPLEFT", 2, -257)
	I_br:SetPoint("TOPLEFT", InspectFrame, "TOPLEFT", 258, -257)
	I_f2:SetPoint("TOPLEFT", InspectFrame, "TOPLEFT", 8, -38)
	title_text:SetPoint("TOPLEFT", InspectFrame, "TOPLEFT", 150, -45)

	local class, _, _ = UnitClass("target")
	UpdateCharacterHC(_hardcore_character, other_name, version, I_f2, class, UnitLevel("target"))
	IPanel:Show()
	I_f:Show()
	I_f2:Show()
end

function HideInspectHC()
	IPanel:Hide()
	I_f:Hide()
	I_f2:Hide()
	I_f2:ReleaseChildren()
end
