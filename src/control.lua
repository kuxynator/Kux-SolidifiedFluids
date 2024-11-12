require("mod")
local main_name = "solidified-fluids"
local main_suffix_liquid = "--liquefied"
local main_suffix_solid = "--solidified"


function validate_recipes_for_techs()
    for _, force in pairs(game.forces) do
        if force and force.technologies then
            for _, tech in pairs(force.technologies) do validate_recipes_for_tech(tech) end
        end
    end
end


---@param tech LuaTechnology
function validate_recipes_for_tech(tech)

	local function set_enabled(name, value)
		if tech.force.recipes[name] then
			if tech.force.recipes[name].enabled == value then return end
			tech.force.recipes[name].enabled = value
		end
	end

    if tech.force and tech.force.technologies[main_name] then
		if(script.active_mods["Kux-SmartLinkedChests"]) then
			print("Kux-SmartLinkedChests exist >> "..tech.name)
			--no main technology required

			for _, effect in ipairs(tech.prototype.effects) do
				if effect.type ~= "unlock-recipe" then goto next_effect end
				local is_active = tech.force.recipes[effect.recipe].enabled
				set_enabled(effect.recipe.."--"..main_name, is_active)
				set_enabled(effect.recipe..main_suffix_liquid, is_active)
				set_enabled(effect.recipe..main_suffix_solid, is_active)

				::next_effect::
			end
		else
			local is_active = tech.researched and tech.force.technologies[main_name].researched

			for _, effect in ipairs(tech.prototype.effects) do
				if effect.type ~= "unlock-recipe" then goto next_effect end
				set_enabled(effect.recipe.."--"..main_name, is_active)
				set_enabled(effect.recipe..main_suffix_liquid, is_active)
				set_enabled(effect.recipe..main_suffix_solid, is_active)
				::next_effect::
			end
		end
    end


end


script.on_init(function()
    validate_recipes_for_techs()
end)

script.on_configuration_changed(function(configuration_changed_data)
    validate_recipes_for_techs()
end)

script.on_event({defines.events.on_research_finished, defines.events.on_research_reversed}, function(event)
    local tech = event.research
    if tech.name == main_name then validate_recipes_for_techs()
    else validate_recipes_for_tech(tech) end
end)

script.on_event({defines.events.on_technology_effects_reset}, function(event)
    validate_recipes_for_techs()
end)
