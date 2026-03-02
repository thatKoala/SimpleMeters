local addon = _G.SimpleMeters
if not addon then
    return
end

local bitmod = bit
local band = bitmod.band
local bor = bitmod.bor
local pairs = pairs
local max = math.max
local sort = table.sort
local table_insert = table.insert
local table_remove = table.remove
local type = type
local tostring = tostring
local strsub = string.sub
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitClass = UnitClass
local IsInRaid = IsInRaid
local GetNumGroupMembers = GetNumGroupMembers
local GetNumSubgroupMembers = GetNumSubgroupMembers
local GetTime = GetTime
local date = date
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local GetSpellTexture = GetSpellTexture
local UNKNOWNOBJECT = UNKNOWNOBJECT or "Unknown"

local AFFILIATION_MASK = bor(
    COMBATLOG_OBJECT_AFFILIATION_MINE,
    COMBATLOG_OBJECT_AFFILIATION_PARTY,
    COMBATLOG_OBJECT_AFFILIATION_RAID
)
local PET_TYPE_MASK = bor(COMBATLOG_OBJECT_TYPE_PET or 0, COMBATLOG_OBJECT_TYPE_GUARDIAN or 0)

local FIGHT_END_DELAY = 3
local ENABLE_DEBUG_INJECT = false
local PERSIST_VERSION = 1
local PERSIST_SAVE_THROTTLE = 5

local ICON_MELEE = "Interface\\Icons\\INV_Sword_04"
local ICON_ENV = "Interface\\Icons\\Ability_Creature_Cursed_02"
local ICON_PET = "Interface\\Icons\\Ability_Hunter_BeastCall"
local ICON_UNKNOWN = "Interface\\Icons\\INV_Misc_QuestionMark"

local state = addon.state or {}
addon.state = state

state.actors = state.actors or {}
state.rosterClassByGUID = state.rosterClassByGUID or {}
state.rosterColorByGUID = state.rosterColorByGUID or {}
state.rosterNameByGUID = state.rosterNameByGUID or {}
state.petOwnerByGUID = state.petOwnerByGUID or {}
state.pendingGUIDLookupSet = state.pendingGUIDLookupSet or state.pendingGUIDLookup or {}
state.pendingGUIDLookupQueue = state.pendingGUIDLookupQueue or {}
state.pendingGUIDLookupHead = tonumber(state.pendingGUIDLookupHead) or 1
state.pendingGUIDLookupTail = tonumber(state.pendingGUIDLookupTail) or 0
state.pendingGUIDLookup = state.pendingGUIDLookupSet
state.guidLookupAttempted = state.guidLookupAttempted or {}
state.spellMeta = state.spellMeta or {}

state.bossHistory = state.bossHistory or {}
state.activeBossGUIDs = state.activeBossGUIDs or {}
state.pendingBossKills = state.pendingBossKills or {}
state.nextBossEntryId = state.nextBossEntryId or 1
state.selectedBossId = state.selectedBossId
state.lastBossKillName = state.lastBossKillName
state.lastBossKillTime = state.lastBossKillTime or 0
state.maxBossHistory = state.maxBossHistory or 24

state.groupMemberGUIDs = state.groupMemberGUIDs or {}
state.groupSnapshotReady = state.groupSnapshotReady == true

state.dirty = state.dirty ~= false
state.inFight = state.inFight == true
state.awaitingFightEnd = state.awaitingFightEnd == true
state.fightEndAt = state.fightEndAt or 0
state.lastRelevantTime = state.lastRelevantTime or 0
state.lastDamageTime = state.lastDamageTime or 0
state.fightId = state.fightId or 0
state.fightStartTime = state.fightStartTime or 0
state.fightActiveTime = state.fightActiveTime or 0
state.lastFightDuration = state.lastFightDuration or 1
state.totalActiveTime = state.totalActiveTime or 0
state.totalDamage = state.totalDamage or 0
state.uiDirty = state.uiDirty == true
state.nextTotalRefreshAt = state.nextTotalRefreshAt or 0
state.resetAt = state.resetAt or GetTime()
state.persistDirty = state.persistDirty == true
state.lastPersistAt = tonumber(state.lastPersistAt) or 0

if state.pendingGUIDLookupTail < state.pendingGUIDLookupHead then
    state.pendingGUIDLookupHead = 1
    state.pendingGUIDLookupTail = 0
end

if state.pendingGUIDLookupTail == 0 then
    for guid in pairs(state.pendingGUIDLookupSet) do
        state.pendingGUIDLookupTail = state.pendingGUIDLookupTail + 1
        state.pendingGUIDLookupQueue[state.pendingGUIDLookupTail] = guid
    end
    state.pendingGUIDLookupHead = 1
end

local function ClearTable(tbl)
    for key in pairs(tbl) do
        tbl[key] = nil
    end
end

