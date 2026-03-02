-- SimpleMeters v0.3
-- Build date: 2026-03-02

local addon = _G.SimpleMeters
if not addon then
    return
end

local CreateFrame = CreateFrame
local UIParent = UIParent
local Minimap = Minimap
local GameTooltip = GameTooltip
local pairs = pairs
local ipairs = ipairs
local next = next
local max = math.max
local min = math.min
local abs = math.abs
local floor = math.floor
local cos = math.cos
local sin = math.sin
local rad = math.rad
local deg = math.deg
local atan = math.atan
local tinsert = table.insert
local tremove = table.remove
local tonumber = tonumber
local GetTime = GetTime
local GetCursorPosition = GetCursorPosition
local CLASS_ICON_TCOORDS = CLASS_ICON_TCOORDS
local UNKNOWNOBJECT = UNKNOWNOBJECT or "Unknown"
local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local PANEL_TYPE_BARS = "bars"
local PANEL_TYPE_TEXT = "text"

local PANEL_MIN_WIDTH = 240
local PANEL_MAX_WIDTH = 460
local PANEL_MIN_HEIGHT = 160
local PANEL_MAX_HEIGHT = 700

local PANEL_DEFAULT_WIDTH = PANEL_MIN_WIDTH
local PANEL_DEFAULT_HEIGHT = 236

local HEADER_HEIGHT = 24
local HEADER_PADDING = 3
local CONTENT_PADDING = 7

local TAB_HEIGHT = 18
local TAB_WIDTH = 56
local TAB_GAP = 5
local TAB_BOTTOM_INSET = 6

local HEADER_BUTTON_SIZE = 18
local CLOSE_BUTTON_SIZE = HEADER_BUTTON_SIZE
local SMALL_BUTTON_SIZE = HEADER_BUTTON_SIZE

local BOSS_LIST_HEIGHT = 56
local BOSS_BUTTON_COUNT = 4
local BOSS_BUTTON_HEIGHT = 13

local ROW_HEIGHT_BARS = 18
local ROW_HEIGHT_TEXT = 17
local ROW_SPACING = 2

local TAB_KEYS = { "total", "fight", "boss" }
local TAB_LABELS = {
    total = "Total",
    fight = "Fight",
    boss = "Boss",
}

local CLASS_ICON_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local UNKNOWN_SPELL_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local LOCKED_TEXTURE = "Interface\\Buttons\\LockButton-Locked-Up"
local UNLOCKED_TEXTURE = "Interface\\Buttons\\LockButton-Unlocked-Up"
local BOSS_ICON_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local PYROBLAST_ICON = "Interface\\Icons\\Spell_Fire_Fireball02"

local MINIMAP_BUTTON_SIZE = 31
local MINIMAP_ICON_INSET = 7
local BAR_VALUE_EPSILON = 0.001
local UI_TICK_INTERVAL = 0.75
local UI_IDLE_INTERVAL = 1.0
local ENABLE_IDLE_TICK_GUARD = true

local sortedActors = {}
local sortedValues = {}

local function Atan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    end

    if x > 0 then
        return atan(y / x)
    elseif x < 0 and y >= 0 then
        return atan(y / x) + math.pi
    elseif x < 0 and y < 0 then
        return atan(y / x) - math.pi
    elseif x == 0 and y > 0 then
        return math.pi / 2
    elseif x == 0 and y < 0 then
        return -math.pi / 2
    end

    return 0
end

local function IsValidMode(mode)
    return mode == "total" or mode == "fight" or mode == "boss"
end

local function IsValidPanelType(panelType)
    return panelType == PANEL_TYPE_BARS or panelType == PANEL_TYPE_TEXT
end

local function MarkDataDirty(addonRef)
    if not addonRef or not addonRef.state then
        return
    end
    addonRef.state.dataDirty = true
    addonRef.state.dirty = true
end

local function MarkRenderDirty(addonRef)
    if not addonRef or not addonRef.state then
        return
    end
    addonRef.state.renderDirty = true
    addonRef.state.uiDirty = true
end

local function GetPanelRowHeight(panelType)
    if panelType == PANEL_TYPE_TEXT then
        return ROW_HEIGHT_TEXT
    end
    return ROW_HEIGHT_BARS
end

local function GetPanelById(db, panelId)
    if not db or type(db.panels) ~= "table" then
        return nil, nil
    end

    for i = 1, #db.panels do
        local panel = db.panels[i]
        if panel and panel.id == panelId then
            return panel, i
        end
    end

    return nil, nil
end

local function EnsurePanelPosition(panel, fallbackX, fallbackY)
    if type(panel.position) ~= "table" then
        panel.position = {}
    end

    if type(panel.position.point) ~= "string" then
        panel.position.point = "RIGHT"
    end
    if type(panel.position.relativePoint) ~= "string" then
        panel.position.relativePoint = "RIGHT"
    end

    panel.position.x = tonumber(panel.position.x) or fallbackX
    panel.position.y = tonumber(panel.position.y) or fallbackY
end

local function EnsurePanelSize(panel)
    if type(panel.size) ~= "table" then
        panel.size = {}
    end

    local width = tonumber(panel.size.width) or PANEL_DEFAULT_WIDTH
    local height = tonumber(panel.size.height) or PANEL_DEFAULT_HEIGHT

    panel.size.width = max(PANEL_MIN_WIDTH, min(PANEL_MAX_WIDTH, floor(width + 0.5)))
    panel.size.height = max(PANEL_MIN_HEIGHT, min(PANEL_MAX_HEIGHT, floor(height + 0.5)))
end

local function GetSpawnPosition(db, panelType)
    local sameTypeCount = 0
    if db and type(db.panels) == "table" then
        for i = 1, #db.panels do
            local panel = db.panels[i]
            if panel and panel.type == panelType then
                sameTypeCount = sameTypeCount + 1
            end
        end
    end

    local baseX = (panelType == PANEL_TYPE_TEXT) and -298 or -30
    local x = baseX - ((sameTypeCount % 5) * 16)
    local y = 0 - ((sameTypeCount % 5) * 18)
    return x, y
end

local function IconMarkup(path)
    return "|T" .. (path or UNKNOWN_SPELL_ICON) .. ":12:12:0:0|t "
end

local function ValueForMode(addonRef, actor, mode)
    if mode == "fight" then
        return addonRef:GetActorValue(actor, "fight")
    end
    return addonRef:GetActorValue(actor, "total")
end

local function IsBetterCandidate(valueA, actorA, valueB, actorB)
    if valueA ~= valueB then
        return valueA > valueB
    end

    local nameA = actorA and actorA.name or UNKNOWNOBJECT
    local nameB = actorB and actorB.name or UNKNOWNOBJECT
    return nameA < nameB
end

local function InsertTopActor(actor, value, limit, count)
    if value <= 0 or limit <= 0 then
        return count
    end

    if count < limit then
        count = count + 1
    else
        local lastActor = sortedActors[count]
        local lastValue = sortedValues[count] or 0
        if not IsBetterCandidate(value, actor, lastValue, lastActor) then
            return count
        end
    end

    local pos = count
    while pos > 1 do
        local prevActor = sortedActors[pos - 1]
        local prevValue = sortedValues[pos - 1] or 0
        if IsBetterCandidate(value, actor, prevValue, prevActor) then
            sortedActors[pos] = prevActor
            sortedValues[pos] = prevValue
            pos = pos - 1
        else
            break
        end
    end

    sortedActors[pos] = actor
    sortedValues[pos] = value
    return count
