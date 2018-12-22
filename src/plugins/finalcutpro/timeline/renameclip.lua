--- === plugins.finalcutpro.timeline.renameclip ===
---
--- Rename Clip

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local require = require

--------------------------------------------------------------------------------
-- Logger:
--------------------------------------------------------------------------------
--local log = require("hs.logger").new("renameClip")

--------------------------------------------------------------------------------
-- CommandPost Extensions:
--------------------------------------------------------------------------------
local axutils = require("cp.ui.axutils")
local fcp = require("cp.apple.finalcutpro")
local tools = require("cp.tools")

--------------------------------------------------------------------------------
-- Hammerspoon Extensions:
--------------------------------------------------------------------------------
local geometry = require("hs.geometry")

--------------------------------------------------------------------------------
--
-- THE PLUGIN:
--
--------------------------------------------------------------------------------
local plugin = {
    id = "finalcutpro.timeline.renameclip",
    group = "finalcutpro",
    dependencies = {
        ["finalcutpro.commands"]    = "fcpxCmds",
    }
}

--------------------------------------------------------------------------------
-- INITIALISE PLUGIN:
--------------------------------------------------------------------------------
function plugin.init(deps)

    --------------------------------------------------------------------------------
    -- Add Commands:
    --------------------------------------------------------------------------------
    local renameClip = fcp:string("FFRename Bin Object")
    deps.fcpxCmds:add("renameClip")
        :whenActivated(function()
            local selectedClip
            local content = fcp:timeline():contents()
            local selectedClips = content:selectedClipsUI()
            if selectedClips and #selectedClips == 1 then
                selectedClip = selectedClips[1]
            end
            if selectedClip then
                local frame = selectedClip:attributeValue("AXFrame")
                if frame then
                    local geoFrame = geometry.new(frame)
                    local center = geoFrame and geoFrame.center
                    local topleft = geoFrame and geoFrame.topleft
                    local bottomright = geoFrame and geoFrame.bottomright
                    local point = center and geometry.point(center.x, center.y)
                    if point and tools.isOffScreen(point) then
                        point = bottomright and center and geometry.point(bottomright.x - 10, center.y)
                    end
                    if point and tools.isOffScreen(point) then
                        point = topleft and center and geometry.point(topleft.x + 10, center.y)
                    end
                    if point and tools.isOffScreen(point) == false then
                        --------------------------------------------------------------------------------
                        -- TODO: Eventually, it would be way better if we could just do
                        --       `item:performAction("AXShowMenu")`, rather than a dodgy ninja mouse
                        --       click but there's currently a 5-10sec delay.
                        --       https://github.com/asmagill/hs._asm.axuielement/issues/13
                        --------------------------------------------------------------------------------
                        tools.ninjaRightMouseClick(point)
                        local parent = selectedClip:attributeValue("AXParent")
                        local menu = parent and axutils.childWithRole(parent, "AXMenu")
                        local item = menu and axutils.childWith(menu, "AXTitle", renameClip)
                        if item and item:attributeValue("AXEnabled") == true then
                            item:performAction("AXPress")
                            return
                        else
                            local closeMenu = parent and axutils.childWithRole(parent, "AXMenu")
                            if closeMenu then
                                local closeMenuKids = closeMenu:attributeValue("AXChildren")
                                if closeMenuKids and #closeMenuKids >= 1 then
                                    closeMenuKids[1]:performAction("AXCancel")
                                end
                            end
                        end
                    end
                end
            end
            --------------------------------------------------------------------------------
            -- Something went wrong:
            --------------------------------------------------------------------------------
            tools.playErrorSound()
        end)
        :titled(renameClip)

end

return plugin