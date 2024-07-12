--
-- Battery % consumption calculated sensor 'Bat%'
--
-- Author: Rob Gayle (bob00@rogers.com)
-- Date: 2024
-- ver: 0.1.0
--

local nextCalc = 0
local packCapacity = 0
local sensorUsedId = 0
local sensorGSpdId = 0
local sensorTRSSId = 0

local function init()
    packCapacity = model.getGlobalVariable(4, 0) * 100

    local fld = getFieldInfo("Used")
    sensorUsedId = fld and fld.id or 0

    fld = getFieldInfo("GSpd")
    sensorGSpdId = fld and fld.id or 0

    fld = getFieldInfo("TRSS")
    sensorTRSSId = fld and fld.id or 0
end

local function safeInit()
    local ret = pcall(init)
end

local function calcBatPcnt(connected)
    local pcnt = 0
    if connected and packCapacity ~= 0 and sensorUsedId ~= 0 then
        -- calc Bat%
        local used = getValue(sensorUsedId)
        if used < packCapacity then
            pcnt = (packCapacity - used) * 100 / packCapacity
        end
    end
    setTelemetryValue(0xFE18, 0, 0, pcnt, UNIT_PERCENT, 0, "Bat%")
end

local function calcKph(connected)
    local kph = 0
    if connected and sensorGSpdId ~= 0 then
        -- calc knts -> kph
        kph = getValue(sensorGSpdId) * 1.852
    end
    setTelemetryValue(0xFE19, 0, 0, kph, UNIT_KMH, 0, "GKph")
end

local function calcSensors()
    -- bail if not time yet
    local time = getTime()
    if time < nextCalc then
        return
    end
    nextCalc = time + 100

    -- connected ?
    local connected = getValue(sensorTRSSId) ~= 0

    -- calc sensors
    calcBatPcnt(connected)
    calcKph(connected)
end

local function safeCalc()
    local ret = pcall(calcSensors)
end

return { init=safeInit, run=safeCalc }