end

local function SetRowClassIcon(row, classFile)
    if not row.classIcon then
        return
    end

    if row.classIconClass == classFile then
        if not classFile and row.classIcon:IsShown() then
            row.classIcon:SetTexture(nil)
            row.classIcon:Hide()
        end
        return
    end

    row.classIconClass = classFile

    local coords = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
    if coords then
        row.classIcon:SetTexture(CLASS_ICON_TEXTURE)
        row.classIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        row.classIcon:Show()
    else
        row.classIcon:SetTexture(nil)
        row.classIcon:Hide()
    end
end

local function CreateBarRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT_BARS)

    row.backdrop = CreateFrame("Frame", nil, row, BACKDROP_TEMPLATE)
    row.backdrop:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.backdrop:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    if row.backdrop.SetBackdrop then
        row.backdrop:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        row.backdrop:SetBackdropColor(0.02, 0.02, 0.02, 0.30)
        row.backdrop:SetBackdropBorderColor(0.28, 0.28, 0.28, 0.92)
    end

    row.barClip = CreateFrame("Frame", nil, row)
    row.barClip:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -2)
    row.barClip:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 2)

    row.barBG = row.barClip:CreateTexture(nil, "BACKGROUND")
    row.barBG:SetAllPoints()
    row.barBG:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    row.barBG:SetVertexColor(0.08, 0.08, 0.08, 0.65)

    row.bar = CreateFrame("StatusBar", nil, row.barClip)
    row.bar:SetAllPoints()
    row.bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    row.bar:SetMinMaxValues(0, 1)
    row.bar:SetValue(0)
    row.bar:SetStatusBarColor(0.25, 0.45, 0.80, 0.90)

    row.textLayer = CreateFrame("Frame", nil, row)
    row.textLayer:SetAllPoints()
    row.textLayer:SetFrameLevel(row.bar:GetFrameLevel() + 4)

    row.classIcon = row.textLayer:CreateTexture(nil, "OVERLAY")
    row.classIcon:SetSize(13, 13)
    row.classIcon:SetPoint("LEFT", row, "LEFT", 3, 0)

    row.nameText = row.textLayer:CreateFontString(nil, "OVERLAY")
    row.nameText:SetFont(STANDARD_TEXT_FONT, 11)
    row.nameText:SetPoint("LEFT", row.classIcon, "RIGHT", 2, 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetTextColor(1, 1, 1)
    row.nameText:SetShadowOffset(1, -1)
    row.nameText:SetShadowColor(0, 0, 0, 1)

    row.valueDpsText = row.textLayer:CreateFontString(nil, "OVERLAY")
    row.valueDpsText:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    row.valueDpsText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.valueDpsText:SetWidth(52)
    row.valueDpsText:SetJustifyH("RIGHT")
    row.valueDpsText:SetTextColor(1, 1, 1)
    row.valueDpsText:SetShadowOffset(1, -1)
    row.valueDpsText:SetShadowColor(0, 0, 0, 1)

    row.valueMainText = row.textLayer:CreateFontString(nil, "OVERLAY")
    row.valueMainText:SetFont(STANDARD_TEXT_FONT, 11)
    row.valueMainText:SetPoint("RIGHT", row.valueDpsText, "LEFT", -8, 0)
    row.valueMainText:SetWidth(72)
    row.valueMainText:SetJustifyH("RIGHT")
    row.valueMainText:SetTextColor(1, 1, 1)
    row.valueMainText:SetShadowOffset(1, -1)
    row.valueMainText:SetShadowColor(0, 0, 0, 1)
    row.valueText = row.valueMainText

    row.nameText:SetPoint("RIGHT", row.valueMainText, "LEFT", -8, 0)

    row:SetScript("OnEnter", function(selfRow)
        addon:ShowRowTooltip(selfRow)
    end)

    row:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    return row
end

local function CreateTextRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT_TEXT)

    row.classIcon = row:CreateTexture(nil, "ARTWORK")
    row.classIcon:SetSize(12, 12)
    row.classIcon:SetPoint("LEFT", row, "LEFT", 2, 0)

    row.nameText = row:CreateFontString(nil, "OVERLAY")
    row.nameText:SetFont(STANDARD_TEXT_FONT, 11)
    row.nameText:SetPoint("LEFT", row.classIcon, "RIGHT", 2, 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetTextColor(0.82, 0.82, 0.82)
    row.nameText:SetShadowOffset(1, -1)
    row.nameText:SetShadowColor(0, 0, 0, 1)

    row.valueDpsText = row:CreateFontString(nil, "OVERLAY")
    row.valueDpsText:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    row.valueDpsText:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.valueDpsText:SetWidth(50)
    row.valueDpsText:SetJustifyH("RIGHT")
    row.valueDpsText:SetTextColor(1, 1, 1)
    row.valueDpsText:SetShadowOffset(1, -1)
    row.valueDpsText:SetShadowColor(0, 0, 0, 1)

    row.valueMainText = row:CreateFontString(nil, "OVERLAY")
    row.valueMainText:SetFont(STANDARD_TEXT_FONT, 11)
    row.valueMainText:SetPoint("RIGHT", row.valueDpsText, "LEFT", -8, 0)
    row.valueMainText:SetWidth(66)
    row.valueMainText:SetJustifyH("RIGHT")
    row.valueMainText:SetTextColor(1, 1, 1)
    row.valueMainText:SetShadowOffset(1, -1)
    row.valueMainText:SetShadowColor(0, 0, 0, 1)
    row.valueText = row.valueMainText

    row.nameText:SetPoint("RIGHT", row.valueMainText, "LEFT", -8, 0)

    row:SetScript("OnEnter", function(selfRow)
        addon:ShowRowTooltip(selfRow)
    end)

    row:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    return row
end

function addon:GetPanelVisibleRowCount(frame)
    if not frame or not frame.cfg or not self.db then
        return 1
    end

    local rowHeight = GetPanelRowHeight(frame.cfg.type)
    local mode = frame.cfg.mode

    local hasBossHistory = false
    if mode == "boss" and self.GetBossHistory then
        local history = self:GetBossHistory() or {}
        hasBossHistory = #history > 0
    end

    local height = frame:GetHeight() or PANEL_DEFAULT_HEIGHT
    local top = HEADER_HEIGHT + CONTENT_PADDING + 2
    local bottom = TAB_HEIGHT + TAB_BOTTOM_INSET + CONTENT_PADDING + 6
    if mode == "boss" and hasBossHistory then
        bottom = bottom + BOSS_LIST_HEIGHT + 6
    end

    local available = height - top - bottom
    local visible = floor((available + ROW_SPACING) / (rowHeight + ROW_SPACING))
    visible = max(1, visible)
    visible = min(visible, self.db.rowCount or 8)
    return visible
end

function addon:EnsurePanelRows(frame)
    if not frame or not frame.cfg or not self.db then
        return
    end

    local rows = frame.rows
    local rowCount = self.db.rowCount or 8
    local rowHeight = GetPanelRowHeight(frame.cfg.type)

    for i = 1, rowCount do
        if not rows[i] then
            if frame.cfg.type == PANEL_TYPE_TEXT then
                rows[i] = CreateTextRow(frame.rowsParent)
            else
                rows[i] = CreateBarRow(frame.rowsParent)
            end
        end

        local y = -(HEADER_HEIGHT + CONTENT_PADDING + ((i - 1) * (rowHeight + ROW_SPACING)))
        rows[i]:ClearAllPoints()
        rows[i]:SetPoint("TOPLEFT", frame.rowsParent, "TOPLEFT", CONTENT_PADDING, y)
        rows[i]:SetPoint("TOPRIGHT", frame.rowsParent, "TOPRIGHT", -CONTENT_PADDING, y)
    end

    for i = rowCount + 1, #rows do
        rows[i]:Hide()
    end
end

function addon:FormatValueWithDPS(value, dps)
    return self:AbbrevNumber(value) .. "   (" .. self:AbbrevNumber(dps) .. "/s)"
end

function addon:SetRowValueTexts(row, value, dps)
    if not row then
        return
    end

    local mainText = self:AbbrevNumber(value or 0)
    local dpsText = "(" .. self:AbbrevNumber(dps or 0) .. "/s)"

    if row.valueMainText then
        if row._smMainText ~= mainText then
            row.valueMainText:SetText(mainText)
            row._smMainText = mainText
        end
    elseif row.valueText then
        if row._smMainText ~= mainText then
            row.valueText:SetText(mainText)
            row._smMainText = mainText
        end
    end

    if row.valueDpsText then
        if row._smDpsText ~= dpsText then
            row.valueDpsText:SetText(dpsText)
            row._smDpsText = dpsText
        end
    end
end

function addon:FormatPercent(value, total)
    if not total or total <= 0 then
        return "0%"
    end
    return string.format("%.1f%%", (value / total) * 100)
end

function addon:ShowBreakdownLines(totalDamage, spells, pets)
    if not GameTooltip then
        return
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Top Spells", 1.0, 0.82, 0.20)

    if not spells or #spells == 0 then
        GameTooltip:AddLine("No spell data", 0.65, 0.65, 0.65)
    else
        local maxLines = min(8, #spells)
        for i = 1, maxLines do
            local entry = spells[i]
            local label = IconMarkup(entry.icon) .. (entry.name or UNKNOWNOBJECT)
            if entry.petName and entry.petName ~= "" then
                label = label .. " |cff9a9a9a(" .. entry.petName .. ")|r"
            end
            local value = self:AbbrevNumber(entry.amount) .. " (" .. self:FormatPercent(entry.amount, totalDamage) .. ")"
            GameTooltip:AddDoubleLine(label, value, 0.90, 0.90, 0.90, 0.95, 0.95, 0.95)
        end
    end

    if pets and #pets > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Pet Damage", 0.55, 0.90, 1.00)

        local maxPets = min(4, #pets)
        for i = 1, maxPets do
            local entry = pets[i]
            local label = IconMarkup(entry.icon) .. (entry.name or "Pet")
            local value = self:AbbrevNumber(entry.amount) .. " (" .. self:FormatPercent(entry.amount, totalDamage) .. ")"
            GameTooltip:AddDoubleLine(label, value, 0.85, 0.95, 1.0, 0.92, 0.95, 1.0)
        end
    end
end

function addon:ShowRowTooltip(row)
    if not GameTooltip or not row then
        return
    end

    local tooltipData
    local title = UNKNOWNOBJECT
    local classFile

    if row.snapshotActor then
        tooltipData = self:GetSnapshotTooltipData(row.snapshotActor, row.snapshotDuration)
        title = row.snapshotActor.name or UNKNOWNOBJECT
        classFile = row.snapshotActor.classFile
    elseif row.actorRef then
        tooltipData = self:GetActorTooltipData(row.actorRef, row.dataMode)
        title = row.actorRef.name or UNKNOWNOBJECT
        classFile = row.actorRef.classFile
    end

    if not tooltipData then
        return
    end

    local damage = tooltipData.damage or 0
    local duration = max(1, tooltipData.duration or 1)
    local dps = damage / duration

    local titleR, titleG, titleB = self:GetClassColorRGB(classFile)
    GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
    GameTooltip:SetText(title, titleR, titleG, titleB)
    GameTooltip:AddDoubleLine("Damage", self:AbbrevNumber(damage), 0.90, 0.90, 0.90, 1, 1, 1)
    GameTooltip:AddDoubleLine("DPS", self:AbbrevNumber(dps), 0.90, 0.90, 0.90, 1, 1, 1)

    self:ShowBreakdownLines(damage, tooltipData.spells, tooltipData.pets)

    GameTooltip:Show()
end

local function ApplyPanelLock(frame)
    if not frame or not frame.cfg then
        return
    end

    local locked = frame.cfg.locked == true
    if locked then
        frame:StopMovingOrSizing()
    end

    if frame.header then
        frame.header:EnableMouse(not locked)
    end
    if frame.resizeHandle then
        frame.resizeHandle:EnableMouse(not locked)
    end

    if frame.lockButton and frame.lockButton.icon then
        if locked then
            frame.lockButton.icon:SetTexture(LOCKED_TEXTURE)
        else
            frame.lockButton.icon:SetTexture(UNLOCKED_TEXTURE)
        end
    end
end

local function UpdatePanelTabs(frame)
    if not frame or not frame.tabs or not frame.cfg then
        return
    end

    for _, key in ipairs(TAB_KEYS) do
        local tab = frame.tabs[key]
        if tab then
            local selected = (key == frame.cfg.mode)
            local text = tab:GetFontString()

            if text then
                if selected then
                    text:SetTextColor(1.0, 0.82, 0.0)
                else
                    text:SetTextColor(1.0, 1.0, 1.0)
                end
                text:SetShadowColor(0, 0, 0, 1)
            end

            if selected then
                tab:LockHighlight()
            else
                tab:UnlockHighlight()
            end
        end
    end
end

local function SetPanelMode(addonRef, frame, mode)
    if not frame or not frame.cfg or not IsValidMode(mode) then
        return
    end

    frame.cfg.mode = mode
    UpdatePanelTabs(frame)

    MarkRenderDirty(addonRef)

    addonRef:EnsurePanelRows(frame)
    addonRef:OnUITick(false)
    if addonRef.WakeUITicker then
        addonRef:WakeUITicker()
    end
end

local function UpdateBossList(addonRef, frame)
    if not frame or not frame.bossList or not frame.cfg then
        return nil
    end

    local history = addonRef:GetBossHistory() or {}
    if frame.cfg.mode ~= "boss" or #history == 0 then
        frame.bossList:Hide()
        for i = 1, BOSS_BUTTON_COUNT do
            local btn = frame.bossButtons and frame.bossButtons[i]
            if btn then
                btn.entryId = nil
                btn:Hide()
                btn:UnlockHighlight()
            end
        end
        return nil
    end

    frame.bossList:Show()

    local selectedId = frame.cfg.selectedBossId
    local selectedEntry = nil

    for i = 1, #history do
        if history[i].id == selectedId then
            selectedEntry = history[i]
            break
        end
    end

    if not selectedEntry then
        selectedEntry = history[1]
        frame.cfg.selectedBossId = selectedEntry and selectedEntry.id or nil
        selectedId = frame.cfg.selectedBossId
    end

    for i = 1, BOSS_BUTTON_COUNT do
        local btn = frame.bossButtons[i]
        local entry = history[i]

        if entry then
            btn.entryId = entry.id
            btn:Show()
            btn.text:SetText(IconMarkup(BOSS_ICON_TEXTURE) .. (entry.name or UNKNOWNOBJECT))
            btn.text:SetTextColor(0.84, 0.84, 0.84)

            if entry.id == selectedId then
                btn:LockHighlight()
            else
                btn:UnlockHighlight()
            end
        else
            btn.entryId = nil
            btn:Hide()
            btn:UnlockHighlight()
        end
    end

    return selectedEntry
end

local function CreateHeader(addonRef, frame)
    local header = CreateFrame("Frame", nil, frame)
    frame.header = header
    header:SetHeight(HEADER_HEIGHT)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", HEADER_PADDING, -HEADER_PADDING)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -HEADER_PADDING, -HEADER_PADDING)

    local headerBG = header:CreateTexture(nil, "BACKGROUND")
    headerBG:SetAllPoints()
    headerBG:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    headerBG:SetVertexColor(0.07, 0.07, 0.07, 0.56)

    local separator = frame:CreateTexture(nil, "BORDER")
    frame.headerSeparator = separator
    separator:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    separator:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -(HEADER_HEIGHT + HEADER_PADDING + 1))
    separator:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -(HEADER_HEIGHT + HEADER_PADDING + 1))
    separator:SetHeight(1)
    separator:SetVertexColor(0.58, 0.50, 0.30, 0.65)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.title = title
    title:SetPoint("LEFT", header, "LEFT", 7, 0)
    title:SetText("SimpleMeters")
    title:SetTextColor(1.0, 0.82, 0.0)
    title:SetShadowOffset(1, -1)
    title:SetShadowColor(0, 0, 0, 1)

    local closeButton = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    frame.closeButton = closeButton
    closeButton:SetSize(CLOSE_BUTTON_SIZE, CLOSE_BUTTON_SIZE)
    closeButton:SetPoint("TOPRIGHT", header, "TOPRIGHT", -1, -1)
    closeButton:SetText("x")
    closeButton:SetNormalFontObject(GameFontNormalSmall)
    closeButton:SetHighlightFontObject(GameFontHighlightSmall)
    closeButton:SetPushedTextOffset(0, 0)
    closeButton:SetScript("OnClick", function()
        addonRef:DestroyPanel(frame.cfg.id)
    end)

    local resetButton = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    frame.resetButton = resetButton
    resetButton:SetSize(SMALL_BUTTON_SIZE, SMALL_BUTTON_SIZE)
    resetButton:SetPoint("RIGHT", closeButton, "LEFT", -2, 0)
    resetButton:SetText("R")
    resetButton:SetNormalFontObject(GameFontNormalSmall)
    resetButton:SetHighlightFontObject(GameFontHighlightSmall)
    resetButton:SetPushedTextOffset(0, 0)
    resetButton:SetScript("OnClick", function()
        addonRef:PromptReset("Are you sure you want to reset SimpleMeters?")
    end)

    local lockButton = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    frame.lockButton = lockButton
    lockButton:SetSize(SMALL_BUTTON_SIZE, SMALL_BUTTON_SIZE)
    lockButton:SetPoint("RIGHT", resetButton, "LEFT", -2, 0)
    lockButton:SetText("")
    lockButton.icon = lockButton:CreateTexture(nil, "ARTWORK")
    lockButton.icon:SetPoint("TOPLEFT", lockButton, "TOPLEFT", 2, -2)
    lockButton.icon:SetPoint("BOTTOMRIGHT", lockButton, "BOTTOMRIGHT", -2, 2)

    lockButton:SetScript("OnClick", function()
        frame.cfg.locked = not frame.cfg.locked
        ApplyPanelLock(frame)
        if frame.cfg.locked then
            addonRef:Print("Panel locked.")
        else
            addonRef:Print("Panel unlocked.")
        end
    end)

    lockButton:SetScript("OnEnter", function(selfButton)
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
        if frame.cfg.locked then
            GameTooltip:SetText("Unlock", 1, 1, 1)
        else
            GameTooltip:SetText("Lock", 1, 1, 1)
        end
        GameTooltip:Show()
    end)

    lockButton:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    header:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and not frame.cfg.locked then
            frame:StartMoving()
        end
    end)

    header:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            frame:StopMovingOrSizing()
            local point, _, relativePoint, x, y = frame:GetPoint(1)
            if point then
                frame.cfg.position.point = point
                frame.cfg.position.relativePoint = relativePoint
                frame.cfg.position.x = x
                frame.cfg.position.y = y
            end
        end
    end)
