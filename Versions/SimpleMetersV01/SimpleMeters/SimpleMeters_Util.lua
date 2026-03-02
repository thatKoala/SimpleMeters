local addon = _G.SimpleMeters
if not addon then
    return
end

local floor = math.floor
local format = string.format

local function FormatOneDecimal(value, suffix)
    local roundedTenth = floor((value * 10) + 0.5)
    local whole = floor(roundedTenth / 10)
    local tenth = roundedTenth - (whole * 10)

    if tenth == 0 then
        return whole .. suffix
    end

    return whole .. "." .. tenth .. suffix
end

function addon:AbbrevNumber(value)
    value = tonumber(value) or 0

    local negative = value < 0
    if negative then
        value = -value
    end

    local text
    if value >= 1000000000 then
        text = FormatOneDecimal(value / 1000000000, "b")
    elseif value >= 1000000 then
        text = FormatOneDecimal(value / 1000000, "m")
    elseif value >= 1000 then
        text = FormatOneDecimal(value / 1000, "k")
    else
        text = tostring(floor(value + 0.5))
    end

    if negative then
        return "-" .. text
    end

    return text
end

function addon:GetClassColorTable(classFile)
    if not classFile then
        return nil
    end

    local custom = _G.CUSTOM_CLASS_COLORS
    if custom and custom[classFile] then
        return custom[classFile]
    end

    if RAID_CLASS_COLORS then
        return RAID_CLASS_COLORS[classFile]
    end

    return nil
end

function addon:GetClassColorRGB(classFile)
    local color = self:GetClassColorTable(classFile)
    if color then
        return color.r or color[1] or 1, color.g or color[2] or 1, color.b or color[3] or 1
    end

    return 0.82, 0.82, 0.82
end

function addon:GetClassColorHex(classFile, fallbackHex)
    local r, g, b = self:GetClassColorRGB(classFile)
    return format("%02x%02x%02x", floor((r * 255) + 0.5), floor((g * 255) + 0.5), floor((b * 255) + 0.5))
end

function addon:ColorizeNameByClass(name, classFile)
    name = name or (UNKNOWNOBJECT or "Unknown")
    local hex = self:GetClassColorHex(classFile, "d1d1d1")
    return "|cff" .. hex .. name .. "|r"
end
