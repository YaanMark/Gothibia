g_itemTooltip = {}
_G.g_itemTooltip = g_itemTooltip

local tooltipWindow = nil
local OPCODE_ITEM_TOOLTIP = 251
local currentHoveredItem = nil

function init()
  ProtocolGame.registerExtendedOpcode(OPCODE_ITEM_TOOLTIP, onReceiveItemTooltip)

  tooltipWindow = g_ui.displayUI('itemtooltip.otui')
  if tooltipWindow then
    tooltipWindow:hide()
  end

  connect(g_game, {
    onGameEnd = onGameEnd
  })
end

function terminate()
  ProtocolGame.unregisterExtendedOpcode(OPCODE_ITEM_TOOLTIP)

  disconnect(g_game, {
    onGameEnd = onGameEnd
  })

  if tooltipWindow then
    tooltipWindow:destroy()
    tooltipWindow = nil
  end
end

function onGameEnd()
  hideTooltip()
end

function requestItemTooltip(itemId)
  if not g_game.isOnline() then return end
  g_logger.info("[ItemTooltip] Requesting tooltip for item: " .. tostring(itemId))
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(OPCODE_ITEM_TOOLTIP, tostring(itemId))
  end
end
g_itemTooltip.requestItemTooltip = requestItemTooltip

function hideTooltip()
  if tooltipWindow then
    tooltipWindow:hide()
  end
  g_tooltip.hide()
  currentHoveredItem = nil
end
g_itemTooltip.hideTooltip = hideTooltip

function onReceiveItemTooltip(protocol, opcode, buffer)
  g_logger.info("[ItemTooltip] Received opcode 251 payload: " .. tostring(buffer))
  if not buffer or #buffer == 0 then return end

  local success, data = pcall(function() return json.decode(buffer) end)
  if not success or not data or data.valid == false then
    g_logger.warn("[ItemTooltip] Failed to decode JSON or invalid item data")
    return
  end

  renderTooltip(data)
end

function renderTooltip(data)
  if not tooltipWindow then return end

  -- Set Name
  local nameLabel = tooltipWindow:getChildById('nameLabel')
  local nameText = data.name or "Item Desconhecido"
  if data.article and #data.article > 0 then
    nameText = data.article .. " " .. nameText
  end
  nameLabel:setText(nameText)

  -- Set Type / Classification
  local typeLabel = tooltipWindow:getChildById('typeLabel')
  local typeText = ""
  if data.classification and #data.classification > 0 then
    typeText = data.classification
  end
  if data.weight and data.weight > 0 then
    local weightText = string.format("Cap: %.2f oz", data.weight / 100)
    if #typeText > 0 then
      typeText = typeText .. " | " .. weightText
    else
      typeText = weightText
    end
  end
  typeLabel:setText(typeText)
  typeLabel:setVisible(#typeText > 0)

  -- Stats (Attack, Defense, Armor, Extra Def, Hit Chance)
  local statsLabel = tooltipWindow:getChildById('statsLabel')
  local stats = {}

  if data.attack and data.attack > 0 then
    table.insert(stats, string.format("Attack: %d", data.attack))
  end
  if data.defense and data.defense > 0 then
    local defText = string.format("Defense: %d", data.defense)
    if data.extraDefense and data.extraDefense ~= 0 then
      defText = defText .. string.format(" (%+d)", data.extraDefense)
    end
    table.insert(stats, defText)
  end
  if data.armor and data.armor > 0 then
    table.insert(stats, string.format("Armor: %d", data.armor))
  end
  if data.hitChance and data.hitChance > 0 then
    table.insert(stats, string.format("Hit Chance: %+d%%", data.hitChance))
  end
  if data.shootRange and data.shootRange > 1 then
    table.insert(stats, string.format("Range: %d tiles", data.shootRange))
  end

  -- Abilities (Speed, Skills, Stats)
  if data.abilities then
    if data.abilities.speed and data.abilities.speed ~= 0 then
      table.insert(stats, string.format("Speed: %+d", data.abilities.speed))
    end
    if data.abilities.skills then
      for skillId, val in pairs(data.abilities.skills) do
        table.insert(stats, string.format("Skill [%s]: %+d", tostring(skillId), val))
      end
    end
  end

  if #stats > 0 then
    statsLabel:setText(table.concat(stats, "\n"))
    statsLabel:setVisible(true)
  else
    statsLabel:setVisible(false)
  end

  -- Requirements (Level, Magic Level, Vocations)
  local reqLabel = tooltipWindow:getChildById('reqLabel')
  local reqs = {}
  if data.minReqLevel and data.minReqLevel > 0 then
    table.insert(reqs, string.format("Min Level: %d", data.minReqLevel))
  end
  if data.minReqMagicLevel and data.minReqMagicLevel > 0 then
    table.insert(reqs, string.format("Min Magic Level: %d", data.minReqMagicLevel))
  end
  if data.vocationString and #data.vocationString > 0 then
    table.insert(reqs, string.format("Vocations: %s", data.vocationString))
  end

  if #reqs > 0 then
    reqLabel:setText(table.concat(reqs, "\n"))
    reqLabel:setVisible(true)
  else
    reqLabel:setVisible(false)
  end

  -- Description
  local descLabel = tooltipWindow:getChildById('descLabel')
  if data.description and #data.description > 0 then
    descLabel:setText(data.description)
    descLabel:setVisible(true)
  else
    descLabel:setVisible(false)
  end

  -- Position Window near Mouse Cursor
  local mousePos = g_window.getMousePosition()
  local windowSize = tooltipWindow:getSize()
  local screenSize = g_window.getSize()

  local posX = mousePos.x + 12
  local posY = mousePos.y + 12

  if posX + windowSize.width > screenSize.width then
    posX = mousePos.x - windowSize.width - 6
  end
  if posY + windowSize.height > screenSize.height then
    posY = mousePos.y - windowSize.height - 6
  end

  tooltipWindow:setPosition({x = posX, y = posY})
  tooltipWindow:show()
  tooltipWindow:raise()
end