end

local function CreateTabs(addonRef, frame)
    frame.tabs = {}

    local totalTabsWidth = (#TAB_KEYS * TAB_WIDTH) + ((#TAB_KEYS - 1) * TAB_GAP)
    local tabsStartX = -floor(totalTabsWidth / 2)

    local prevTab = nil
    for i, key in ipairs(TAB_KEYS) do
        local tab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        frame.tabs[key] = tab

        tab:SetSize(TAB_WIDTH, TAB_HEIGHT)
        tab:SetText(TAB_LABELS[key])
        tab:SetNormalFontObject(GameFontNormalSmall)
        tab:SetHighlightFontObject(GameFontHighlightSmall)

        local text = tab:GetFontString()
        if text then
            text:SetShadowOffset(1, -1)
            text:SetShadowColor(0, 0, 0, 1)
        end

        if i == 1 then
            tab:SetPoint("BOTTOMLEFT", frame, "BOTTOM", tabsStartX, TAB_BOTTOM_INSET)
        else
            tab:SetPoint("LEFT", prevTab, "RIGHT", TAB_GAP, 0)
        end

        tab:SetScript("OnClick", function()
            SetPanelMode(addonRef, frame, key)
        end)

        prevTab = tab
    end

    UpdatePanelTabs(frame)
end

local function CreateBossList(addonRef, frame)
    local bossList = CreateFrame("Frame", nil, frame)
    frame.bossList = bossList
    bossList:SetHeight(BOSS_LIST_HEIGHT)
    bossList:SetPoint("BOTTOM", frame, "BOTTOM", 0, TAB_BOTTOM_INSET + TAB_HEIGHT + 6)
    bossList:SetWidth((frame:GetWidth() or PANEL_DEFAULT_WIDTH) - 20)

    local title = bossList:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOP", bossList, "TOP", 0, -4)
    title:SetText("Boss Kills")

    frame.bossButtons = {}
    for i = 1, BOSS_BUTTON_COUNT do
        local btn = CreateFrame("Button", nil, bossList)
        frame.bossButtons[i] = btn

        btn:SetHeight(BOSS_BUTTON_HEIGHT)
        btn:SetPoint("LEFT", bossList, "LEFT", 10, 0)
        btn:SetPoint("RIGHT", bossList, "RIGHT", -10, 0)

        if i == 1 then
            btn:SetPoint("TOP", title, "BOTTOM", 0, -3)
        else
            btn:SetPoint("TOP", frame.bossButtons[i - 1], "BOTTOM", 0, -1)
        end

        local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        highlight:SetBlendMode("ADD")

        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btn.text = text
        text:SetPoint("LEFT", btn, "LEFT", 0, 0)
        text:SetPoint("RIGHT", btn, "RIGHT", 0, 0)
        text:SetJustifyH("CENTER")

        btn:SetScript("OnClick", function(selfButton)
            if selfButton.entryId then
                frame.cfg.selectedBossId = selfButton.entryId
                MarkRenderDirty(addonRef)
                addonRef:OnUITick(false)
                if addonRef.WakeUITicker then
                    addonRef:WakeUITicker()
                end
            end
        end)
    end

    bossList:Hide()
end

local function CreateResizeHandle(frame)
    local resizeHandle = CreateFrame("Button", nil, frame)
    frame.resizeHandle = resizeHandle
    resizeHandle:SetSize(14, 14)
    resizeHandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)

    local texture = resizeHandle:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")

    resizeHandle:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and not frame.cfg.locked then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)

    resizeHandle:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            frame:StopMovingOrSizing()
            local width = frame:GetWidth() or PANEL_DEFAULT_WIDTH
            local height = frame:GetHeight() or PANEL_DEFAULT_HEIGHT
            frame.cfg.size.width = max(PANEL_MIN_WIDTH, min(PANEL_MAX_WIDTH, floor(width + 0.5)))
            frame.cfg.size.height = max(PANEL_MIN_HEIGHT, min(PANEL_MAX_HEIGHT, floor(height + 0.5)))
        end
    end)
