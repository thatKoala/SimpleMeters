-- SimpleMeters v0.4
-- Build date: 2026-03-02

local addonName = ...
local addon = _G.SimpleMeters or {}
_G.SimpleMeters = addon

addon.addonName = addonName
addon.eventFrame = addon.eventFrame or CreateFrame("Frame")
addon.MAX_PANELS = 10

local floor = math.floor
local max = math.max
local min = math.min
local tonumber = tonumber
local strlower = string.lower
local GetTime = GetTime
local tremove = table.remove

local VERSION = "0.4"
local RESET_POPUP_ID = "SIMPLEMETERS_CONFIRM_RESET"
local CHAT_PREFIX = "|cff66c6ff[SimpleMeters]|r "

local PANEL_TYPE_BARS = "bars"
local PANEL_TYPE_TEXT = "text"

local DEFAULTS = {
    panels = {
        {
            id = 1,
            type = PANEL_TYPE_BARS,
            shown = true,
            locked = false,
            mode = "total",
            position = {
                point = "RIGHT",
                relativePoint = "RIGHT",
                x = -30,
                y = 0,
            },
            size = {
                width = 252,
                height = 236,
            },
        },
    },
    nextPanelId = 2,
    rowCount = 8,
    scale = 1,
    mergePets = true,
    minimap = {
        hide = false,
        angle = 220,
        radius = 78,
    },
}

local function CopyDefaults(dst, src)
    for key, value in pairs(src) do
        if type(value) == "table" then
            if type(dst[key]) ~= "table" then
                dst[key] = {}
            end
            CopyDefaults(dst[key], value)
        elseif dst[key] == nil then
            dst[key] = value
        end
    end
end

local function IsValidMode(mode)
    return mode == "total" or mode == "fight" or mode == "boss"
end

local function IsValidPanelType(panelType)
    return panelType == PANEL_TYPE_BARS or panelType == PANEL_TYPE_TEXT
end

local function ClampPanelSize(size)
    local width = tonumber(size and size.width) or 252
    local height = tonumber(size and size.height) or 236

    width = max(240, min(460, floor(width + 0.5)))
    height = max(160, min(700, floor(height + 0.5)))

    return width, height
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

local function BuildLegacyPanel(legacyPanel, panelType, shownDefault, fallbackX, fallbackY, globalMode, globalLocked)
    local panel = {}

    if type(legacyPanel) == "table" then
        if type(legacyPanel.position) == "table" then
            panel.position = {
                point = legacyPanel.position.point,
                relativePoint = legacyPanel.position.relativePoint,
                x = legacyPanel.position.x,
                y = legacyPanel.position.y,
            }
        end
        if type(legacyPanel.size) == "table" then
            panel.size = {
                width = legacyPanel.size.width,
                height = legacyPanel.size.height,
            }
        end
        if type(legacyPanel.shown) == "boolean" then
            panel.shown = legacyPanel.shown
        end
    end

    panel.type = panelType
    panel.shown = (type(panel.shown) == "boolean") and panel.shown or shownDefault
    panel.locked = (type(globalLocked) == "boolean") and globalLocked or false
    panel.mode = IsValidMode(globalMode) and globalMode or "total"

    if type(panel.size) ~= "table" then
        panel.size = {}
    end
    local width, height = ClampPanelSize(panel.size)
    panel.size.width = width
    panel.size.height = height

    EnsurePanelPosition(panel, fallbackX, fallbackY)
    return panel
end

local function EnsureResetDialog()
    if not StaticPopupDialogs or not StaticPopup_Show then
        return
    end

    if StaticPopupDialogs[RESET_POPUP_ID] then
        return
    end

    StaticPopupDialogs[RESET_POPUP_ID] = {
        text = "%s",
        button1 = YES,
        button2 = NO,
        OnAccept = function()
            if addon.ResetAll then
                addon:ResetAll()
            end
            addon:Print("Meters were reset.")
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }
end

function addon:Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(CHAT_PREFIX .. message)
    end
end

local function CommandText(command)
    return "|cffffd100" .. command .. "|r"
end

function addon:PrintHelp()
    self:Print(CommandText("/smsm") .. " or " .. CommandText("/smsm help") .. " shows all the commands available.")
    self:Print(CommandText("/smsm show") .. " shows all SimpleMeters panels.")
    self:Print(CommandText("/smsm hide") .. " hides all SimpleMeters panels.")
    self:Print(CommandText("/smsm toggle") .. " will toggle to show or hide the available SimpleMeters panels.")
    self:Print(CommandText("/smsm 1") .. " creates a SimpleMeters bar panel, and you can have many panels.")
    self:Print(CommandText("/smsm 2") .. " creates a SimpleMeters text panel, and you can have many panels.")
    self:Print(CommandText("/smsm minimap") .. " or " .. CommandText("/smsm map") .. " toggles the minimap button.")
