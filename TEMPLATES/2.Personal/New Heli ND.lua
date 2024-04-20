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
-- ver: 0.2.0

local VALUE = 0
local COMBO = 1
local edit = false
local page = 1
local current = 1
local pages = {}
local fields = {}
local Text_Color= lcd.setColor(CUSTOM_COLOR, BLACK)

chdir("/TEMPLATES/2.Personal")

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
  repeat
    current = 1 + ((current + step - 1 + #fields) % #fields)
  until fields[current][4]==1
end

-- Redraw the current page
local function redrawFieldsPage(event)

  for index = 1, 10, 1 do
    local field = fields[index]
    if field == nil then
      break
    end

    local attr = current == (index) and ((edit == true and BLINK or 0) + INVERS) or 0
    attr = attr

    if field[4] == 1 then
      if field[3] == VALUE then
        lcd.drawNumber(field[1], field[2], field[5], LEFT + attr + field[8])
      elseif field[3] == COMBO then
        if field[5] >= 0 and field[5] < #(field[6]) then
          lcd.drawText(field[1],field[2], field[6][1+field[5]], attr)
        end
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
    if fields[current][5] ~= nil then
      edit = not edit
      if edit == false then
        lcd.clear()
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

-- set visibility flags starting with SECOND field of fields
local function setFieldsVisible(...)
  local arg={...}
  local cnt = 2
  for i,v in ipairs(arg) do
    fields[cnt][4] = v
    cnt = cnt + 1
  end
end

local WarningFields = {
  {50, 50, VALUE, 1, 84, 0, 140, PREC1, "FBL Low Voltage" },
}

local function initWarningConfig()
  fields = WarningFields
  for idx = 1, #fields do
    fields[idx][5] = model.getGlobalVariable(idx - 1,0)
  end
  
end

local function runWarningConfig(event)
  lcd.clear()
  lcd.drawBitmap(BackgroundImg,0,0)
  lcd.drawBitmap(ImgPageDn, 455, 95)
  fields = WarningFields
  local y = 20

  for idx = 1, #fields do
    lcd.drawText(40, y, fields[idx][9])
    lcd.drawFilledRectangle(40, y + 25, 100, 30, TEXT_BGCOLOR)
    y = y + 65
  end

  y = y + 80
  lcd.drawText(40, y, "** Set to zero to disable")
  local result = runFieldsPage(event)
  return result
end

local lineIndex

local function drawNextTextLine(text, text2)
  lcd.drawText(40, lineIndex, text)
  lcd.drawText(242, lineIndex, ": " ..text2)
  lineIndex = lineIndex + 32
end

local function drawNextNumberLine(text, number, prec)
  lcd.drawText(40, lineIndex, text)
  lcd.drawText(242, lineIndex, ": ")
  local dx = lcd.sizeText(": ")
  lcd.drawNumber(242 + dx, lineIndex, number, LEFT + prec)
  lineIndex = lineIndex + 32
end

local function switchLine(text)
  text=WarningFields[2][5]
  getFieldInfo(text)
  swnum=text.id
end

local ConfigSummaryFields = {
  {110, 250, COMBO, 1, 0, { "No, I need to change something", "Yes, all is well, create the model !"} },
}

local function runConfigSummary(event)
  lcd.clear()
  fields = ConfigSummaryFields
  lcd.drawBitmap(BackgroundImg, 0, 0)
  lcd.drawBitmap(ImgPageUp, 0, 95)
  lineIndex = 40

  -- voltage warnings
  local f = WarningFields
  for idx = 1, #f do
    local val = f[idx][5]
    if val > 0 then
      drawNextNumberLine(f[idx][9], val, f[idx][8])
    else
      drawNextTextLine(f[idx][9], "disabled")
    end
  end

  local result = runFieldsPage(event)
  if(fields[1][5] == 1 and edit == false) then
    selectPage(1)
  end
  return result
end

local function createModel(event)
  lcd.clear()

  fields = WarningFields
  local y = 20

  -- voltage warnings
  for idx = 1, #fields do
    model.setGlobalVariable(idx - 1,0,fields[idx][5])
  end

  selectPage(1)
  return 0
end

local function onEnd(event)
  lcd.clear()
  lcd.drawBitmap(BackgroundImg, 0, 0)
  lcd.drawBitmap(ImgSummary, 300, 60)

  lcd.drawText(70, 90, "Model successfully created !")
  lcd.drawText(100, 130, "Hold [RTN] to exit.", Text_Color)
  return 0
end

-- Init
local function init()
  initWarningConfig()

  current, edit = 1, false
  pages = {
    runWarningConfig,
    runConfigSummary,
    createModel,
    onEnd
  }
end


-- Main
local function run(event, touchState)
  if event == nil then
    error("Cannot be run as a model script!")
    return 2
  elseif event == EVT_VIRTUAL_PREV_PAGE and page > 1 then
    killEvents(event);
    selectPage(-1)
  elseif event == EVT_VIRTUAL_NEXT_PAGE and page < #pages - 2 then
    selectPage(1)
  elseif event == EVT_TOUCH_FIRST and (touchState.x <= 40 and touchState.y >= 100 and touchState.y <= 160) then
    print(string.format("(%s) %s - %s", page, touchState.x, touchState.y))
    selectPage(-1)
  elseif event == EVT_TOUCH_FIRST and (touchState.x >= LCD_W - 40 and touchState.y >= 100 and touchState.y <= 160) then
    print(string.format("(%s) %s - %s", page, touchState.x, touchState.y))
    if page ~= (#pages - 2) then
      selectPage(1)
    end
  end

  local result = pages[page](event)
  return result
end

return { init=init, run=run }
