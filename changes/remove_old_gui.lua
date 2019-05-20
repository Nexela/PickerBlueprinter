return function(event)
    if event.mod_changes and event.mod_changes['PickerBlueprinter'] then
        for _, player in pairs(game.players) do
            local flow = player.gui.left.picker_main_flow
            if flow then
                local oldframe = flow.picker_bp_tools
                if oldframe then
                    oldframe.destroy()
                end
            end
        end
    end
end