end

function addon:PromptReset(reason)
    reason = reason or "Are you sure you want to reset SimpleMeters?"

    if not StaticPopupDialogs or not StaticPopup_Show then
        if self.ResetAll then
            self:ResetAll()
        end
        self:Print("Meters were reset.")
        return
    end

    EnsureResetDialog()
    StaticPopup_Show(RESET_POPUP_ID, reason)
end

function addon:InitializeDB()
    if type(SimpleMetersDB) ~= "table" then
        SimpleMetersDB = {}
    end

    -- Legacy migration for older fixed-panel schema.
    if type(SimpleMetersDB.panels) ~= "table" then
        local migrated = {}

        local hadLegacyPanel1 = type(SimpleMetersDB.panel1) == "table"
            or type(SimpleMetersDB.position) == "table"
            or type(SimpleMetersDB.width) == "number"
            or type(SimpleMetersDB.height) == "number"
            or type(SimpleMetersDB.shown) == "boolean"

        local hadLegacyPanel2 = type(SimpleMetersDB.panel2) == "table"
            or type(SimpleMetersDB.position2) == "table"
            or type(SimpleMetersDB.shown2) == "boolean"

        if hadLegacyPanel1 then
            local lp1 = SimpleMetersDB.panel1
            if type(lp1) ~= "table" then
                lp1 = {
                    shown = SimpleMetersDB.shown,
                    position = SimpleMetersDB.position,
                    size = {
                        width = SimpleMetersDB.width,
                        height = SimpleMetersDB.height,
                    },
                }
            else
                if type(lp1.position) ~= "table" and type(SimpleMetersDB.position) == "table" then
                    lp1.position = {
                        point = SimpleMetersDB.position.point,
                        relativePoint = SimpleMetersDB.position.relativePoint,
                        x = SimpleMetersDB.position.x,
                        y = SimpleMetersDB.position.y,
                    }
                end
                if type(lp1.size) ~= "table" and (type(SimpleMetersDB.width) == "number" or type(SimpleMetersDB.height) == "number") then
                    lp1.size = {
                        width = SimpleMetersDB.width,
                        height = SimpleMetersDB.height,
                    }
                end
                if type(lp1.shown) ~= "boolean" and type(SimpleMetersDB.shown) == "boolean" then
                    lp1.shown = SimpleMetersDB.shown
                end
            end

            migrated[#migrated + 1] = BuildLegacyPanel(lp1, PANEL_TYPE_BARS, true, -30, 0, SimpleMetersDB.mode, SimpleMetersDB.locked)
        end

        if hadLegacyPanel2 then
            local lp2 = SimpleMetersDB.panel2
            if type(lp2) ~= "table" then
                lp2 = {
                    shown = SimpleMetersDB.shown2,
                    position = SimpleMetersDB.position2,
                    size = {
                        width = SimpleMetersDB.width,
                        height = SimpleMetersDB.height,
                    },
                }
            else
                if type(lp2.position) ~= "table" and type(SimpleMetersDB.position2) == "table" then
                    lp2.position = {
                        point = SimpleMetersDB.position2.point,
                        relativePoint = SimpleMetersDB.position2.relativePoint,
                        x = SimpleMetersDB.position2.x,
                        y = SimpleMetersDB.position2.y,
                    }
                end
                if type(lp2.size) ~= "table" and (type(SimpleMetersDB.width) == "number" or type(SimpleMetersDB.height) == "number") then
                    lp2.size = {
                        width = SimpleMetersDB.width,
                        height = SimpleMetersDB.height,
                    }
                end
                if type(lp2.shown) ~= "boolean" and type(SimpleMetersDB.shown2) == "boolean" then
                    lp2.shown = SimpleMetersDB.shown2
                end
            end

            migrated[#migrated + 1] = BuildLegacyPanel(lp2, PANEL_TYPE_TEXT, false, -296, 0, SimpleMetersDB.mode, SimpleMetersDB.locked)
        end

        if #migrated == 0 then
            migrated[1] = BuildLegacyPanel(nil, PANEL_TYPE_BARS, true, -30, 0, "total", false)
        end

        SimpleMetersDB.panels = migrated
    end

    CopyDefaults(SimpleMetersDB, DEFAULTS)

    if type(SimpleMetersDB.rowCount) ~= "number" then
        SimpleMetersDB.rowCount = DEFAULTS.rowCount
    end
    SimpleMetersDB.rowCount = max(1, min(20, floor(SimpleMetersDB.rowCount + 0.5)))

    if type(SimpleMetersDB.scale) ~= "number" then
        SimpleMetersDB.scale = DEFAULTS.scale
    end
    SimpleMetersDB.scale = max(0.75, min(1.5, SimpleMetersDB.scale))

    if type(SimpleMetersDB.mergePets) ~= "boolean" then
        SimpleMetersDB.mergePets = DEFAULTS.mergePets
    end

    if type(SimpleMetersDB.minimap) ~= "table" then
        SimpleMetersDB.minimap = {}
    end
    if type(SimpleMetersDB.minimap.hide) ~= "boolean" then
        SimpleMetersDB.minimap.hide = DEFAULTS.minimap.hide
    end
    if type(SimpleMetersDB.minimap.angle) ~= "number" then
        SimpleMetersDB.minimap.angle = DEFAULTS.minimap.angle
    end
    if type(SimpleMetersDB.minimap.radius) ~= "number" then
        SimpleMetersDB.minimap.radius = DEFAULTS.minimap.radius
    end
    SimpleMetersDB.minimap.radius = max(60, min(110, floor(SimpleMetersDB.minimap.radius + 0.5)))

    local seenIds = {}
    local maxId = 0
    local normalized = {}

    for i = 1, #SimpleMetersDB.panels do
        if #normalized >= addon.MAX_PANELS then
            break
        end

        local panel = SimpleMetersDB.panels[i]
        if type(panel) == "table" then
            if not IsValidPanelType(panel.type) then
                panel.type = PANEL_TYPE_BARS
            end

            if type(panel.shown) ~= "boolean" then
                panel.shown = (panel.type == PANEL_TYPE_BARS and #normalized == 0)
            end

            if type(panel.locked) ~= "boolean" then
                panel.locked = false
            end

            if not IsValidMode(panel.mode) then
                panel.mode = "total"
            end

            if type(panel.size) ~= "table" then
                panel.size = {}
            end
            local width, height = ClampPanelSize(panel.size)
            panel.size.width = width
            panel.size.height = height

            local fallbackX = (panel.type == PANEL_TYPE_TEXT) and -296 or -30
            local fallbackY = 0
            EnsurePanelPosition(panel, fallbackX, fallbackY)

            local panelId = tonumber(panel.id)
            panelId = panelId and floor(panelId + 0.5) or nil
            if not panelId or panelId <= 0 or seenIds[panelId] then
                panelId = maxId + 1
            end

            panel.id = panelId
            seenIds[panelId] = true
            if panelId > maxId then
                maxId = panelId
            end

            if type(panel.selectedBossId) ~= "number" then
                panel.selectedBossId = nil
            end

            normalized[#normalized + 1] = panel
        end
    end

    if #normalized == 0 then
        normalized[1] = {
            id = 1,
            type = PANEL_TYPE_BARS,
            shown = true,
            locked = false,
            mode = "total",
            position = {
                point = "RIGHT",
                relativePoint = "RIGHT",
                x = -30,
                y = 0,
            },
            size = {
                width = 252,
                height = 236,
            },
        }
        maxId = 1
    end

    SimpleMetersDB.panels = normalized
    SimpleMetersDB.nextPanelId = max(maxId + 1, tonumber(SimpleMetersDB.nextPanelId) or 1)

    self.db = SimpleMetersDB
end

function addon:RegisterRuntimeEvents()
    local frame = self.eventFrame
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_LEAVING_WORLD")
    frame:RegisterEvent("PLAYER_LOGOUT")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    frame:RegisterEvent("BOSS_KILL")
    frame:RegisterEvent("CHAT_MSG_SYSTEM")
end

function addon:RegisterSlashCommands()
    SLASH_SIMPLEMETERS1 = "/smsm"
    SlashCmdList.SIMPLEMETERS = function(msg)
        addon:HandleSlash(msg or "")
    end
end

function addon:HandleSlash(msg)
    local command = strlower((msg or ""):match("^(%S*)") or "")

    if command == "" then
        self:PrintHelp()
        return
    end

    if command == "help" then
        self:PrintHelp()
        return
    end

    if command == "show" then
        if self.SetAllPanelsShown then
            self:SetAllPanelsShown(true)
            self:Print("All panels are now shown.")
        end
        return
    end

    if command == "hide" then
        if self.SetAllPanelsShown then
            self:SetAllPanelsShown(false)
            self:Print("All panels are now hidden.")
        end
        return
    end

    if command == "toggle" then
        if self.ToggleAllPanels then
            local shown = self:ToggleAllPanels()
            if shown then
                self:Print("All panels are now shown.")
            else
                self:Print("All panels are now hidden.")
            end
        end
        return
    end

    if command == "1" then
        if self.SpawnPanel then
            local ok, info = self:SpawnPanel(PANEL_TYPE_BARS)
            if ok then
                self:Print("A new bar panel was created.")
            else
                self:Print(info or "Panel limit reached.")
            end
        end
        return
    end

    if command == "2" then
        if self.SpawnPanel then
            local ok, info = self:SpawnPanel(PANEL_TYPE_TEXT)
            if ok then
                self:Print("A new text panel was created.")
            else
                self:Print(info or "Panel limit reached.")
            end
        end
        return
    end

    if command == "minimap" or command == "map" then
        if self.db and self.db.minimap then
            self.db.minimap.hide = not self.db.minimap.hide
        end
        if self.UpdateMinimapButtonPosition then
            self:UpdateMinimapButtonPosition()
        end
        if self.db and self.db.minimap and self.db.minimap.hide then
            self:Print("Minimap button hidden.")
        else
            self:Print("Minimap button shown.")
        end
        return
    end

    self:PrintHelp()
end

function addon:ADDON_LOADED(loadedAddonName)
    if loadedAddonName ~= addonName then
        return
    end

    self:InitializeDB()

    if self.InitializeCombat then
        self:InitializeCombat()
    end

    if self.RestorePersistedCombat then
        self:RestorePersistedCombat()
    end

    if self.CreateUI then
        self:CreateUI()
    end

    if self.ApplyUISavedSettings then
        self:ApplyUISavedSettings()
    end

    self:RegisterSlashCommands()
    self:RegisterRuntimeEvents()

    if self.RefreshRosterCache then
        self:RefreshRosterCache()
    end

    self:Print("v" .. VERSION .. " loaded. Type |cffffd100/smsm|r for options.")

    self.eventFrame:UnregisterEvent("ADDON_LOADED")
end

function addon:PLAYER_ENTERING_WORLD()
    if self.RefreshRosterCache then
        self:RefreshRosterCache()
    end
    if self.WakeUITicker and not self.uiTickerRunning then
        self:WakeUITicker()
    end
end

function addon:PLAYER_LEAVING_WORLD()
    if self.SavePersistedCombat then
        self:SavePersistedCombat(true)
    end
end

function addon:PLAYER_LOGOUT()
    if self.SavePersistedCombat then
        self:SavePersistedCombat(true)
    end
end

function addon:GROUP_ROSTER_UPDATE()
    local changed, joined, left = false, 0, 0
    if self.RefreshRosterCache then
        changed, joined, left = self:RefreshRosterCache()
    end

    if changed and (joined > 0 or left > 0) then
        local parts = {}
        if joined > 0 then
            parts[#parts + 1] = "|cff80ff80+" .. joined .. " joined|r"
        end
        if left > 0 then
            parts[#parts + 1] = "|cffff8080-" .. left .. " left|r"
        end

        local details = table.concat(parts, ", ")
        self:Print("|cffffff00Group changed|r: " .. details .. ". Use the reset button if this is a new run.")
    end

    if self.WakeUITicker and not self.uiTickerRunning then
        self:WakeUITicker()
    end
end

function addon:PLAYER_REGEN_DISABLED()
    -- Fight timing is damage-driven (party-inclusive), not personal regen state.
end

function addon:PLAYER_REGEN_ENABLED()
    if self.OnLeaveCombat then
        self:OnLeaveCombat(GetTime())
    end
    if self.WakeUITicker and not self.uiTickerRunning then
        self:WakeUITicker()
    end
end

function addon:COMBAT_LOG_EVENT_UNFILTERED()
    if self.OnCombatLogEvent then
        self:OnCombatLogEvent()
    end
    if self.WakeUITicker and not self.uiTickerRunning then
        self:WakeUITicker()
    end
end

function addon:BOSS_KILL(arg1, arg2)
    local bossName = nil
    if type(arg2) == "string" then
        bossName = arg2
    elseif type(arg1) == "string" then
        bossName = arg1
    end

    if self.QueueBossKill then
        self:QueueBossKill(bossName)
    elseif self.RecordBossKill then
        self:RecordBossKill(bossName)
    end
    if self.WakeUITicker and not self.uiTickerRunning then
        self:WakeUITicker()
    end
end

function addon:CHAT_MSG_SYSTEM(msg)
    if type(msg) ~= "string" then
        return
    end

    local shouldPrompt = false
    if INSTANCE_RESET_SUCCESS and msg == INSTANCE_RESET_SUCCESS then
        shouldPrompt = true
    end

    if not shouldPrompt then
        local lowered = strlower(msg)
        if lowered:find("has been reset", 1, true) or lowered:find("instances have been reset", 1, true) then
            shouldPrompt = true
        end
    end

    if not shouldPrompt then
        return
    end

    local now = GetTime()
    local last = self.lastDungeonResetPrompt or 0
    if (now - last) < 5 then
        return
    end

    self.lastDungeonResetPrompt = now
    self:PromptReset("A dungeon reset was detected. Reset SimpleMeters now?")
end

addon.eventFrame:SetScript("OnEvent", function(_, event, ...)
    local handler = addon[event]
    if handler then
        handler(addon, ...)
    end
end)

addon.eventFrame:RegisterEvent("ADDON_LOADED")