local function QueueGUIDLookup(guid)
    if not guid or state.guidLookupAttempted[guid] or state.pendingGUIDLookupSet[guid] then
        return
    end

    -- Class fallback is only meaningful for player GUIDs.
    if strsub(guid, 1, 7) ~= "Player-" then
        state.guidLookupAttempted[guid] = true
        return
    end

    state.pendingGUIDLookupSet[guid] = true
    state.pendingGUIDLookup = state.pendingGUIDLookupSet
    state.pendingGUIDLookupTail = state.pendingGUIDLookupTail + 1
    state.pendingGUIDLookupQueue[state.pendingGUIDLookupTail] = guid
end

local function BuildGroupDiff(oldMap, newMap)
    local joined = 0
    local left = 0

    for guid in pairs(newMap) do
        if not oldMap[guid] then
            joined = joined + 1
        end
    end

    for guid in pairs(oldMap) do
        if not newMap[guid] then
            left = left + 1
        end
    end

    return (joined > 0 or left > 0), joined, left
end

local function EnsureSpellMeta(key, name, icon, spellId)
    local meta = state.spellMeta[key]
    if not meta then
        meta = {
            name = name,
            icon = icon,
            spellId = spellId,
        }
        state.spellMeta[key] = meta
    else
        if name and not meta.name then
            meta.name = name
        end
        if icon and not meta.icon then
            meta.icon = icon
        end
        if spellId and not meta.spellId then
            meta.spellId = spellId
        end
    end

    return meta
end

local function EnsureFightMaps(actor)
    if actor.lastSeenFightId ~= state.fightId then
        actor.fightDamage = 0
        actor.lastSeenFightId = state.fightId
        ClearTable(actor.spellFight)
        ClearTable(actor.petFight)
        ClearTable(actor.petSpellFight)
    end
end

local function GetOrCreateActor(guid, fallbackName)
    local actor = state.actors[guid]
    if actor then
        if fallbackName and (not actor.name or actor.name == UNKNOWNOBJECT) then
            actor.name = fallbackName
        end

        if not actor.petSpellTotal then
            actor.petSpellTotal = {}
        end
        if not actor.petSpellFight then
            actor.petSpellFight = {}
        end

        if not actor.classFile then
            local classFile = state.rosterClassByGUID[guid]
            if classFile then
                actor.classFile = classFile
                actor.color = state.rosterColorByGUID[guid]
            else
                QueueGUIDLookup(guid)
            end
        end

        return actor
    end

    local classFile = state.rosterClassByGUID[guid]
    actor = {
        name = state.rosterNameByGUID[guid] or fallbackName or UNKNOWNOBJECT,
        classFile = classFile,
        color = classFile and state.rosterColorByGUID[guid] or nil,
        totalDamage = 0,
        fightDamage = 0,
        lastSeenFightId = 0,
        spellTotal = {},
        spellFight = {},
        petTotal = {},
        petFight = {},
        petSpellTotal = {},
        petSpellFight = {},
    }
    state.actors[guid] = actor

    if not classFile then
        QueueGUIDLookup(guid)
    end

    return actor
end

local function AddSpellDamage(actor, spellKey, spellName, icon, spellId, amount)
    if not spellKey then
        return
    end

    local totalMap = actor.spellTotal
    totalMap[spellKey] = (totalMap[spellKey] or 0) + amount

    local fightMap = actor.spellFight
    fightMap[spellKey] = (fightMap[spellKey] or 0) + amount

    EnsureSpellMeta(spellKey, spellName, icon, spellId)
end

local function AddPetDamage(actor, petName, amount)
    if not petName then
        return
    end

    local totalMap = actor.petTotal
    totalMap[petName] = (totalMap[petName] or 0) + amount

    local fightMap = actor.petFight
    fightMap[petName] = (fightMap[petName] or 0) + amount
end

local function AddPetSpellDamage(actor, spellKey, petName, amount)
    if not petName or not spellKey then
        return
    end

    local totalBySpell = actor.petSpellTotal[spellKey]
    if not totalBySpell then
        totalBySpell = {}
        actor.petSpellTotal[spellKey] = totalBySpell
    end
    totalBySpell[petName] = (totalBySpell[petName] or 0) + amount

    local fightBySpell = actor.petSpellFight[spellKey]
    if not fightBySpell then
        fightBySpell = {}
        actor.petSpellFight[spellKey] = fightBySpell
    end
    fightBySpell[petName] = (fightBySpell[petName] or 0) + amount
end

local function EffectiveDamage(amount, overkill)
    amount = tonumber(amount) or 0
    overkill = tonumber(overkill) or 0
    if overkill < 0 then
        overkill = 0
    end
    amount = amount - overkill
    if amount < 0 then
        return 0
    end
    return amount
end

local function AddDamage(actor, amount, spellKey, spellName, spellIcon, spellId, petName)
    if not amount or amount <= 0 then
        return
    end

    actor.totalDamage = actor.totalDamage + amount
    state.totalDamage = (state.totalDamage or 0) + amount

    EnsureFightMaps(actor)
    actor.fightDamage = actor.fightDamage + amount

    AddSpellDamage(actor, spellKey, spellName, spellIcon, spellId, amount)
    AddPetDamage(actor, petName, amount)
    AddPetSpellDamage(actor, spellKey, petName, amount)

    state.persistDirty = true
    state.dirty = true
