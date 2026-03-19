--[[
#########################################################################
#                                                                       #
# Telemetry Widget script for FrSky Horus/RadioMaster TX16s             #
# Copyright "Offer Shmuely"                                             #
#                                                                       #
# License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
#                                                                       #
# This program is free software; you can redistribute it and/or modify  #
# it under the terms of the GNU General Public License version 2 as     #
# published by the Free Software Foundation.                            #
#                                                                       #
# This program is distributed in the hope that it will be useful        #
# but WITHOUT ANY WARRANTY; without even the implied warranty of        #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
# GNU General Public License for more details.                          #
#                                                                       #
#########################################################################


-- This widget display a graphical representation of a Lipo/Li-ion (not other types) battery level,
-- it will automatically detect the cell amount of the battery.
-- it will take a lipo/li-ion voltage that received as a single value (as opposed to multi cell values send while using FLVSS liPo Voltage Sensor)
-- common sources are:
--   * Transmitter Battery
--   * FrSky VFAS
--   * A1/A2 analog voltage
--   * mini quad flight controller
--   * radio-master 168
--   * OMP m2 heli

]]

-- Based on...
-- Widget to display the levels of Lipo battery from single analog source
-- Author : Offer Shmuely
-- Date: 2021-2023
-- ver: 0.5

-- Voice alerts added, kill the blink, brighter battery colors + line
-- Added consumption "power bar"
-- friendlier UI, new name (vPowerBar), specify cell count option, reserve, haptic critical
-- Author: Rob Gayle (bob00@rogers.com)
-- Date: 2026
-- ver: 0.9.0.03192

local app_name = "ePowerbar"

local AUDIO_PATH = "/SOUNDS/en/"

local ALERTLEVEL_NONE       = 0
local ALERTLEVEL_LOW        = 1
local ALERTLEVEL_CRITICAL   = 2

local BAR_COLOR_OK          = lcd.RGB(0x00, 0xff, 0x00)
local BAR_COLOR_WARN        = lcd.RGB(0xf8, 0xc0, 0x00) -- lcd.RGB(0xff, 0xff, 0)
local BAR_COLOR_LOW         = lcd.RGB(0xff, 0xff, 0x00)
local BAR_COLOR_CRITICAL    = lcd.RGB(0xff, 0x00, 0x00)
local BAR_COLOR_CHECK       = lcd.RGB(0xb8, 0xb8, 0xb8)
local BAR_COLOR_BACKGROUND  = lcd.RGB(0xc8, 0xc8, 0xc8)
local BAR_COLOR_LINE        = lcd.RGB(160, 160, 160)

local STARTUP_DELAY = 400
local VOLTTIMER_DISABLED = -1

local defaultVoltSensor = "Vbat"
local defaultPcntSensor = "Bat%"
local defaultMahSensor = "Capa"
local defaultCellSensor = "Cel#"

local _options = {
    { "VoltSensor"            , SOURCE, getSourceIndex(defaultVoltSensor) },
    { "mAhSensor"             , SOURCE, getSourceIndex(defaultMahSensor) },
    { "FuelSensor"            , SOURCE, getSourceIndex(defaultPcntSensor) },
    { "LipoMah"               , VALUE, 0, 0, 24000 },
    { "CellSensor"            , SOURCE, getSourceIndex(defaultCellSensor) },
    { "Cells"                 , VALUE, 0, 0, 16 },      -- cell detection time (or interval if calc perceentage)
    { "Reserve"               , VALUE, 20, 0, 40 },   -- reserve
    { "Mute"                  , BOOL, 0 },
    { "Vibrate"               , BOOL, 1 },
    { "VoltAlerts"            , SOURCE, 0 },
    { "CellFull"              , VALUE, 412, 0, 480 },
    { "CellLow"               , VALUE, 345, 0, 440 },
    { "CellCritical"          , VALUE, 330, 0, 440 },
}

--------------------------------------------------------------
local function log(s)
    -- print("BattAnalog: " .. s)
end
--------------------------------------------------------------

local function getSensorFieldInfo(wgt, name)
    local fi = getFieldInfo(name)
    if fi == nil then
        wgt.common.log("Required sensor '"..name.."' missing")
    end
    return fi
end

