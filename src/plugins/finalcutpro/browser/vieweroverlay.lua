--- === plugins.finalcutpro.browser.vieweroverlay ===
---
--- Solo a clip in the Final Cut Pro Browser.

local require   = require

--local log       = require "hs.logger".new "soloclip"

local canvas    = require "hs.canvas"
local geometry  = require "hs.geometry"
local mouse     = require "hs.mouse"
local timer     = require "hs.timer"

local axutils   = require("cp.ui.axutils")
local fcp       = require "cp.apple.finalcutpro"
local tools     = require "cp.tools"

local plugin = {
    id              = "finalcutpro.browser.vieweroverlay",
    group           = "finalcutpro",
    dependencies    = {
        ["finalcutpro.commands"] = "fcpxCmds",
    }
}

local c
local activated = false
local overlayTimer

function plugin.init(deps)
    deps.fcpxCmds:add("viewerOverlay")
        :groupedBy("browser")
        :whenActivated(function()
            local w = 1920 / 10
            local h = 1080 / 10
            if activated then
                overlayTimer:stop()
                c:hide()
                c:delete()
                activated = false
            else
                activated = true
                local p = mouse.getAbsolutePosition()
                local r = geometry.rect(p.x, p.y, w, h)
                c = canvas.new(r)
                c[1] = {
                    type             = "rectangle",
                    action           = "strokeAndFill",
                    strokeColor      = { white = 1 },
                    fillColor        = { white = .25 },
                    roundedRectRadii = { xRadius = 5, yRadius = 5 },
                }
                c[2] = {
                    type = "image",
                    image = snapshot,
                    imageScaling = "scaleToFit",
                }
                c:show()
                overlayTimer = timer.doEvery(0.00001, function()
                    if fcp:isFrontmost() then
                        local contentsUI = fcp:viewer():contentsUI()
                        if contentsUI then
                            local snapshot = axutils.snapshot(contentsUI)
                            if snapshot then
                                local pos = mouse.getAbsolutePosition()
                                local rect = geometry.rect(pos.x, pos.y, w, h)
                                c[2].image = snapshot
                                c:frame(rect)
                            end
                        end
                    else
                        c:hide()
                    end
                end)
            end
        end)
end

return plugin
