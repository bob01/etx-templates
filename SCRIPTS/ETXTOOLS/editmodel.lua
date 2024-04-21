---- #########################################################################
---- #                                                                       #
---- # Copyright (C) EdgeTX                                                  #
-----#                                                                       #
-----# Credits: graphics by https://github.com/jrwieland                     #
-----#                                                                       #
---- # License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
---- #                                                                       #
---- # This program is free software; you can redistribute it and/or modify  #
---- # it under the terms of the GNU General Public License version 2 as     #
---- # published by the Free Software Foundation.                            #
---- #                                                                       #
---- # This program is distributed in the hope that it will be useful        #
---- # but WITHOUT ANY WARRANTY; without even the implied warranty of        #
---- # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
---- # GNU General Public License for more details.                          #
---- #                                                                       #
---- #########################################################################

-- Edits by: Rob Gayle (bob00@rogers.com)
-- Date: 2024
-- ver: 0.2.5

local VALUE = 0
local COMBO = 1

local edit = false
local page = 1
local current = 1
local pages = {}
local fields = {}
local direction = { "Normal", "Reverse" }
local switches = { "SA", "SB", "SC", "SD", "SE", "SF", "SG", "SH", "SI", "SJ" }

chdir("/SCRIPTS/ETXTOOLS")

-- load common Bitmaps
local BackgroundImg = Bitmap.open("img/background.png")
local ImgPageUp = Bitmap.open("img/pageup.png")
local ImgPageDn = Bitmap.open("img/pagedn.png")
local ImgSummary = Bitmap.open("img/summary.png")

-- Change display attribute to current field
local function addField(step)
  local field = fields[current]
  local min, max
  if field[3] == VALUE then
    min = field[6]
    max = field[7]
  elseif field[3] == COMBO then
    min = 0
    max = #(field[6]) - 1
  end
  if (step < 0 and field[5] > min) or (step > 0 and field[5] < max) then
    field[5] = field[5] + step
  end
end