local function update(wgt, options)
    if (wgt == nil) then
        return
    end

    wgt.options = options

    wgt.vReserve = wgt.options.Reserve

    -- reload common libraries
    local commonClass = loadScript("/WIDGETS/eLib/lib_common.lua", "tcd")
    wgt.common = commonClass(app_name)

    local fi = getSensorFieldInfo(wgt, wgt.options.VoltSensor)
    wgt.sensorVoltId = fi and fi.id or 0

    fi = getSensorFieldInfo(wgt, wgt.options.mAhSensor)
    wgt.sensorMahId = fi and fi.id or 0

    fi = getSensorFieldInfo(wgt, wgt.options.FuelSensor)
    wgt.sensorPcntId = fi and fi.id or 0

    fi = getSensorFieldInfo(wgt, wgt.options.CellSensor)
    wgt.sensorCellsId = fi and fi.id or 0

    fi = getSensorFieldInfo(wgt, wgt.options.VoltAlerts)
    wgt.sourceVoltAlertsId = fi and fi.id or 0

    wgt.alertCellCitical = wgt.options.CellCritical
    wgt.alertCellLow = wgt.options.CellLow

    -- trigger retest
    wgt.cellCount = nil
end

local function create(zone, options)
    local wgt = {
        zone = zone,
        options = options,
        counter = 0,

        text_color = 0,
        cell_color = 0,
        border_l = 5,
        border_r = 10,
        border_t = 0,
        border_b = 10,

        isTelemetryActive = 0,
        fuel = 0,
        vReserve = 20,
        vLow = 10,
        vMah = 0,
        cellCount = nil,
        barColor = BAR_COLOR_OK,
        voltTimer = VOLTTIMER_DISABLED,
        cellFullCheckProgress = 0,

        -- alerts
        alertPending = 0,
        alertSampleDuration = 50,
        alertLevel = ALERTLEVEL_NONE,
        alertNext = 0,
        alertRepeatInterval = 500,

        cellv = 0,
        volts = 0,

        -- audio state
        lastCapa = 100,
        nextCapa = 0,

        -- methods
        getCritical = function (widget)
            return widget.vReserve > 0 and 0 or 20
        end,

        getCellFull = function (widget)
            return widget.options.CellFull > 0 and (widget.options.CellFull / 100) or 0
        end,
    }

    update(wgt, options)
    return wgt
end

-- audio support
local function playAudio(file)
    playFile(AUDIO_PATH .. file .. ".wav")
end

local function playVibe(widget)
    if widget.options.Vibrate == 1 then
        playHaptic(100, 0, PLAY_NOW)
    end
end

-- color for gauge
local function getBarColor(wgt)
    local critical = wgt:getCritical()
    if wgt.voltTimer ~= VOLTTIMER_DISABLED then
        -- in cell check
        return BAR_COLOR_CHECK
    elseif wgt.fuel <= critical then
        -- red
        return BAR_COLOR_CRITICAL
    elseif wgt.fuel <= critical + 20 then
        -- yellow
        return BAR_COLOR_LOW
    else
        -- green
        return wgt.barColor
    end
end