end

function addon:CreatePanel(panel)
    if not self.db or type(panel) ~= "table" then
        return nil
    end

    self.panelFrames = self.panelFrames or {}
    if self.panelFrames[panel.id] then
        return self.panelFrames[panel.id]
    end

    if not IsValidPanelType(panel.type) then
        panel.type = PANEL_TYPE_BARS
    end
    if not IsValidMode(panel.mode) then
        panel.mode = "total"
    end
    if type(panel.locked) ~= "boolean" then
        panel.locked = false
    end
    if type(panel.shown) ~= "boolean" then
        panel.shown = true
    end

    EnsurePanelSize(panel)

    local fallbackX = (panel.type == PANEL_TYPE_TEXT) and -298 or -30
    EnsurePanelPosition(panel, fallbackX, 0)

    local frameName = "SimpleMetersPanel" .. panel.id
    local frame = CreateFrame("Frame", frameName, UIParent, BACKDROP_TEMPLATE)
    frame.cfg = panel

    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetClampedToScreen(true)
    frame:SetUserPlaced(false)
    frame:SetScale(self.db.scale or 1)

    frame:SetSize(panel.size.width, panel.size.height)
    frame:ClearAllPoints()
    frame:SetPoint(
        panel.position.point,
        UIParent,
        panel.position.relativePoint,
        panel.position.x,
        panel.position.y
    )

    if frame.SetResizeBounds then
        frame:SetResizeBounds(PANEL_MIN_WIDTH, PANEL_MIN_HEIGHT, PANEL_MAX_WIDTH, PANEL_MAX_HEIGHT)
    else
        if type(frame.SetMinResize) == "function" then
            frame:SetMinResize(PANEL_MIN_WIDTH, PANEL_MIN_HEIGHT)
        end
        if type(frame.SetMaxResize) == "function" then
            frame:SetMaxResize(PANEL_MAX_WIDTH, PANEL_MAX_HEIGHT)
        end
    end

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        frame:SetBackdropColor(0.02, 0.02, 0.02, 0.70)
        frame:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
    end

    frame:SetScript("OnSizeChanged", function(selfFrame, width, height)
        local clampedW = max(PANEL_MIN_WIDTH, min(PANEL_MAX_WIDTH, width or PANEL_DEFAULT_WIDTH))
        local clampedH = max(PANEL_MIN_HEIGHT, min(PANEL_MAX_HEIGHT, height or PANEL_DEFAULT_HEIGHT))

        if clampedW ~= width or clampedH ~= height then
            selfFrame:SetSize(clampedW, clampedH)
            return
        end

        panel.size.width = floor(clampedW + 0.5)
        panel.size.height = floor(clampedH + 0.5)

        if selfFrame.bossList then
            selfFrame.bossList:SetWidth(max(120, clampedW - 20))
        end

        addon:EnsurePanelRows(selfFrame)
        MarkRenderDirty(addon)
    end)

    frame:SetScript("OnHide", function(selfFrame)
        selfFrame:StopMovingOrSizing()
    end)

    frame.rowsParent = CreateFrame("Frame", nil, frame)
    frame.rowsParent:SetAllPoints(frame)
    frame.rows = {}

    CreateHeader(self, frame)
    CreateTabs(self, frame)
    CreateBossList(self, frame)
    CreateResizeHandle(frame)

    self:EnsurePanelRows(frame)
    ApplyPanelLock(frame)

    if panel.shown then
        frame:Show()
    else
        frame:Hide()
    end

    self.panelFrames[panel.id] = frame
    return frame