end

-- SWING_DAMAGE payload offsets (after destRaidFlags):
--  a1=amount, a2=overkill, a3=school, a4=resisted, a5=blocked
local function HandleSWING_DAMAGE(actor, _, _, _, petName, a1, a2)
    local amount = EffectiveDamage(a1, a2)
    AddDamage(actor, amount, 0, "Melee", ICON_MELEE, nil, petName)
end

-- SPELL_DAMAGE / SPELL_PERIODIC_DAMAGE / RANGE_DAMAGE payload offsets:
--  a1=spellId, a2=spellName, a3=spellSchool, a4=amount, a5=overkill
local function HandleSPELL_DAMAGE(actor, _, _, _, petName, a1, a2, _, a4, a5)
    local amount = EffectiveDamage(a4, a5)
    AddDamage(actor, amount, a1, a2, nil, a1, petName)
end

local ENV_KEY_BY_TYPE = {}
local ENV_NAME_BY_TYPE = {}

-- ENVIRONMENTAL_DAMAGE payload offsets:
--  a1=environmentalType, a2=amount, a3=overkill, a4=school, a5=resisted
local function HandleENVIRONMENTAL_DAMAGE(actor, _, _, _, petName, a1, a2, a3)
    local envType = a1 or "Unknown"
    local envName = ENV_NAME_BY_TYPE[envType]
    if not envName then
        envName = tostring(envType)
        ENV_NAME_BY_TYPE[envType] = envName
    end
    local key = ENV_KEY_BY_TYPE[envType]
    if not key then
        key = "ENV:" .. envName
        ENV_KEY_BY_TYPE[envType] = key
    end
    local amount = EffectiveDamage(a2, a3)
    AddDamage(actor, amount, key, envName, ICON_ENV, nil, petName)
end

local SUBEVENT_DISPATCH = {
    SWING_DAMAGE = HandleSWING_DAMAGE,
    SPELL_DAMAGE = HandleSPELL_DAMAGE,
    SPELL_PERIODIC_DAMAGE = HandleSPELL_DAMAGE,
    RANGE_DAMAGE = HandleSPELL_DAMAGE,
    ENVIRONMENTAL_DAMAGE = HandleENVIRONMENTAL_DAMAGE,
}

local DAMAGE_SUBEVENTS = {
    SWING_DAMAGE = true,
    SPELL_DAMAGE = true,
    SPELL_PERIODIC_DAMAGE = true,
    RANGE_DAMAGE = true,
    ENVIRONMENTAL_DAMAGE = true,
}

local function UpdateUnitCache(unit)
    if not UnitExists(unit) then
        return nil
    end

    local guid = UnitGUID(unit)
    if not guid then
        return nil
    end

    local name = UnitName(unit)
    if name then
        state.rosterNameByGUID[guid] = name
    end

    local _, classFile = UnitClass(unit)
    if classFile then
        state.rosterClassByGUID[guid] = classFile
        state.rosterColorByGUID[guid] = addon:GetClassColorTable(classFile)
    end

    local actor = state.actors[guid]
    if actor then
        if name then
            actor.name = name
        end
        if classFile then
            actor.classFile = classFile
            actor.color = state.rosterColorByGUID[guid]
            state.guidLookupAttempted[guid] = nil
        end
    end

    return guid
end

local function MapPetOwner(petUnit, ownerUnit)
    if not UnitExists(petUnit) then
        return
    end

    local petGUID = UnitGUID(petUnit)
    local ownerGUID = UnitGUID(ownerUnit)
    if petGUID and ownerGUID then
        state.petOwnerByGUID[petGUID] = ownerGUID
    end
end

local function CompareSnapshotActors(a, b)
    if a.damage == b.damage then
        return (a.name or UNKNOWNOBJECT) < (b.name or UNKNOWNOBJECT)
    end
    return a.damage > b.damage
end

local function CopyDamageMap(src)
    local copy = {}
    for key, value in pairs(src or {}) do
        copy[key] = value
    end
    return copy
end

local function ClearNestedMap(map)
    for key, value in pairs(map) do
        if type(value) == "table" then
            for subKey in pairs(value) do
                value[subKey] = nil
            end
        end
        map[key] = nil
    end
end

local function CopyNestedDamageMap(src)
    local copy = {}
    for key, value in pairs(src or {}) do
        local nested = {}
        for subKey, amount in pairs(value or {}) do
            nested[subKey] = amount
        end
        copy[key] = nested
    end
    return copy
end

local function GetFightEndTimestamp(now)
    now = now or GetTime()

    local startTime = state.fightStartTime or 0
    local endTime

    if state.inFight then
        endTime = state.lastDamageTime
    else
        endTime = state.lastDamageTime
        if not endTime or endTime <= 0 then
            endTime = state.lastRelevantTime
        end
    end

    if not endTime or endTime <= 0 then
        endTime = now
    end
    if startTime > 0 and endTime < startTime then
        endTime = now
    end

    return endTime
end

