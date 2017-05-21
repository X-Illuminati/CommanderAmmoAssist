//=== This file modifies Natural Selection 2, Copyright Unknown Worlds Entertainment. ============
//
// CAA\CAA_Client.lua
//
//    Created by:   Chris Baker (chris.l.baker@gmail.com)
//    License:      Public Domain
//
// Public Domain license of this file does not supercede any Copyrights or Trademarks of Unknown
// Worlds Entertainment, Inc. Natural Selection 2, its Assets, Source Code, Documentation, and
// Utilities are Copyright Unknown Worlds Entertainment, Inc. All rights reserved.
// ========= For more information, visit http://www.unknownworlds.com ============================

kCAAModVersion = "0.91"
DebugPrint("Commander Ammo Assist Mod version " .. kCAAModVersion)


local alertTechIdMap = { }
local alertButtonList = { }

/* CLB-
 * These constants adapted from GUICommanderHelpWidget.lua
 */
local kButtonTexture = "ui/buildmenu.dds"
local kButtonLayer = kGUILayerPlayerHUDForeground1
local kAlertButtonSizePx = 40
local kAlertIconColor = Color(1,1,1,1)
local kAlertButtonStartFade = 6 // starts at end of commander alert message fade
local kAlertFadeTime = 2 // ends 2 seconds later

// Helper function to create a new alert button
local function CreateAlertButton(entityId, techId, teamType)
    local worldButtonSize = GUIScale(kAlertButtonSizePx)

    local button = {}
    button.entityId = entityId
    button.time = 0
    button.team = teamType

    button.graphic = GetGUIManager():CreateGraphicItem()
    button.graphic:SetIsVisible(false)
    button.graphic:SetSize(Vector(worldButtonSize, worldButtonSize, 0))
    button.graphic:SetTexture(kButtonTexture)
    button.graphic:SetTexturePixelCoordinates(unpack(GetTextureCoordinatesForIcon(techId)))
    button.graphic:SetLayer(kButtonLayer)

    //DebugPrint("--Created Button %s - %f)", button.graphic, button.graphic:GetColor().a)
    table.insert(alertButtonList, button)
    
    return button
end // function CreateAlertButton

// Helper function to update the position of an alert button
// returns true if the alert is still valid
local function UpdateAlertButton(button, deltaTime)
    // add deltaTime to button alive time
    button.time = button.time + deltaTime
    if (button.time > (kAlertButtonStartFade+kAlertFadeTime)) then
        // button alive time exceeds 8 seconds, so destroy it
        //DebugPrint("----End  Button %s - %f)", button.graphic, button.graphic:GetColor().a)
        button.graphic:SetIsVisible(false)
        return false
    end

    // check if entity is on-screen and alive
    local entity = Shared.GetEntity(button.entityId)
    if entity ~= nil then
        if entity:GetIsAlive() then
            // adjust button position so it is jsut to the lower-left of the unit
            local worldButtonSize = GUIScale(kAlertButtonSizePx)
            local testvec = Client.WorldToScreen(entity:GetOrigin())
            if button.team == kMarineTeamType then
                testvec = testvec + Vector(-1.5*worldButtonSize, -0.5*worldButtonSize, 0)
            elseif button.team == kAlienTeamType then
                testvec = testvec + Vector(-1.5*worldButtonSize, 0.5*worldButtonSize, 0)
            else
                //not sure how this would happen...
                testvec = testvec + Vector(-1*worldButtonSize, worldButtonSize, 0)
            end
            button.graphic:SetPosition(testvec)

            button.graphic:SetIsVisible(true)
            //if (not button.graphic:GetIsVisible()) then
                //DebugPrint("--++Show Button %s - %f)", button.graphic, button.graphic:GetColor().a)
            //end
            
            // if button alive time is more than 6 seconds, start fading it out over the next 2 seconds
            if (button.time >= kAlertButtonStartFade) then
                local currentColor = kAlertIconColor
                currentColor.a = 1 - (button.time - kAlertButtonStartFade)/kAlertFadeTime
                button.graphic:SetColor(currentColor)
                //DebugPrint("--  Fade Button %s - %f)", button.graphic, button.graphic:GetColor().a)
            else
                //DebugPrint("--  Test Button %s - %f)", button.graphic, button.graphic:GetColor().a)
                local currentColor = kAlertIconColor
                currentColor.a = 1
                button.graphic:SetColor(currentColor)
            end
        else
            // not alive, destory button
            //DebugPrint("----Dead Button %s - %f)", button.graphic, button.graphic:GetColor().a)
            button.graphic:SetIsVisible(false)
            return false
        end // if entity:GetIsAlive()...
    else
         // GetEntity failed; must not be on-screen
        if (button.graphic:GetIsVisible()) then
            button.graphic:SetIsVisible(false)
            //DebugPrint("----Hide Button %s - %f)", button.graphic, button.graphic:GetColor().a)
        end
        
    end // if entity...

    return true