end

function addon:DestroyPanel(panelId)
    if not self.db or type(self.db.panels) ~= "table" then
        return false
    end

    local panel, index = GetPanelById(self.db, panelId)
    if not panel or not index then
        return false
    end

    tremove(self.db.panels, index)

    if self.panelFrames and self.panelFrames[panelId] then
        local frame = self.panelFrames[panelId]
        frame:Hide()
        frame:SetParent(nil)
        self.panelFrames[panelId] = nil
    end

    MarkRenderDirty(self)
    if self.WakeUITicker then
        self:WakeUITicker()
    end

    return true
end

function addon:SpawnPanel(panelType)
    if not self.db then
        return false, "Database not ready."
    end

    if not IsValidPanelType(panelType) then
        return false, "Invalid panel type."
    end

    local panels = self.db.panels
    if type(panels) ~= "table" then
        panels = {}
        self.db.panels = panels
    end

    if #panels >= (self.MAX_PANELS or 10) then
        return false, "Panel limit reached (10)."
    end

    local panelId = tonumber(self.db.nextPanelId) or 1
    panelId = max(1, floor(panelId + 0.5))

    local x, y = GetSpawnPosition(self.db, panelType)
    local newPanel = {
        id = panelId,
        type = panelType,
        shown = true,
        locked = false,
        mode = "total",
        position = {
            point = "RIGHT",
            relativePoint = "RIGHT",
            x = x,
            y = y,
        },
        size = {
            width = PANEL_MIN_WIDTH,
            height = PANEL_DEFAULT_HEIGHT,
        },
        selectedBossId = nil,
    }

    panels[#panels + 1] = newPanel
    self.db.nextPanelId = panelId + 1

    self:CreatePanel(newPanel)

    MarkRenderDirty(self)
    self:OnUITick(false)
    if self.WakeUITicker then
        self:WakeUITicker()
    end
    return true, newPanel
end

function addon:GetAnyPanelShown()
    if not self.db or type(self.db.panels) ~= "table" then
        return false
    end

    for i = 1, #self.db.panels do
        local panel = self.db.panels[i]
        if panel and panel.shown then
            return true
        end
    end

    return false
end

function addon:ToggleAllPanels()
    if not self.db then
        return false
    end

    local panels = self.db.panels
    if type(panels) ~= "table" or #panels == 0 then
        local ok = self:SpawnPanel(PANEL_TYPE_BARS)
        return ok and true or false
    end

    local anyShown = self:GetAnyPanelShown()
    local show = not anyShown

    for i = 1, #panels do
        local panel = panels[i]
        panel.shown = show

        local frame = self.panelFrames and self.panelFrames[panel.id]
        if show then
            if not frame then
                frame = self:CreatePanel(panel)
            end
            if frame then
                frame:Show()
            end
        else
            if frame then
                frame:Hide()
            end
        end
    end

    if show then
        MarkRenderDirty(self)
        self:OnUITick(false)
        if self.WakeUITicker then
            self:WakeUITicker()
        end
    end

    return show
end

local function BuildTopEntries(addonRef, mode, now, limit)
    local count = 0
    addonRef.modeEntryBuffers = addonRef.modeEntryBuffers or {}
    local entries = addonRef.modeEntryBuffers[mode]
    if not entries then
        entries = {}
        addonRef.modeEntryBuffers[mode] = entries
    end

    for _, actor in pairs(addonRef:GetActorsTable()) do
        local value = ValueForMode(addonRef, actor, mode)
        if value > 0 then
            count = InsertTopActor(actor, value, limit, count)
        end
    end

    for i = 1, count do
        local entry = entries[i]
        if entry then
            entry.actor = sortedActors[i]
            entry.value = sortedValues[i] or 0
        else
            entries[i] = {
                actor = sortedActors[i],
                value = sortedValues[i] or 0,
            }
        end
    end

    for i = count + 1, #entries do
        entries[i] = nil
    end

    for i = count + 1, #sortedActors do
        sortedActors[i] = nil
        sortedValues[i] = nil
    end

    local duration
    if mode == "fight" then
        duration = addonRef:GetFightDuration(now)
    else
        duration = addonRef:GetTotalDuration(now)
    end

    return {
        entries = entries,
        maxValue = entries[1] and entries[1].value or 0,
        duration = max(1, duration or 1),
    }
end

function addon:BuildModeCaches(now, opts)
    self.modeCache = self.modeCache or {}
    opts = opts or {}

    local limit = self.db and self.db.rowCount or 8
    if limit < 1 then
        limit = 1
    end

    local fightCache = self.modeCache.fight
    local totalCache = self.modeCache.total

    local rebuildFight = opts.force or opts.rebuildFight or not fightCache
    local rebuildTotal = opts.force or opts.rebuildTotal or not totalCache

    if fightCache and fightCache.limit ~= limit then
        rebuildFight = true
    end
    if totalCache and totalCache.limit ~= limit then
        rebuildTotal = true
    end

    if rebuildFight then
        local builtFight = BuildTopEntries(self, "fight", now, limit)
        builtFight.limit = limit
        self.modeCache.fight = builtFight
    end

    if rebuildTotal then
        local builtTotal = BuildTopEntries(self, "total", now, limit)
        builtTotal.limit = limit
        self.modeCache.total = builtTotal
    end

    return self.modeCache
end

local function RenderBarRows(addonRef, frame, entries, rowLimit, duration, maxValue, instant)
    local rows = frame.rows
    local rowCount = addonRef.db.rowCount or 8

    for i = 1, rowCount do
        local row = rows[i]
        local entry = (i <= rowLimit) and entries[i] or nil

        if entry then
            local actor = entry.actor
            local value = entry.value or 0
            local dps = value / max(1, duration)

            if not row._smVisible then
                row:Show()
                row._smVisible = true
            end
            row.actorRef = actor
            row.snapshotActor = nil
            row.snapshotDuration = nil
            row.dataMode = frame.cfg.mode

            local name = actor and actor.name or UNKNOWNOBJECT
            if row._smNameText ~= name then
                row.nameText:SetText(name)
                row._smNameText = name
            end
            if row._smNameR ~= 1 or row._smNameG ~= 1 or row._smNameB ~= 1 then
                row.nameText:SetTextColor(1, 1, 1)
                row._smNameR = 1
                row._smNameG = 1
                row._smNameB = 1
            end
            addonRef:SetRowValueTexts(row, value, dps)

            local color = actor and actor.color
            local r = 0.82
            local g = 0.82
            local b = 0.82
            if color then
                r = color.r or color[1] or r
                g = color.g or color[2] or g
                b = color.b or color[3] or b
            end

            local br, bg, bb, ba = r * 0.92, g * 0.92, b * 0.92, 0.90
            if row._smBarR ~= br or row._smBarG ~= bg or row._smBarB ~= bb or row._smBarA ~= ba then
                row.bar:SetStatusBarColor(br, bg, bb, ba)
                row._smBarR = br
                row._smBarG = bg
                row._smBarB = bb
                row._smBarA = ba
            end

            local fill = 0
            if maxValue and maxValue > 0 then
                fill = value / maxValue
            end
            fill = max(0, min(1, fill))
            if row._smBarValue == nil or abs(row._smBarValue - fill) > BAR_VALUE_EPSILON then
                row.bar:SetValue(fill)
                row._smBarValue = fill
            end

            SetRowClassIcon(row, actor and actor.classFile)
        else
            if row._smVisible ~= false then
                row:Hide()
                row._smVisible = false
            end
            row.actorRef = nil
            row.snapshotActor = nil
            row.snapshotDuration = nil
            row.dataMode = nil
            row.classIconClass = nil
            if row._smBarValue == nil or row._smBarValue ~= 0 then
                row.bar:SetValue(0)
                row._smBarValue = 0
            end
            if row.valueMainText then
                if row._smMainText ~= "" then
                    row.valueMainText:SetText("")
                    row._smMainText = ""
                end
            end
            if row.valueDpsText then
                if row._smDpsText ~= "" then
                    row.valueDpsText:SetText("")
                    row._smDpsText = ""
                end
            end
        end
    end
end

local function RenderTextRows(addonRef, frame, entries, rowLimit, duration)
    local rows = frame.rows
    local rowCount = addonRef.db.rowCount or 8

    for i = 1, rowCount do
        local row = rows[i]
        local entry = (i <= rowLimit) and entries[i] or nil

        if entry then
            local actor = entry.actor
            local value = entry.value or 0
            local dps = value / max(1, duration)
            local r, g, b = addonRef:GetClassColorRGB(actor and actor.classFile)

            if not row._smVisible then
                row:Show()
                row._smVisible = true
            end
            row.actorRef = actor
            row.snapshotActor = nil
            row.snapshotDuration = nil
            row.dataMode = frame.cfg.mode
            local name = actor and actor.name or UNKNOWNOBJECT
            if row._smNameText ~= name then
                row.nameText:SetText(name)
                row._smNameText = name
            end
            if row._smNameR ~= r or row._smNameG ~= g or row._smNameB ~= b then
                row.nameText:SetTextColor(r, g, b)
                row._smNameR = r
                row._smNameG = g
                row._smNameB = b
            end
            addonRef:SetRowValueTexts(row, value, dps)
            SetRowClassIcon(row, actor and actor.classFile)
        else
            if row._smVisible ~= false then
                row:Hide()
                row._smVisible = false
            end
            row.actorRef = nil
            row.snapshotActor = nil
            row.snapshotDuration = nil
            row.dataMode = nil
            row.classIconClass = nil
            if row.valueMainText then
                if row._smMainText ~= "" then
                    row.valueMainText:SetText("")
                    row._smMainText = ""
                end
            end
            if row.valueDpsText then
                if row._smDpsText ~= "" then
                    row.valueDpsText:SetText("")
                    row._smDpsText = ""
                end
            end
        end
    end
end

local function BuildBossEntriesForPanel(addonRef, frame, rowLimit)
    local selected = UpdateBossList(addonRef, frame)
    if not selected then
        return nil
    end

    local duration = max(1, selected.duration or 1)
    local sourceActors = selected.actors or {}
    local entries = frame.bossEntriesBuffer
    if not entries then
        entries = {}
        frame.bossEntriesBuffer = entries
    end
    local count = 0

    for i = 1, rowLimit do
        local actor = sourceActors[i]
        if not actor then
            break
        end
        count = count + 1
        local entry = entries[count]
        if entry then
            entry.actor = nil
            entry.snapshotActor = actor
            entry.value = actor.damage or 0
        else
            entries[count] = {
                actor = nil,
                snapshotActor = actor,
                value = actor.damage or 0,
            }
        end
    end

    for i = count + 1, #entries do
        entries[i] = nil
    end

    local maxValue = entries[1] and entries[1].value or 0
    return {
        entries = entries,
        maxValue = maxValue,
        duration = duration,
    }
end

local function RenderBossRows(addonRef, frame, bossData, rowLimit)
    local rows = frame.rows
    local rowCount = addonRef.db.rowCount or 8

    local entries = bossData and bossData.entries or {}
    local duration = bossData and bossData.duration or 1
    local maxValue = bossData and bossData.maxValue or 0

    for i = 1, rowCount do
        local row = rows[i]
        local entry = (i <= rowLimit) and entries[i] or nil

        if entry and entry.snapshotActor then
            local actor = entry.snapshotActor
            local damage = entry.value or 0
            local dps = damage / max(1, duration)
            local r, g, b = addonRef:GetClassColorRGB(actor.classFile)

            if not row._smVisible then
                row:Show()
                row._smVisible = true
            end
            row.actorRef = nil
            row.snapshotActor = actor
            row.snapshotDuration = duration
            row.dataMode = "boss"

            local name = actor.name or UNKNOWNOBJECT
            if row._smNameText ~= name then
                row.nameText:SetText(name)
                row._smNameText = name
            end

            if frame.cfg.type == PANEL_TYPE_TEXT then
                if row._smNameR ~= r or row._smNameG ~= g or row._smNameB ~= b then
                    row.nameText:SetTextColor(r, g, b)
                    row._smNameR = r
                    row._smNameG = g
                    row._smNameB = b
                end
                addonRef:SetRowValueTexts(row, damage, dps)
                SetRowClassIcon(row, actor.classFile)
            else
                if row._smNameR ~= 1 or row._smNameG ~= 1 or row._smNameB ~= 1 then
                    row.nameText:SetTextColor(1, 1, 1)
                    row._smNameR = 1
                    row._smNameG = 1
                    row._smNameB = 1
                end
                addonRef:SetRowValueTexts(row, damage, dps)
                local br, bg, bb, ba = r * 0.92, g * 0.92, b * 0.92, 0.90
                if row._smBarR ~= br or row._smBarG ~= bg or row._smBarB ~= bb or row._smBarA ~= ba then
                    row.bar:SetStatusBarColor(br, bg, bb, ba)
                    row._smBarR = br
                    row._smBarG = bg
                    row._smBarB = bb
                    row._smBarA = ba
                end
                local fill = 0
                if maxValue > 0 then
                    fill = damage / maxValue
                end
                fill = max(0, min(1, fill))
                if row._smBarValue == nil or abs(row._smBarValue - fill) > BAR_VALUE_EPSILON then
                    row.bar:SetValue(fill)
                    row._smBarValue = fill
                end
                SetRowClassIcon(row, actor.classFile)
            end
        else
            if row._smVisible ~= false then
                row:Hide()
                row._smVisible = false
            end
            row.actorRef = nil
            row.snapshotActor = nil
            row.snapshotDuration = nil
            row.dataMode = nil
            row.classIconClass = nil
            if row.bar then
                if row._smBarValue == nil or row._smBarValue ~= 0 then
                    row.bar:SetValue(0)
                    row._smBarValue = 0
                end
            end
            if row.valueMainText then
                if row._smMainText ~= "" then
                    row.valueMainText:SetText("")
                    row._smMainText = ""
                end
            end
            if row.valueDpsText then
                if row._smDpsText ~= "" then
                    row.valueDpsText:SetText("")
                    row._smDpsText = ""
                end
            end
        end
    end
end

function addon:RenderPanel(frame, now, modeCaches)
    if not frame or not frame.cfg or not frame:IsShown() or not frame.cfg.shown then
        return
    end

    local cfg = frame.cfg
    local rowLimit = self:GetPanelVisibleRowCount(frame)

    if cfg.mode == "boss" then
        local bossData = BuildBossEntriesForPanel(self, frame, rowLimit)
        RenderBossRows(self, frame, bossData, rowLimit)
        return
    end

    if frame.bossList then
        frame.bossList:Hide()
    end

    local data = modeCaches and modeCaches[cfg.mode]
    if not data then
        local durationFallback = (cfg.mode == "fight") and self:GetFightDuration(now) or self:GetTotalDuration(now)
        data = {
            entries = {},
            maxValue = 0,
            duration = max(1, durationFallback or 1),
        }
    end

    if cfg.type == PANEL_TYPE_TEXT then
        RenderTextRows(self, frame, data.entries or {}, rowLimit, data.duration)
    else
        local instant = cfg.mode ~= "fight"
        RenderBarRows(self, frame, data.entries or {}, rowLimit, data.duration, data.maxValue, instant)
    end
end

function addon:HasVisiblePanels()
    if not self.panelFrames then
        return false
    end

    for _, frame in pairs(self.panelFrames) do
        if frame and frame.cfg and frame.cfg.shown and frame:IsShown() then
            return true
        end
    end

    return false
end

function addon:HasPendingGUIDLookups()
    if not self.state then
        return false
    end

    local head = tonumber(self.state.pendingGUIDLookupHead) or 1
    local tail = tonumber(self.state.pendingGUIDLookupTail) or 0
    return head <= tail
end

function addon:HasPendingBossKills()
    return self.state and self.state.pendingBossKills and #self.state.pendingBossKills > 0
end

function addon:GetUITickInterval()
    if self.state and self.state.awaitingFightEnd then
        return UI_IDLE_INTERVAL
    end
    return UI_TICK_INTERVAL
end

function addon:NeedsUITick(now)
    if not self.state then
        return false
    end

    now = now or GetTime()
    local state = self.state

    if state.inFight then
        return true
    end
    if state.awaitingFightEnd then
        return true
    end
    if self:HasPendingGUIDLookups() or self:HasPendingBossKills() then
        return true
    end
    if state.dataDirty or state.dirty then
        return true
    end
    if self:HasVisiblePanels() and (state.renderDirty or state.uiDirty) then
        return true
    end
    return false
end

function addon:OnUITick(force)
    if not self.state or not self.db then
        return
    end

    local state = self.state
    local now = GetTime()

    if self.UpdateFightTimeout then
        self:UpdateFightTimeout(now)
    end
    if self.ProcessPendingGUIDLookups then
        self:ProcessPendingGUIDLookups(8)
    end
    if self.ScanBossUnits then
        self:ScanBossUnits()
    end
    if self.ProcessPendingBossKills then
        self:ProcessPendingBossKills(2)
    end

    local dataDirty = state.dataDirty == true or state.dirty == true
    local renderDirty = state.renderDirty == true or state.uiDirty == true
    local hasVisible = self:HasVisiblePanels()

    local fightTick = state.inFight and not state.awaitingFightEnd
    local totalPeriodicTick = false
    if state.inFight then
        local totalDamage = tonumber(state.totalDamage) or 0
        if totalDamage <= 0 then
            totalPeriodicTick = true
        else
            local nextTotalRefreshAt = tonumber(state.nextTotalRefreshAt) or 0
            if now >= nextTotalRefreshAt then
                totalPeriodicTick = true
                state.nextTotalRefreshAt = now + 10
            end
        end
    end

    local rebuildFight = force or dataDirty or fightTick
    local rebuildTotal = force or dataDirty or totalPeriodicTick
    local shouldBuildData = rebuildFight or rebuildTotal
    local shouldRender = hasVisible and (force or renderDirty or shouldBuildData)

    if not shouldBuildData and not shouldRender then
        if ENABLE_IDLE_TICK_GUARD and self.StopUITicker and not self:NeedsUITick(now) then
            self:StopUITicker()
        end
        return
    end

    local modeCaches
    if shouldBuildData then
        modeCaches = self:BuildModeCaches(now, {
            force = force,
            rebuildFight = rebuildFight,
            rebuildTotal = rebuildTotal,
        })
    else
        modeCaches = self.modeCache or {}
    end

    if shouldRender and self.panelFrames then
        for _, frame in pairs(self.panelFrames) do
            self:RenderPanel(frame, now, modeCaches)
        end
    end

    if shouldBuildData then
        state.dataDirty = false
        state.dirty = false
    end
    if shouldRender or not hasVisible then
        state.renderDirty = false
        state.uiDirty = false
    end

    if ENABLE_IDLE_TICK_GUARD and self.StopUITicker and not self:NeedsUITick(now) then
        self:StopUITicker()
    end
end

function addon:UpdateMinimapButtonPosition()
    if not self.db or not self.minimapButton or not Minimap then
        return
    end

    local minimap = self.db.minimap or {}
    local angle = tonumber(minimap.angle) or 220
    local radius = tonumber(minimap.radius) or 78
    radius = max(60, min(96, radius))
    minimap.radius = radius

    local x = cos(rad(angle)) * radius
    local y = sin(rad(angle)) * radius

    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)

    if minimap.hide then
        self.minimapButton:Hide()
    else
        self.minimapButton:Show()
    end