-- Select the next or previous page
local function selectPage(step)
  lcd.drawBitmap(BackgroundImg,0,0)
  page = 1 + ((page + step - 1 + #pages) % #pages)
  edit = false
  current = 1
end

-- Select the next or previous editable field
local function selectField(step)
  -- repeat
    current = 1 + ((current + step - 1 + #fields) % #fields)
  -- until fields[current][4]==1
end

-- Redraw the current page
local function redrawFieldsPage(event)

  for index = 1, #fields, 1 do
    local field = fields[index]
    if field == nil then
      break
    end

    local attr = current == (index) and ((edit == true and BLINK or 0) + INVERS) or 0
    attr = attr + TEXT_COLOR

    if field[3] == VALUE then
      lcd.drawNumber(field[1], field[2], field[5], LEFT + attr + field[8])
    elseif field[3] == COMBO then
      if field[5] >= 0 and field[5] < #(field[6]) then
        lcd.drawText(field[1],field[2], field[6][1+field[5]], attr)
      end
    end
  end
end

local function updateField(field)
  local value = field[5]
end

-- Main
local function runFieldsPage(event)
  if event == EVT_VIRTUAL_EXIT then -- exit script
    return 2
  elseif event == EVT_VIRTUAL_ENTER then -- toggle editing/selecting current field
    if #fields > 0 and fields[current][5] ~= nil and fields[current][4] == 1 then
      edit = not edit
      if edit == false then
        -- lcd.clear()
        updateField(fields[current])
      end
    end
  elseif edit then
    if event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
      addField(1)
    elseif event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
      addField(-1)
    end
  else
    if event == EVT_VIRTUAL_NEXT then
      selectField(1)
    elseif event == EVT_VIRTUAL_PREV then
      selectField(-1)
    end
  end
  redrawFieldsPage(event)
  return 0
end

-- Utility
local function sjoin(table, separator, reverse)
  local out = ""

  if reverse ~= 0 then
    for i = #table, 1, -1 do
      out = out..table[i]
      if i > 1 then
        out = out..separator
      end
    end
  else
    for i = 1, #table do
      out = out..table[i]
      if i < #table then
        out = out..separator
      end
    end
  end

  return out
end

local INPUT_MOTOR = 8
local INPUT_MOTOR_OFF = 9
local INPUT_ARM = 5
local INPUT_BANK = 6
local INPUT_RESCUE = 12
local INPUT_RATES = 10
local INPUT_BLACKBOX = 7
local INPUT_SDLOGGING = 11

local function checkCompatiblity()
  local input = model.getInput(INPUT_BLACKBOX, 0)
  if input and input.inputName == "BBox" then
    input = model.getInput(INPUT_MOTOR, 0)
    if input and (input.inputName == "Motr" or input.inputName == "MotA") then
      -- compatible, next page
      selectPage(1)
      return true
    end
  end
  return false
end

local exitPage
local exitMessage
local exitX = 40
local exitY = 10

local function exitWithMessage(message)
  exitMessage = message
  page = exitPage
end

local function runExitWithMessage()
  lcd.clear()
  lcd.drawBitmap(BackgroundImg, 0, 0)
  fields = {}
  edit = false

  lcd.drawText(exitX - 20, exitY, "Error", MIDSIZE + TEXT_COLOR)

  local w, h = lcd.sizeText(exitMessage)
  lcd.drawText((LCD_W - w) / 2, (LCD_H - h) / 2, exitMessage, TEXT_COLOR)

  local text = "Hold [RTN] to exit..."
  w, h = lcd.sizeText(text)
  lcd.drawText((LCD_W - w) / 2, LCD_H - h, text, TEXT_COLOR + BOLD)

  return 0
end

local function runCompatiblityCheck()
  if not checkCompatiblity() then
    -- incompatible
    exitWithMessage("Current model is not compatible")
  end
  return 0
end

-- Switches
local switchX = 30
local switchY = 10
local switchDy = 32
local switchFields;

local SOURCE_SWITCH_OFFSET = 126

local function initSwitchConfig()
  local x = switchX + lcd.sizeText("SD Card Logging") + 20
  local wc = lcd.sizeText("SA") + 12
  local xd = x + lcd.sizeText("SA") + 16
  local wd = lcd.sizeText("Reverse") + 12
  local y = switchY + 35
  switchFields = {}

  -- exclude motor switch if using more complex SH/SJ setup
  local input = model.getInput(INPUT_MOTOR_OFF, 0)
  local sg = input and 0 or 1
  -- motor
  input = model.getInput(INPUT_MOTOR, 0)
  local reverse = input.weight < 0 and 1 or 0
  switchFields[#switchFields+1] = { x, y, COMBO, sg, input.source - SOURCE_SWITCH_OFFSET, switches, "Motor", wc, INPUT_MOTOR }
  switchFields[#switchFields+1] = { xd, y, COMBO, sg, reverse, direction, sg == 0 and { "Off(SJ)", "Hold", "On" } or {"Off", "Hold", "On"}, wd }
  y = y + switchDy

  -- arm
  input = model.getInput(INPUT_ARM, 0)
  reverse = input.weight < 0 and 1 or 0
  switchFields[#switchFields+1] = { x, y, COMBO, 1, input.source - SOURCE_SWITCH_OFFSET, switches, "Arm", wc, INPUT_ARM}
  switchFields[#switchFields+1] = { xd, y, COMBO, 1, reverse, direction, { "Armed", "Safe", "Safe" }, wd }
  y = y + switchDy

  -- bank
  input = model.getInput(INPUT_BANK, 0)
  reverse = input.weight < 0 and 1 or 0
  switchFields[#switchFields+1] = { x, y, COMBO, 1, input.source - SOURCE_SWITCH_OFFSET, switches, "Bank", wc, INPUT_BANK }
  switchFields[#switchFields+1] = { xd, y, COMBO, 1, reverse, direction, { "Bank3", "Bank2", "Bank1" }, wd }
  y = y + switchDy

  -- rates
  input = model.getInput(INPUT_RATES, 0)
  if input and input.inputName == "Rate" then
    reverse = input.weight < 0 and 1 or 0
    switchFields[#switchFields+1] = { x, y, COMBO, 1, input.source - SOURCE_SWITCH_OFFSET, switches, "Rates", wc, INPUT_RATES }
    switchFields[#switchFields+1] = { xd, y, COMBO, 1, reverse, direction, { "High", "Med", "Low" }, wd }
    y = y + switchDy
  end

  -- rescue
  input = model.getInput(INPUT_RESCUE, 0)
  if input and input.inputName == "Resc" then
    reverse = input.weight < 0 and 1 or 0
    switchFields[#switchFields+1] = { x, y, COMBO, 1, input.source - SOURCE_SWITCH_OFFSET, switches, "Rescue", wc, INPUT_RESCUE }
    switchFields[#switchFields+1] = { xd, y, COMBO, 1, reverse, direction, { "Activate", "Off" }, wd }
    y = y + switchDy
  end

  -- blackbox
  input = model.getInput(INPUT_BLACKBOX, 0)
  reverse = input.weight < 0 and 1 or 0
  switchFields[#switchFields+1] = { x, y, COMBO, 1, input.source - SOURCE_SWITCH_OFFSET, switches, "BlackBox", wc, INPUT_BLACKBOX }
  switchFields[#switchFields+1] = { xd, y, COMBO, 1, reverse, direction, { "Off", "On", "Erase" }, wd }
  y = y + switchDy

  -- sd logging
  input = model.getInput(INPUT_SDLOGGING, 0)
  if input and input.inputName == "Talk" then
    reverse = input.weight < 0 and 1 or 0
    switchFields[#switchFields+1] = { x, y, COMBO, 1, input.source - SOURCE_SWITCH_OFFSET, switches, "SD Card Logging", wc, INPUT_SDLOGGING }
    switchFields[#switchFields+1] = { xd, y, COMBO, 1, reverse, direction, { "On", "Call RPM", "Off" }, wd }
    y = y + switchDy
  end
end

local function runSwitchConfig(event)
  lcd.clear()
  lcd.drawBitmap(BackgroundImg,0,0)
  lcd.drawBitmap(ImgPageDn, 455, 95)
  lcd.drawText(switchX - 10, switchY, "Switch Assignments", MIDSIZE + TEXT_COLOR)
  fields = switchFields
  for idx = 1, #fields do
    local f = fields[idx]
    lcd.drawFilledRectangle(f[1] - 5, f[2] - 5, f[8], 30, TEXT_BGCOLOR)

    local tx = f[9] and switchX or (f[1] + f[8] + 4)
    local text = f[9] and f[7] or sjoin(f[7], "-", f[5])
    lcd.drawText(tx, f[2], text, TEXT_COLOR)
  end

  local result = runFieldsPage(event)
  return result
end

local LS_BATT_CONNECTED_INDEX       = 8
local LS_BEC_MONITOR_INDEX          = 11

local function isElectric()
  -- get logical switch, assume nitro if missing
  local lswitch = model.getLogicalSwitch(LS_BATT_CONNECTED_INDEX)
  return lswitch and lswitch.func ~= LS_FUNC_NONE
end

-- Warnings
local warningsX = 30
local warningsY = 10
local warningFields

local GV_RLO    = 0
local GV_BLO    = 1
local GV_BCR    = 2

local function initWarningConfig()
  local x = warningsX + 20
  local y = warningsY + 70
  local dy = 60
  warningFields = {}

  -- rlo
  local gv = model.getGlobalVariable(GV_RLO, 0)
  warningFields[#warningFields+1] = { x, y, VALUE, 1, gv, 0, 140, PREC1, "Rx/FBL Low Voltage" }
  y = y + dy

  -- electric only
  if isElectric() then
    -- blo
    gv = model.getGlobalVariable(GV_BLO, 0)
    warningFields[#warningFields+1] = { x, y, VALUE, 1, gv, 0, 560, PREC1, "Battery Low Voltage" }
    y = y + dy

    -- bcr
    gv = model.getGlobalVariable(GV_BCR, 0)
    warningFields[#warningFields+1] = { x, y, VALUE, 1, gv, 0, 560, PREC1, "Battery Critical Voltage" }
  end
end

local function runWarningConfig(event)
  lcd.clear()
  lcd.drawBitmap(BackgroundImg,0,0)
  lcd.drawBitmap(ImgPageUp, 0, 95)
  lcd.drawBitmap(ImgPageDn, 455, 95)
  lcd.drawText(warningsX - 10, warningsY, "Voltage Monitors", MIDSIZE + TEXT_COLOR)
  fields = warningFields
  local y = warningsY + 40

  for idx = 1, #fields do
    lcd.drawText(40, y, fields[idx][9], TEXT_COLOR)
    lcd.drawFilledRectangle(40, y + 25, 100, 30, TEXT_BGCOLOR)
    y = y + 60
  end

  y = y + 10
  lcd.drawText(40, y, "** Set to zero to disable", TEXT_COLOR)
  local result = runFieldsPage(event)
  return result
end

-- Advanced
local vmeterX = 30
local vmeterY = 10
local vmeterAdcImg
local vmeterBecImg
local vmeterLabel = "Rx/FBL Voltage Source: "
local vmeterFields
local vmeterAdcSensor
local vmeterEscSensor

local TELE_ADC_SENSOR_INDEX     = 12
local TELE_ESC_SENSOR_INDEX     = 19

local function initAdvancedConfig()
  vmeterFields = {}

  if not vmeterAdcSensor then
    vmeterAdcSensor = model.getSensor(TELE_ADC_SENSOR_INDEX)
  end
  if not vmeterEscSensor then
    vmeterEscSensor = model.getSensor(TELE_ESC_SENSOR_INDEX)
  end

  local lswitch = model.getLogicalSwitch(LS_BEC_MONITOR_INDEX)
  local isAdcSensor = lswitch.v1 == getSourceIndex(CHAR_TELEMETRY..vmeterAdcSensor.name)

  vmeterFields[1] = { vmeterX + lcd.sizeText(vmeterLabel) + 10, vmeterY + 50, COMBO, 1, isAdcSensor and 1 or 0, { "ESC Telemetry", "Servo Bus ADC" }, vmeterLabel }
end

local function runAdvancedConfig(event)
  lcd.clear()
  lcd.drawBitmap(BackgroundImg,0,0)
  lcd.drawBitmap(ImgPageUp, 0, 95)
  lcd.drawBitmap(ImgPageDn, 455, 95)
  lcd.drawText(vmeterX - 10, vmeterY, "Advanced", MIDSIZE + TEXT_COLOR)
  fields = vmeterFields

  local f = vmeterFields[1]
  lcd.drawText(vmeterX, f[2], f[7], TEXT_COLOR)

  local w = lcd.sizeText(f[6][2])
  lcd.drawFilledRectangle(f[1] - 5, f[2] - 5, w + 10, 30, TEXT_BGCOLOR)

  if not vmeterAdcImg then
    vmeterAdcImg = Bitmap.open("img/adcmeter.png")
  end
  if not vmeterBecImg then
    vmeterBecImg = Bitmap.open("img/becmeter.png")
  end

  local sensor
  local img
  if f[5] ~= 0 then
    sensor = vmeterAdcSensor
    img = vmeterAdcImg
  else
    sensor = vmeterEscSensor
    img = vmeterBecImg
  end

  -- show help
  lcd.drawText(45, f[2] + 40, "Top bar widget source should be set to "..CHAR_TELEMETRY..sensor.name, TEXT_COLOR)
  lcd.drawBitmap(img, 45, 130)
  
  local result = runFieldsPage(event)
  return result
end

-- Summary
local summaryX = 40
local summaryFX = 242
local summaryY = 10
local summaryDY = 20
local lineIndex

local function drawNextTextLine(text, text2)
  lcd.drawText(summaryX, lineIndex, text, TEXT_COLOR)
  lcd.drawText(summaryFX, lineIndex, ": " ..text2, TEXT_COLOR)
  lineIndex = lineIndex + summaryDY
end

local function drawNextNumberLine(text, number, prec)
  lcd.drawText(summaryX, lineIndex, text, TEXT_COLOR)
  lcd.drawText(summaryFX, lineIndex, ": ", TEXT_COLOR)
  local dx = lcd.sizeText(": ")
  lcd.drawNumber(summaryFX + dx, lineIndex, number, LEFT + prec + TEXT_COLOR)
  lineIndex = lineIndex + summaryDY
end

local function runConfigSummary(event)
  lcd.clear()
  fields = {}
  lcd.drawBitmap(BackgroundImg, 0, 0)
  lcd.drawBitmap(ImgPageUp, 0, 95)
  lcd.drawBitmap(ImgSummary, 300, 60)
  lineIndex = summaryY

  lcd.drawText(summaryX - 20, summaryY, "Summary", MIDSIZE + TEXT_COLOR)
  lineIndex = lineIndex + 30

  -- switches
  local f = switchFields
  for idx = 1, #f, 2 do
    local fs = switchFields[idx]
    local fd = switchFields[idx + 1]
    local val = switches[fs[5] + 1]
    if fd[5] == 1 then
      val = val.."  reversed"
    end
    if val then
    drawNextTextLine(fs[7], val)
    end
  end
  lineIndex = lineIndex + 6

  -- voltage warnings
  f = warningFields
  for idx = 1, #f do
    local val = f[idx][5]
    if val > 0 then
      drawNextNumberLine(f[idx][9], val, f[idx][8])
    else
      drawNextTextLine(f[idx][9], "disabled")
    end
  end

  local text = "Hold [Enter] to apply changes or [RTN] to cancel..."
  local w, h = lcd.sizeText(text)
  lcd.drawText((LCD_W - w) / 2, LCD_H - h, text, TEXT_COLOR + BOLD)

  local result = runFieldsPage(event)
  if event == EVT_VIRTUAL_ENTER_LONG then
    selectPage(1)
  end
  return result
end

-- Create model
local function createModel(event)
  lcd.clear()

  -- switches
  for idx = 1, #switchFields, 2 do
    local fs = switchFields[idx]
    local fd = switchFields[idx + 1]
    local index = fs[9]
    local input = model.getInput(index, 0)
    input.source = fs[5] + SOURCE_SWITCH_OFFSET
    if fd[5] == 1 then
      input.weight = -input.weight
    end
    model.insertInput(index, 0, input)
    model.deleteInput(index, 1)
  end

  -- voltage warnings
  fields = warningFields
  for idx = 1, #fields do
    model.setGlobalVariable(idx - 1,0,fields[idx][5])
  end

  -- advanced
  local f = vmeterFields[1]
  -- if f[5] ~= 0 then

  local lswitch = model.getLogicalSwitch(LS_BEC_MONITOR_INDEX)
  lswitch.v1 = getSourceIndex(CHAR_TELEMETRY..(f[5] > 0 and vmeterAdcSensor.name or vmeterEscSensor.name))
  model.setLogicalSwitch(LS_BEC_MONITOR_INDEX, lswitch)

  return 2
end

-- Init
local function init()
  current, edit = 1, false
  pages = {}

  pages[#pages+1] = runCompatiblityCheck
  pages[#pages+1] = runSwitchConfig
  pages[#pages+1] = runWarningConfig
  if isElectric() then
    pages[#pages+1] = runAdvancedConfig
  end
  pages[#pages+1] = runConfigSummary
  pages[#pages+1] = createModel
  pages[#pages+1] = runExitWithMessage

  exitPage = #pages

  -- bail now if model not compatible
  if not checkCompatiblity() then
    return
  end

  initSwitchConfig()
  initWarningConfig()
  initAdvancedConfig()
end


-- Main
local function run(event, touchState)
  if event == nil then
    error("Cannot be run as a model script!")
    return 2
  elseif page == exitPage then
    -- fall thru, w/o nav for this page
  elseif event == EVT_VIRTUAL_PREV_PAGE and page > 1 then
    killEvents(event);
    selectPage(-1)
  elseif event == EVT_VIRTUAL_NEXT_PAGE and page < #pages - 2 then
    selectPage(1)
  elseif event == EVT_TOUCH_FIRST and (touchState.x <= 40 and touchState.y >= 100 and touchState.y <= 160) then
    selectPage(-1)
  elseif event == EVT_TOUCH_FIRST and (touchState.x >= LCD_W - 40 and touchState.y >= 100 and touchState.y <= 160) then
    if page ~= (#pages - 2) then
      selectPage(1)
    end
  end

  local result = pages[page](event)
  return result
end

return { init=init, run=run }