--- paint
local function paint(wgt)
    local myBatt = { ["x"] = 4, ["y"] = 4, ["w"] = wgt.zone.w - 8, ["h"] = wgt.zone.h - 8, ["segments_w"] = 25, ["color"] = WHITE, ["cath_w"] = 6, ["cath_h"] = 20 }

    -- background
    local color = BAR_COLOR_BACKGROUND
    lcd.drawFilledRectangle(myBatt.x, myBatt.y, myBatt.w, myBatt.h, color)

    -- bar
    if wgt.fuel and wgt.volts and wgt.volts > 0 then
        local fill
        if wgt.voltTimer == VOLTTIMER_DISABLED then
            fill = wgt.fuel > 0 and wgt.fuel <= 100 and wgt.fuel or 100
        else
            fill = wgt.cellFullCheckProgress < 100 and wgt.cellFullCheckProgress or 100
        end

        local bar_width = math.floor((((myBatt.w - 2) / 100) * fill) + 2)
        color = getBarColor(wgt)
        lcd.drawFilledRectangle(myBatt.x, myBatt.y, bar_width, myBatt.h, color)

        color = BAR_COLOR_LINE
        lcd.drawLine(myBatt.x + bar_width, myBatt.y, myBatt.x + bar_width, myBatt.y + myBatt.h, SOLID, color)
    end

    -- outline
    lcd.drawRectangle(myBatt.x, myBatt.y, myBatt.w + 1, myBatt.h, wgt.text_color)

    -- bar
    local volts
    if wgt.cellCount and wgt.cellCount > 0 then
        -- cell count available
        volts = string.format("%.1f v / %.2f v (%.0fs)", wgt.volts, wgt.cellv, wgt.cellCount);
    else
        -- cell count not available
        volts = string.format("%.1f v / %.2f v (?s)", wgt.volts, wgt.cellv);
    end
    lcd.drawText(myBatt.x + 8, myBatt.y + 4, volts, BOLD + LEFT  + wgt.text_color)

    if wgt.sensorMahId ~= 0 then
        local mah = string.format("%.0f mah", wgt.vMah)
        lcd.drawText(myBatt.x + 8, myBatt.y + myBatt.h / 2, mah, BOLD + LEFT  + wgt.text_color)
    end

    local percent = string.format("%.0f%%", wgt.fuel)
    lcd.drawText(myBatt.x + myBatt.w - 4, myBatt.y + myBatt.h / 2, percent, BOLD + VCENTER + RIGHT + MIDSIZE + wgt.text_color)
end

--- battery calcs
local function calculateBatteryData(wgt)
    -- get voltage
    local v = getValue(wgt.sensorVoltId)

    -- cells
    local cells = 0
    if wgt.sensorCellsId ~= 0 then
        -- use sensor cell count
        cells = getValue(wgt.sensorCellsId)
    elseif wgt.options.Cells > 0 then
        -- use configured cell count
        cells = wgt.options.Cells
    end
    if wgt.cellCount ~= cells then
        wgt.cellCount = cells

        wgt.voltTimer = getTime() + STARTUP_DELAY
        wgt.cellFullCheckProgress = 0
    end
    local vdiv = wgt.cellCount and wgt.cellCount > 0 and wgt.cellCount or 1

    -- check for initial voltage check
    local now = getTime()
    if wgt.voltTimer ~= VOLTTIMER_DISABLED then
        if wgt.voltTimer < now then
            wgt.voltTimer = VOLTTIMER_DISABLED

            -- warn if battery low or cell count unknown
            if wgt.cellCount == 0 then
                -- cell count unknown
                wgt.barColor = BAR_COLOR_CHECK
            elseif (v / vdiv) >= wgt:getCellFull() then
                -- ok
                wgt.barColor = BAR_COLOR_OK
            else
                -- warn
                playAudio("batlow")
                playNumber(v * 10, 1, PREC1)
                wgt.barColor = BAR_COLOR_WARN
            end
        else
            local progress = 100 - ((wgt.voltTimer - now) * 100 / STARTUP_DELAY)
            if wgt.cellFullCheckProgress ~= progress then
                wgt.cellFullCheckProgress = progress
            end
        end
    end

    -- battery voltage
    wgt.cellv = v / vdiv
    wgt.volts = v

    -- battery percentage
    if wgt.sensorPcntId ~= 0 then
        local pcnt = getValue(wgt.sensorPcntId)
        if pcnt < wgt.vReserve then
            wgt.fuel = pcnt - wgt.vReserve
        else
            local usable = 100 - wgt.vReserve
            wgt.fuel = (pcnt - wgt.vReserve) / usable * 100
        end
    else
        wgt.fuel = 0
    end

    -- battery mah
    if wgt.sensorMahId ~= 0 then
        wgt.vMah = getValue(wgt.sensorMahId)
    end
end

-- call fuel consumption on the 10's (singles when critical)
local function crankFuelCalls(widget)
    -- voice alerts
    local fuel = widget.fuel

    local critical = widget:getCritical()

    -- what do we have to report?
    local capa = 0
    if fuel > critical + widget.vLow then
        capa = math.ceil(fuel / 10) * 10
    else
        capa = fuel
    end

    -- time to report?
    if (widget.lastCapa ~= capa or capa <= 0) and getTime() > widget.nextCapa then
        -- skip initial report
        if widget.nextCapa ~= 0 then
            -- urgent?
            if capa > critical + widget.vLow then
                playAudio("battry")
            elseif capa > critical then
                playAudio("batlow")
            else
                playAudio("batcrt")
                playVibe(widget)
            end

            -- play % if >= 0
            if capa >= 0 then
                playNumber(capa, UNIT_PERCENT)
            end
        end

        -- schedule next
        widget.lastCapa = capa
        widget.nextCapa = getTime() + 500
    end