local function BuildBossSnapshot(now)
    local duration
    if state.inFight and state.fightStartTime > 0 then
        duration = GetFightEndTimestamp(now) - state.fightStartTime
    else
        duration = state.lastFightDuration or 1
    end
    duration = max(1, duration)

    local actors = {}
    local totalDamage = 0

    for guid, actor in pairs(state.actors) do
        if actor.lastSeenFightId == state.fightId and (actor.fightDamage or 0) > 0 then
            local damage = actor.fightDamage
            totalDamage = totalDamage + damage
            actors[#actors + 1] = {
                guid = guid,
                name = actor.name or UNKNOWNOBJECT,
                classFile = actor.classFile,
                damage = damage,
                spells = CopyDamageMap(actor.spellFight),
                petSpells = CopyNestedDamageMap(actor.petSpellFight),
                pets = CopyDamageMap(actor.petFight),
            }
        end
    end

    if #actors > 1 then
        sort(actors, CompareSnapshotActors)
    end

    return actors, totalDamage, duration
end

local function RecordBossKillNow(bossName, bossGUID, now)
    if bossGUID and state.activeBossGUIDs[bossGUID] then
        bossName = state.activeBossGUIDs[bossGUID]
        state.activeBossGUIDs[bossGUID] = nil
    end

    bossName = bossName or UNKNOWNOBJECT
    now = now or GetTime()

    if state.lastBossKillName == bossName and (now - state.lastBossKillTime) < 2 then
        return
    end

    state.lastBossKillName = bossName
    state.lastBossKillTime = now

    local actors, totalDamage, duration = BuildBossSnapshot(now)

    local entry = {
        id = state.nextBossEntryId,
        name = bossName,
        fightId = state.fightId,
        totalDamage = totalDamage,
        duration = duration,
        time = date("%H:%M"),
        actors = actors,
    }
    state.nextBossEntryId = state.nextBossEntryId + 1

    table_insert(state.bossHistory, 1, entry)

    if #state.bossHistory > state.maxBossHistory then
        table_remove(state.bossHistory)
    end

    if not state.selectedBossId then
        state.selectedBossId = entry.id
    end

    state.persistDirty = true
    state.dirty = true
end

function addon:InitializeCombat()
    EnsureSpellMeta(0, "Melee", ICON_MELEE, nil)
    state.resetAt = state.resetAt or GetTime()
    state.dirty = true
end

function addon:ClearPersistedCombat()
    if self.db then
        self.db.combatPersist = nil
    end
    state.persistDirty = false
    state.lastPersistAt = 0
end