end

function addon:UpdateMinimapAngleFromCursor()
    if not self.db or not Minimap then
        return
    end

    local mx, my = Minimap:GetCenter()
    if not mx or not my then
        return
    end

    local scale = Minimap:GetEffectiveScale() or 1
    local cx, cy = GetCursorPosition()
    cx = cx / scale
    cy = cy / scale

    local dx = cx - mx
    local dy = cy - my

    local angle = deg(Atan2(dy, dx))
    if angle < 0 then
        angle = angle + 360
    end

    local minimap = self.db.minimap or {}
    self.db.minimap = minimap
    minimap.angle = angle
    self:UpdateMinimapButtonPosition()
end

function addon:CreateMinimapButton()
    if self.minimapButton or not Minimap then
        return
    end

    local button = CreateFrame("Button", "SimpleMetersMinimapButton", Minimap)
    self.minimapButton = button

    button:SetFrameStrata("MEDIUM")
    button:SetSize(MINIMAP_BUTTON_SIZE, MINIMAP_BUTTON_SIZE)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture(PYROBLAST_ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", MINIMAP_ICON_INSET, -MINIMAP_ICON_INSET + 1)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -MINIMAP_ICON_INSET + 1, MINIMAP_ICON_INSET - 1)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:SetSize(54, 54)

    button.dragged = false

    button:SetScript("OnDragStart", function(selfButton)
        selfButton.dragged = false
        selfButton:SetScript("OnUpdate", function()
            addon:UpdateMinimapAngleFromCursor()
            selfButton.dragged = true
        end)
    end)

    button:SetScript("OnDragStop", function(selfButton)
        selfButton:SetScript("OnUpdate", nil)
    end)

    button:SetScript("OnClick", function(selfButton)
        if selfButton.dragged then
            selfButton.dragged = false
            return
        end
        addon:ToggleAllPanels()
    end)

    button:SetScript("OnEnter", function(selfButton)
        if not GameTooltip then
            return
        end

        GameTooltip:SetOwner(selfButton, "ANCHOR_LEFT")
        GameTooltip:SetText("SimpleMeters", 0.30, 0.80, 1.00)
        GameTooltip:AddLine("Drag: move on minimap ring", 1.00, 0.82, 0.20)
        GameTooltip:AddLine("Click: toggle all panels", 0.75, 1.00, 0.75)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    self:UpdateMinimapButtonPosition()
end

function addon:StartUITicker()
    if not self.uiTicker then
        self.uiTicker = CreateFrame("Frame")
    end

    if self.uiTickerRunning then
        return
    end

    local ticker = self.uiTicker
    ticker.tickElapsed = 0
    ticker:SetScript("OnUpdate", self.uiTickerOnUpdate)
    self.uiTickerRunning = true
end

function addon:StopUITicker()
    if not self.uiTicker then
        return
    end

    self.uiTicker.tickElapsed = 0
    self.uiTicker:SetScript("OnUpdate", nil)
    self.uiTickerRunning = false
end

function addon:WakeUITicker()
    if not ENABLE_IDLE_TICK_GUARD then
        return
    end
    if self:NeedsUITick(GetTime()) then
        self:StartUITicker()
    end
end

function addon:CreateUI()
    self.panelFrames = self.panelFrames or {}

    if not self.db or type(self.db.panels) ~= "table" then
        return
    end

    for i = 1, #self.db.panels do
        local panel = self.db.panels[i]
        self:CreatePanel(panel)
    end

    if not self.uiTicker then
        self.uiTicker = CreateFrame("Frame")
    end

    if not self.uiTickerOnUpdate then
        self.uiTickerOnUpdate = function(_, elapsed)
            if not addon.state then
                return
            end

            local ticker = addon.uiTicker
            ticker.tickElapsed = (ticker.tickElapsed or 0) + elapsed

            local tickInterval = addon:GetUITickInterval()
            local runs = 0
            while ticker.tickElapsed >= tickInterval and runs < 2 do
                ticker.tickElapsed = ticker.tickElapsed - tickInterval
                addon:OnUITick(false)
                runs = runs + 1
                tickInterval = addon:GetUITickInterval()
            end

            if ticker.tickElapsed > (tickInterval * 2) then
                ticker.tickElapsed = tickInterval
            end

            if ENABLE_IDLE_TICK_GUARD and not addon:NeedsUITick(GetTime()) then
                addon:StopUITicker()
            end
        end
    end

    if ENABLE_IDLE_TICK_GUARD then
        if self:NeedsUITick(GetTime()) then
            self:StartUITicker()
        else
            self:StopUITicker()
        end
    else
        self:StartUITicker()
    end

    self:CreateMinimapButton()
end

function addon:ApplyUISavedSettings()
    if not self.db then
        return
    end

    if self.panelFrames then
        for _, frame in pairs(self.panelFrames) do
            if frame and frame.cfg then
                frame:SetScale(self.db.scale or 1)
                EnsurePanelSize(frame.cfg)
                EnsurePanelPosition(frame.cfg, -30, 0)

                frame:SetSize(frame.cfg.size.width, frame.cfg.size.height)
                frame:ClearAllPoints()
                frame:SetPoint(
                    frame.cfg.position.point,
                    UIParent,
                    frame.cfg.position.relativePoint,
                    frame.cfg.position.x,
                    frame.cfg.position.y
                )

                UpdatePanelTabs(frame)
                ApplyPanelLock(frame)

                if frame.cfg.shown then
                    frame:Show()
                else
                    frame:Hide()
                end
            end
        end
    end

    self:UpdateMinimapButtonPosition()

    MarkDataDirty(self)
    MarkRenderDirty(self)
    self:OnUITick(true)
    if self.WakeUITicker then
        self:WakeUITicker()
    end
end