end

local function crankVoltageAlerts(widget)
    -- bail if in delay
    local now = getTime()
    if now < widget.alertNext then
        return
    end
    
    -- we will be working w/ per cell voltage (x100 for 2 place decimal prec)
    local prec = 100
    local cellv = math.floor(widget.cellv * prec)

    local alertLevel = (cellv <= widget.alertCellCitical and ALERTLEVEL_CRITICAL) or (cellv <= widget.alertCellLow and ALERTLEVEL_LOW) or ALERTLEVEL_NONE

    if widget.alertPending ~= 0 then
        -- in alert state
        if alertLevel == ALERTLEVEL_NONE then
            -- exit alert state alert condition cleared while pending
            widget.alertPending = 0
            return
        elseif alertLevel < widget.alertLevel then
            -- reduce alert level if less critical level seen while pending
            widget.alertLevel = alertLevel
        end

        -- trigger if delay elapsed
        if now >= widget.alertPending then
            -- alert
            local locale = "en"
            local haptic = false
            if alertLevel == ALERTLEVEL_LOW then
                playAudio("batlow")
            elseif alertLevel == ALERTLEVEL_CRITICAL then
                playAudio("batcrt")
                haptic = true
            end
            -- report total voltage until https://github.com/FrSkyRC/ETHOS-Feedback-Community/issues/3491
            -- (was https://github.com/FrSkyRC/ETHOS-Feedback-Community/issues/4708)
            playNumber(widget.volts * 10, UNIT_VOLTS, PREC1)

            if haptic then
                playVibe(widget)
            end

            -- start delay
            widget.alertNext = now + widget.alertRepeatInterval

            -- exit alert state
            widget.alertPending = 0
            return
        end
    elseif alertLevel > ALERTLEVEL_NONE then
        -- enter alert state
        widget.alertLevel = alertLevel
        widget.alertPending = now + widget.alertSampleDuration
    end
end

-- process sensors, pre-render and announce
local function background(wgt)
    if (wgt == nil) then
        return
    end

    -- assume no telemetry if required sensors missing
    if wgt.sensorVoltId == 0 or wgt.sensorPcntId == 0 then
        wgt.isTelemetryActive = false
    else
        local telemetryActive = wgt.common.isTelemetryActive()
        if telemetryActive ~= wgt.isTelemetryActive then
            wgt.isTelemetryActive = telemetryActive
            if wgt.isTelemetryActive then
                -- restart voltage check timer on telemetry connection
                wgt.voltTimer = getTime() + STARTUP_DELAY
            end
        end
    end

    -- bail if no telemetry
    if not wgt.isTelemetryActive then
        return
    end

    calculateBatteryData(wgt)

    -- quiet if mute or during startup delay
    if wgt.options.Mute ~= 1 and wgt.voltTimer == VOLTTIMER_DISABLED then
        -- fuel calls
        crankFuelCalls(wgt)

        -- low/critical voltage alerts
        if getValue(wgt.options.VoltAlerts) > 0 then
            crankVoltageAlerts(wgt)
        end
    end
end

local function refresh(wgt, event, touchState)
    if (wgt == nil)         then return end
    if type(wgt) ~= "table" then return end
    if (wgt.options == nil) then return end
    if (wgt.zone == nil)    then return end
    --if (wgt.options.Show_Total_Voltage == nil) then return end

    background(wgt)

    if wgt.isTelemetryActive then
        wgt.text_color = BLACK
        wgt.cell_color = BLACK
    else
        wgt.text_color = COLOR_THEME_DISABLED
        wgt.cell_color = COLOR_THEME_DISABLED
    end

    paint(wgt)

    if (event ~= nil) then
        if (touchState and touchState.tapCount == 2) or (event and event == EVT_VIRTUAL_EXIT) then
            lcd.exitFullScreen()
        end
    end
end

return { name = app_name, options = _options, create = create, update = update, background = background, refresh = refresh }