function addon:SavePersistedCombat(force)
    if not self.db then
        return
    end

    local now = GetTime()
    if not force then
        if not state.persistDirty then
            return
        end
        if state.lastPersistAt > 0 and (now - state.lastPersistAt) < PERSIST_SAVE_THROTTLE then
            return
        end
    end

    local persistedActiveTime = state.totalActiveTime or 0
    if state.inFight and state.fightStartTime > 0 then
        local activeNow = GetFightEndTimestamp(now) - state.fightStartTime
        if activeNow > 0 then
            persistedActiveTime = persistedActiveTime + activeNow
        end
    end

    local persist = {
        version = PERSIST_VERSION,
        resetAt = state.resetAt or GetTime(),
        totalActiveTime = persistedActiveTime,
        totalDamage = state.totalDamage or 0,
        spellMeta = {},
        actors = {},
        bossHistory = {},
        nextBossEntryId = state.nextBossEntryId or 1,
        selectedBossId = state.selectedBossId,
    }

    for key, meta in pairs(state.spellMeta or {}) do
        if type(meta) == "table" then
            persist.spellMeta[key] = {
                name = meta.name,
                icon = meta.icon,
                spellId = meta.spellId,
            }
        end
    end

    for guid, actor in pairs(state.actors or {}) do
        local totalDamage = tonumber(actor.totalDamage) or 0
        if totalDamage > 0 then
            persist.actors[guid] = {
                name = actor.name,
                classFile = actor.classFile,
                totalDamage = totalDamage,
                spellTotal = CopyDamageMap(actor.spellTotal),
                petTotal = CopyDamageMap(actor.petTotal),
                petSpellTotal = CopyNestedDamageMap(actor.petSpellTotal),
            }
        end
    end

    for i = 1, #(state.bossHistory or {}) do
        local entry = state.bossHistory[i]
        if type(entry) == "table" then
            local savedEntry = {
                id = entry.id,
                name = entry.name,
                fightId = entry.fightId,
                totalDamage = entry.totalDamage,
                duration = entry.duration,
                time = entry.time,
                actors = {},
            }

            for j = 1, #(entry.actors or {}) do
                local actor = entry.actors[j]
                if type(actor) == "table" then
                    savedEntry.actors[#savedEntry.actors + 1] = {
                        guid = actor.guid,
                        name = actor.name,
                        classFile = actor.classFile,
                        damage = actor.damage,
                        spells = CopyDamageMap(actor.spells),
                        petSpells = CopyNestedDamageMap(actor.petSpells),
                        pets = CopyDamageMap(actor.pets),
                    }
                end
            end

            persist.bossHistory[#persist.bossHistory + 1] = savedEntry
        end
    end

    self.db.combatPersist = persist
    state.persistDirty = false
    state.lastPersistAt = now
end

function addon:RestorePersistedCombat()
    if not self.db then
        return
    end

    local persist = self.db.combatPersist
    if type(persist) ~= "table" then
        return
    end

    local persistVersion = tonumber(persist.version) or 0
    if persistVersion ~= PERSIST_VERSION then
        -- Drop incompatible snapshots to avoid stale/corrupt restore state.
        self.db.combatPersist = nil
        return
    end

    ClearTable(state.actors)
    ClearTable(state.spellMeta)
    ClearTable(state.bossHistory)
    ClearTable(state.activeBossGUIDs)
    ClearTable(state.pendingBossKills)
    ClearTable(state.pendingGUIDLookupSet)
    ClearTable(state.pendingGUIDLookupQueue)
    state.pendingGUIDLookupHead = 1
    state.pendingGUIDLookupTail = 0
    state.pendingGUIDLookup = state.pendingGUIDLookupSet
    ClearTable(state.guidLookupAttempted)

    state.inFight = false
    state.awaitingFightEnd = false
    state.fightEndAt = 0
    state.lastRelevantTime = 0
    state.lastDamageTime = 0
    state.fightStartTime = 0
    state.fightActiveTime = 0
    state.lastFightDuration = 1

    state.resetAt = tonumber(persist.resetAt) or GetTime()
    state.totalActiveTime = max(0, tonumber(persist.totalActiveTime) or 0)
    state.totalDamage = max(0, tonumber(persist.totalDamage) or 0)
    state.nextBossEntryId = max(1, tonumber(persist.nextBossEntryId) or 1)
    state.selectedBossId = tonumber(persist.selectedBossId)
    state.nextTotalRefreshAt = 0

    for key, meta in pairs(persist.spellMeta or {}) do
        if type(meta) == "table" then
            state.spellMeta[key] = {
                name = meta.name,
                icon = meta.icon,
                spellId = meta.spellId,
            }
        end
    end
    EnsureSpellMeta(0, "Melee", ICON_MELEE, nil)

    local recomputedTotal = 0
    for guid, savedActor in pairs(persist.actors or {}) do
        if type(savedActor) == "table" then
            local classFile = savedActor.classFile
            local actor = {
                name = savedActor.name or state.rosterNameByGUID[guid] or UNKNOWNOBJECT,
                classFile = classFile,
                color = classFile and addon:GetClassColorTable(classFile) or nil,
                totalDamage = max(0, tonumber(savedActor.totalDamage) or 0),
                fightDamage = 0,
                lastSeenFightId = state.fightId,
                spellTotal = CopyDamageMap(savedActor.spellTotal),
                spellFight = {},
                petTotal = CopyDamageMap(savedActor.petTotal),
                petFight = {},
                petSpellTotal = CopyNestedDamageMap(savedActor.petSpellTotal),
                petSpellFight = {},
            }
            recomputedTotal = recomputedTotal + actor.totalDamage
            state.actors[guid] = actor
        end
    end

    if state.totalDamage <= 0 and recomputedTotal > 0 then
        state.totalDamage = recomputedTotal
    end

    for i = 1, #(persist.bossHistory or {}) do
        local entry = persist.bossHistory[i]
        if type(entry) == "table" then
            local restored = {
                id = tonumber(entry.id) or i,
                name = entry.name or UNKNOWNOBJECT,
                fightId = tonumber(entry.fightId) or 0,
                totalDamage = max(0, tonumber(entry.totalDamage) or 0),
                duration = max(1, tonumber(entry.duration) or 1),
                time = entry.time,
                actors = {},
            }

            for j = 1, #(entry.actors or {}) do
                local actor = entry.actors[j]
                if type(actor) == "table" then
                    restored.actors[#restored.actors + 1] = {
                        guid = actor.guid,
                        name = actor.name or UNKNOWNOBJECT,
                        classFile = actor.classFile,
                        damage = max(0, tonumber(actor.damage) or 0),
                        spells = CopyDamageMap(actor.spells),
                        petSpells = CopyNestedDamageMap(actor.petSpells),
                        pets = CopyDamageMap(actor.pets),
                    }
                end
            end

            state.bossHistory[#state.bossHistory + 1] = restored
            if restored.id >= state.nextBossEntryId then
                state.nextBossEntryId = restored.id + 1
            end
        end
    end

    if not state.selectedBossId and #state.bossHistory > 0 then
        state.selectedBossId = state.bossHistory[1].id
    end

    state.persistDirty = false
    state.lastPersistAt = 0
    state.uiDirty = true
    state.dirty = true
end

function addon:RefreshRosterCache()
    local newGroupMembers = {}

    ClearTable(state.rosterClassByGUID)
    ClearTable(state.rosterColorByGUID)
    ClearTable(state.rosterNameByGUID)
    ClearTable(state.petOwnerByGUID)

    local guid = UpdateUnitCache("player")
    if guid then
        newGroupMembers[guid] = true
    end
    MapPetOwner("pet", "player")

    if IsInRaid() then
        local count = GetNumGroupMembers()
        for i = 1, count do
            local unit = "raid" .. i
            guid = UpdateUnitCache(unit)
            if guid then
                newGroupMembers[guid] = true
            end
            MapPetOwner("raidpet" .. i, unit)
        end
    else
        local count = GetNumSubgroupMembers()
        for i = 1, count do
            local unit = "party" .. i
            guid = UpdateUnitCache(unit)
            if guid then
                newGroupMembers[guid] = true
            end
            MapPetOwner("partypet" .. i, unit)
        end
    end

    local changed, joined, left = false, 0, 0
    if state.groupSnapshotReady then
        changed, joined, left = BuildGroupDiff(state.groupMemberGUIDs, newGroupMembers)
    end

    state.groupMemberGUIDs = newGroupMembers
    state.groupSnapshotReady = true
    state.dirty = true
    return changed, joined, left
end

function addon:StartFight(now)
    now = now or GetTime()

    if state.inFight then
        state.lastRelevantTime = now
        state.awaitingFightEnd = false
        state.fightEndAt = 0
        return
    end

    state.inFight = true
    state.awaitingFightEnd = false
    state.fightEndAt = 0
    state.lastRelevantTime = now
    state.lastDamageTime = now
    state.fightStartTime = now
    state.fightActiveTime = 0
    state.lastFightDuration = 1
    state.fightId = state.fightId + 1
    state.dirty = true
end

local function FinalizeFight(now)
    if not state.inFight then
        return false
    end

    now = now or GetTime()

    local startTime = state.fightStartTime or 0
    local endTime = GetFightEndTimestamp(now)
    local duration = endTime - startTime
    if duration < 0 then
        duration = 0
    end

    state.fightActiveTime = duration
    state.totalActiveTime = (state.totalActiveTime or 0) + duration
    state.lastFightDuration = max(1, duration)

    state.inFight = false
    state.awaitingFightEnd = false
    state.fightEndAt = 0
    state.nextTotalRefreshAt = 0
    state.uiDirty = true
    state.dirty = true

    -- Lightweight checkpoint after each finalized fight; avoids progress loss on crash.
    if addon and addon.SavePersistedCombat and addon.db then
        addon:SavePersistedCombat(false)
    end
    return true
end

function addon:OnLeaveCombat(now)
    if not state.inFight then
        return
    end

    now = now or GetTime()
    state.awaitingFightEnd = true
    state.fightEndAt = now + FIGHT_END_DELAY
end

function addon:UpdateFightTimeout(now)
    if not state.inFight then
        return
    end

    now = now or GetTime()
    local lastDamageTime = state.lastDamageTime or 0
    if lastDamageTime <= 0 then
        return
    end

    local elapsed = now - lastDamageTime
    if elapsed >= FIGHT_END_DELAY then
        FinalizeFight(lastDamageTime)
    else
        state.awaitingFightEnd = true
        state.fightEndAt = lastDamageTime + FIGHT_END_DELAY
    end
end

function addon:ScanBossUnits()
    ClearTable(state.activeBossGUIDs)

    for i = 1, 5 do
        local unit = "boss" .. i
        if UnitExists(unit) then
            local guid = UnitGUID(unit)
            if guid then
                state.activeBossGUIDs[guid] = UnitName(unit) or UNKNOWNOBJECT
            end
        end
    end
end

function addon:QueueBossKill(bossName, bossGUID, eventTime)
    table_insert(state.pendingBossKills, {
        name = bossName,
        guid = bossGUID,
        time = eventTime or GetTime(),
    })
end

function addon:ProcessPendingBossKills(maxPerTick)
    maxPerTick = maxPerTick or 2

    local processed = 0
    while #state.pendingBossKills > 0 and processed < maxPerTick do
        local pending = table_remove(state.pendingBossKills, 1)
        RecordBossKillNow(pending.name, pending.guid, pending.time)
        processed = processed + 1
    end
end

function addon:OnCombatLogEvent()
    local _, subevent, _, srcGUID, srcName, srcFlags, _, destGUID, destName, _, _, a1, a2, a3, a4, a5 = CombatLogGetCurrentEventInfo()

    if subevent == "UNIT_DIED" or subevent == "UNIT_DESTROYED" then
        if destGUID and state.activeBossGUIDs[destGUID] then
            self:QueueBossKill(destName or state.activeBossGUIDs[destGUID], destGUID, GetTime())
        end
        return
    end

    if subevent == "SPELL_SUMMON" then
        if srcGUID and srcFlags and band(srcFlags, AFFILIATION_MASK) ~= 0 and destGUID then
            state.petOwnerByGUID[destGUID] = srcGUID
        end
        return
    end

    if not srcGUID or not srcFlags then
        return
    end

    -- Early affiliation filter before any event-specific parsing.
    if band(srcFlags, AFFILIATION_MASK) == 0 then
        return
    end

    local handler = SUBEVENT_DISPATCH[subevent]
    if not handler then
        return
    end

    local now = GetTime()
    local isDamage = DAMAGE_SUBEVENTS[subevent] == true

    local actorGUID = srcGUID
    local petName = nil

    if addon.db and addon.db.mergePets ~= false then
        local ownerGUID = state.petOwnerByGUID[srcGUID]
        if ownerGUID then
            actorGUID = ownerGUID
            petName = srcName
        elseif band(srcFlags, PET_TYPE_MASK) ~= 0 then
            -- Skip orphan pet/guardian events until owner mapping is known.
            return
        end
    end

    if isDamage and not state.inFight then
        self:StartFight(now)
    end

    if state.inFight and isDamage then
        state.lastRelevantTime = now
        state.lastDamageTime = now
        state.awaitingFightEnd = false
        state.fightEndAt = 0
    end

    local actorName = state.rosterNameByGUID[actorGUID] or srcName
    local actor = GetOrCreateActor(actorGUID, actorName)
    handler(actor, srcGUID, srcName, srcFlags, petName, a1, a2, a3, a4, a5)
end

function addon:ProcessPendingGUIDLookups(maxPerTick)
    maxPerTick = maxPerTick or 8

    local queue = state.pendingGUIDLookupQueue
    local head = state.pendingGUIDLookupHead or 1
    local tail = state.pendingGUIDLookupTail or 0
    local processed = 0
    while processed < maxPerTick and head <= tail do
        local guid = queue[head]
        queue[head] = nil
        head = head + 1

        if guid then
            state.pendingGUIDLookupSet[guid] = nil
            state.pendingGUIDLookup = state.pendingGUIDLookupSet
            state.guidLookupAttempted[guid] = true

            local _, classFile = GetPlayerInfoByGUID(guid)
            if classFile then
                state.rosterClassByGUID[guid] = classFile
                local color = addon:GetClassColorTable(classFile)
                state.rosterColorByGUID[guid] = color
                state.guidLookupAttempted[guid] = nil

                local actor = state.actors[guid]
                if actor then
                    actor.classFile = classFile
                    actor.color = color
                    state.dirty = true
                end
            end

            processed = processed + 1
        end
    end

    if head > tail then
        state.pendingGUIDLookupHead = 1
        state.pendingGUIDLookupTail = 0
    else
        state.pendingGUIDLookupHead = head
        state.pendingGUIDLookupTail = tail
    end
end

function addon:GetActorsTable()
    return state.actors
end

function addon:GetBossHistory()
    return state.bossHistory
end

function addon:GetBossEntryById(entryId)
    if not entryId then
        return nil
    end

    for i = 1, #state.bossHistory do
        local entry = state.bossHistory[i]
        if entry.id == entryId then
            return entry
        end
    end

    return nil
end

function addon:GetSelectedBossId()
    return state.selectedBossId
end

function addon:SelectBossById(entryId)
    if not entryId then
        state.selectedBossId = nil
        state.dirty = true
        return
    end

    if self:GetBossEntryById(entryId) then
        state.selectedBossId = entryId
        state.dirty = true
    end
end

function addon:GetFightDuration(now)
    now = now or GetTime()
    if state.inFight and state.fightStartTime > 0 then
        return max(1, GetFightEndTimestamp(now) - state.fightStartTime)
    end
    return max(1, state.lastFightDuration or 1)
end

function addon:GetTotalDuration(now)
    now = now or GetTime()
    local totalDuration = state.totalActiveTime or 0
    if state.inFight and state.fightStartTime > 0 then
        totalDuration = totalDuration + max(0, GetFightEndTimestamp(now) - state.fightStartTime)
    end
    return max(1, totalDuration)
end

local function CompareBreakdownEntries(a, b)
    if a.amount == b.amount then
        return a.name < b.name
    end
    return a.amount > b.amount
end

function addon:BuildSpellBreakdown(damageMap, petSpellMap)
    local entries = {}

    for key, amount in pairs(damageMap or {}) do
        if amount and amount > 0 then
            local meta = state.spellMeta[key]
            local name = meta and meta.name or tostring(key)
            local icon = meta and meta.icon

            if (not icon) and meta and meta.spellId and GetSpellTexture then
                icon = GetSpellTexture(meta.spellId)
                meta.icon = icon
            end

            if key == 0 then
                icon = icon or ICON_MELEE
                name = "Melee"
            end

            local remaining = amount
            local petByName = petSpellMap and petSpellMap[key]
            if petByName then
                for petName, petAmount in pairs(petByName) do
                    if petAmount and petAmount > 0 then
                        entries[#entries + 1] = {
                            key = key,
                            name = name,
                            icon = icon or ICON_UNKNOWN,
                            amount = petAmount,
                            petName = petName,
                        }
                        remaining = remaining - petAmount
                    end
                end
            end

            if remaining > 0 then
                entries[#entries + 1] = {
                    key = key,
                    name = name,
                    icon = icon or ICON_UNKNOWN,
                    amount = remaining,
                }
            end
        end
    end

    if #entries > 1 then
        sort(entries, CompareBreakdownEntries)
    end

    return entries
end

function addon:BuildPetBreakdown(damageMap)
    local entries = {}

    for name, amount in pairs(damageMap or {}) do
        if amount and amount > 0 then
            entries[#entries + 1] = {
                name = name,
                icon = ICON_PET,
                amount = amount,
            }
        end
    end

    if #entries > 1 then
        sort(entries, CompareBreakdownEntries)
    end

    return entries
end

function addon:GetActorTooltipData(actor, mode, now)
    if not actor then
        return nil
    end

    local damage
    local spellMap
    local petSpellMap
    local petMap
    local duration

    if mode == "fight" then
        if actor.lastSeenFightId ~= state.fightId then
            return nil
        end
        damage = actor.fightDamage or 0
        spellMap = actor.spellFight
        petSpellMap = actor.petSpellFight
        petMap = actor.petFight
        duration = self:GetFightDuration(now)
    else
        damage = actor.totalDamage or 0
        spellMap = actor.spellTotal
        petSpellMap = actor.petSpellTotal
        petMap = actor.petTotal
        duration = self:GetTotalDuration(now)
    end

    if damage <= 0 then
        return nil
    end

    return {
        damage = damage,
        duration = max(1, duration),
        spells = self:BuildSpellBreakdown(spellMap, petSpellMap),
        pets = self:BuildPetBreakdown(petMap),
    }
end

function addon:GetSnapshotTooltipData(snapshotActor, duration)
    if not snapshotActor then
        return nil
    end

    local damage = snapshotActor.damage or 0
    if damage <= 0 then
        return nil
    end

    return {
        damage = damage,
        duration = max(1, duration or 1),
        spells = self:BuildSpellBreakdown(snapshotActor.spells, snapshotActor.petSpells),
        pets = self:BuildPetBreakdown(snapshotActor.pets),
    }
end

function addon:GetActorValue(actor, mode)
    if mode == "fight" then
        if actor.lastSeenFightId ~= state.fightId then
            return 0
        end
        return actor.fightDamage or 0
    end

    return actor.totalDamage or 0
end

function addon:ResetAll()
    state.fightId = state.fightId + 1
    state.inFight = false
    state.awaitingFightEnd = false
    state.fightEndAt = 0
    state.lastRelevantTime = 0
    state.lastDamageTime = 0
    state.fightStartTime = 0
    state.fightActiveTime = 0
    state.lastFightDuration = 1
    state.totalActiveTime = 0
    state.totalDamage = 0
    state.nextTotalRefreshAt = 0
    state.resetAt = GetTime()
    state.persistDirty = true

    for _, actor in pairs(state.actors) do
        actor.totalDamage = 0
        actor.fightDamage = 0
        actor.lastSeenFightId = state.fightId
        ClearTable(actor.spellTotal)
        ClearTable(actor.spellFight)
        ClearTable(actor.petTotal)
        ClearTable(actor.petFight)
        ClearNestedMap(actor.petSpellTotal)
        ClearNestedMap(actor.petSpellFight)
    end

    ClearTable(state.bossHistory)
    ClearTable(state.activeBossGUIDs)
    ClearTable(state.pendingBossKills)
    ClearTable(state.pendingGUIDLookupSet)
    ClearTable(state.pendingGUIDLookupQueue)
    state.pendingGUIDLookupHead = 1
    state.pendingGUIDLookupTail = 0
    state.pendingGUIDLookup = state.pendingGUIDLookupSet
    state.selectedBossId = nil
    state.uiDirty = true
    state.dirty = true

    self:ClearPersistedCombat()
end

function addon:DebugInjectFakeData()
    if not ENABLE_DEBUG_INJECT then
        return false
    end

    state.fightId = state.fightId + 1
    state.fightStartTime = GetTime() - 90
    state.lastDamageTime = GetTime()
    state.totalActiveTime = (state.totalActiveTime or 0) + 90
    state.lastFightDuration = 90

    local a1 = GetOrCreateActor("Player-0-00000001", "Tankadin")
    a1.classFile = "PALADIN"
    a1.color = addon:GetClassColorTable("PALADIN")
    AddDamage(a1, 220450, 35395, "Crusader Strike", nil, 35395, nil)
    AddDamage(a1, 48220, 0, "Melee", ICON_MELEE, nil, nil)

    local a2 = GetOrCreateActor("Player-0-00000002", "Pyromage")
    a2.classFile = "MAGE"
    a2.color = addon:GetClassColorTable("MAGE")
    AddDamage(a2, 198730, 42873, "Fireball", nil, 42873, nil)
    AddDamage(a2, 50190, 42891, "Pyroblast", nil, 42891, nil)

    local a3 = GetOrCreateActor("Player-0-00000003", "Treeclaws")
    a3.classFile = "DRUID"
    a3.color = addon:GetClassColorTable("DRUID")
    AddDamage(a3, 74520, 33745, "Lacerate", nil, 33745, nil)

    RecordBossKillNow("Debug Boss", nil, GetTime())

    state.dirty = true
    return true
end