end // function UpdateAlertButton

//Helper function to destroy an alert button
local function DestroyAlertButton(index)
    //DebugPrint("--Destroy Button %s", alertButtonList[index].graphic)
    GUI.DestroyItem(alertButtonList[index].graphic)
    table.remove(alertButtonList, index)
end // function DestroyAlertButton


// We will extend Player:AddAlert
local originalP_AddAlert = nil
local function newP_AddAlert(self, techId, worldX, worldZ, entityId, entityTechId)
    table.insert(alertTechIdMap, techId)
    return originalP_AddAlert(self, techId, worldX, worldZ, entityId, entityTechId)
end // function newP_AddAlert

// We will extend GUICommanderAlerts:Update
local originalGCA_Update = nil
local function newGCA_Update(self, deltaTime)
    originalGCA_Update(self, deltaTime)
    
    // check for any new messages and check the Tech ID for each
    for _, message in ipairs(self.messages) do
        if #alertTechIdMap == 0 then
            break
        end

        // is it a new message?
        if message.Time == deltaTime then
            local techId = alertTechIdMap[1]
            table.remove(alertTechIdMap, 1)
            // check whether we are interested in this Alert
            if (techId == kTechId.MarineAlertNeedMedpack) or (techId == kTechId.MarineAlertNeedAmmo) or (techId == kTechId.MarineAlertNeedOrder) then
                //DebugPrint("GUICommanderAlerts:Update -- %s", EnumToString(kTechId, techId))
                CreateAlertButton(message.EntityId, techId, kMarineTeamType)
            elseif (techId == kTechId.AlienAlertNeedMist) or (techId == kTechId.AlienAlertNeedDrifter) then
                //DebugPrint("GUICommanderAlerts:Update -- %s", EnumToString(kTechId, techId))
                CreateAlertButton(message.EntityId, techId, kAlienTeamType)
            end
        end
    end // for ipairs(self.messages)

    // loop through all of our buttons and update them
    for i, button in ipairs(alertButtonList) do
        if not UpdateAlertButton(button, deltaTime) then
            DestroyAlertButton(i)
        end
    end
end // function newGCA_Update

// We will extend CommanderUI_GetAlertMessages in order to patch Player and GUICommanderAlerts
local originalCUI_GetAlertMessages = CommanderUI_GetAlertMessages
function CommanderUI_GetAlertMessages()
    local player = Client.GetLocalPlayer()
    if (newP_AddAlert ~= player.AddAlert) then
        //Print("Player:AddAlert patched")
        originalP_AddAlert = player.AddAlert
        player.AddAlert = newP_AddAlert
    end
    if GUICommanderAlerts.Update and (GUICommanderAlerts.Update ~= newGCA_Update) then
        //Print("GUICommanderAlerts:Update patched")
        originalGCA_Update = GUICommanderAlerts.Update
        GUICommanderAlerts.Update = newGCA_Update
    end

    return originalCUI_GetAlertMessages()
end // function CommanderUI_GetAlertMessages


//=== Change Log =================================================================================
//
// 0.50
// - Original Release
//
// 0.80
// - Reduced icon transparency
// - Moved icon slightly lower for aliens
//
// 0.90
// - Fixed the button transparency sometimes starting at 0
// - Change fade behavior to manual control as the message background transparency sometimes has 
//   the same problem
//
// 0.91
// - Changed AlienAlertNeedEnzyme to AlienAlertNeedDrifter
//          
//================================================================================================