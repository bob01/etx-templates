--[[
#########################################################################
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
]]

-- RotorFlight aware bitmap
-- Author: Rob Gayle (bob00@rogers.com)
-- Date: 2026
-- ver: 0.9.0.03194

local app_name = "eBitmap"

local ALIGN_LEFT    = 0
local ALIGN_CENTER  = 1
local ALIGN_RIGHT   = 2

local imageDir = "/images/"

local _options = {
    { "TextAlign"             , ALIGNMENT, ALIGN_CENTER },
}

local function loadBitmapFile(name, ext)
    local path = imageDir .. name .. ext
    local bmp = (fstat(path) and Bitmap.open(path)) or nil
    if bmp then
        local bw, bh = Bitmap.getSize(bmp)
        bmp = bw == 0 and bh == 0 and nil or bmp
    end
    return bmp
end

local function loadBitmap(name)
    return loadBitmapFile(name, ".png") or loadBitmapFile(name, ".bmp") or nil
end

local function update(wgt, options)
    if (wgt == nil) then
        return
    end

    wgt.options = options
end

local function create(zone, options)
    local wgt = {
        zone = zone,
        options = options,

        modelName = nil,
        craftBmp = nil,
        bmpNone = loadBitmap("new")
    }

    update(wgt, options)
    return wgt
end

--- paint
local function paint(wgt)
    -- canvas dimensions
    local box_width, box_height = wgt.zone.w, wgt.zone.h
    local box_left, box_top = 0, 0
    local margin = 8

    -- text
    local textAlignment = wgt.options.TextAlign
    local text = wgt.modelName or "---"
    local textFlags = BOLD + COLOR_THEME_PRIMARY1
    local text_w, text_h = lcd.sizeText(text, textFlags)

    -- bitmap
    local bmp = wgt.craftBmp or wgt.bmpNone
    if bmp then
        local bw, bh = Bitmap.getSize(bmp)
        local cw, ch = box_width, box_height - margin * 2 - text_h
        local scalew = cw / bw
        local scaleh = ch / bh
        local scale, ofx, ofy
        -- use smaller scale and center image
        if scalew < scaleh then
            scale = scalew
            ofx = 0
            ofy = (ch - bh * scale) / 2
        else
            scale = scaleh
            ofy = 0
            ofx = (cw - bw * scale) / 2
        end
        lcd.drawBitmap(bmp, box_left + ofx, box_top +ofy + text_h + margin * 2, scale * 100)
    end

    -- title
    local tx
    if textAlignment == ALIGN_LEFT then
        tx = box_left + margin * 2
    elseif textAlignment == ALIGN_CENTER then
        tx = box_left + box_width / 2 - text_w / 2
    else
        tx = box_left + box_width - text_w - margin * 2
    end
    lcd.drawText(tx, box_top + margin, text, textFlags)
end

local function background(wgt)
    if (wgt == nil) then
        return
    end

    local mi = model.getInfo()
    local modelName = mi.name
    if wgt.modelName ~= modelName then
        -- name
        wgt.modelName = modelName

        -- bitmap
        wgt.craftBmp = loadBitmap(modelName)
    end
end

local function refresh(wgt, event, touchState)

    if (wgt == nil)         then return end
    if type(wgt) ~= "table" then return end
    if (wgt.options == nil) then return end
    if (wgt.zone == nil)    then return end

    background(wgt)

    paint(wgt)

    if (event ~= nil) then
        if (touchState and touchState.tapCount == 2) or (event and event == EVT_VIRTUAL_EXIT) then
            lcd.exitFullScreen()
        end
    end
end

return { name = app_name, options = _options, create = create, update = update, background = background, refresh = refresh }
