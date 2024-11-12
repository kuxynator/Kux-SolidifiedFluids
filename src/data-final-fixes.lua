require("mod")
local main_name = "solidified-fluids"
local main_suffix_liquid = "--liquefied"
local main_suffix_solid = "--solidified"

local compression_factor = 10

local function find_technology_for_recipe(recipe_name)
    for _, technology in pairs(data.raw.technology) do
        if technology.effects then
            for _, effect in pairs(technology.effects) do
                if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
                    return technology
                end
            end
        end
    end
    return nil
end

local tech_solidified_fluids = data.raw.technology[main_name]
local tech_oil_gathering = data.raw.technology["oil-gathering"]
for _, fluid in pairs(data.raw.fluid) do
    if not data.raw.recipe["empty-"..fluid.name.."-barrel"] then goto fluid_continue end
    table.insert(tech_solidified_fluids.effects, {type = "unlock-recipe", recipe = fluid.name..main_suffix_solid})
    table.insert(tech_solidified_fluids.effects, {type = "unlock-recipe", recipe = fluid.name..main_suffix_liquid})

	if fluid.name == "water" or fluid.name == "crude-oil" then
		table.insert(tech_oil_gathering.effects, {type = "unlock-recipe", recipe = fluid.name..main_suffix_solid})
		table.insert(tech_oil_gathering.effects, {type = "unlock-recipe", recipe = fluid.name..main_suffix_liquid})
	end
    ::fluid_continue::
end

if settings.startup[main_name.."-alt"].value then
    for _, recipe in pairs(data.raw.recipe) do
        local has_fluid = false
		local has_input_fluid = false
		local has_output_fluid = false

        if string.find(recipe.name, main_suffix_solid) then goto recipe_continue end
        if string.find(recipe.name, main_suffix_liquid) then goto recipe_continue end

        if recipe.ingredients then
            for _, ingredient in ipairs(recipe.ingredients) do
                if ingredient.type == "fluid" then has_fluid = true; has_input_fluid=true end
            end
        end
		if recipe.results then
            for _, result in ipairs(recipe.results) do
                if result.type == "fluid" then has_fluid = true; has_output_fluid=true end
            end
        end

        if not has_fluid then goto recipe_continue end

        local recipe_alt = table.deepcopy(recipe)
        recipe_alt.name = recipe.name.."--"..main_name

        if not recipe.localised_name then
            if recipe.results then
                if #recipe.results > 1 then
                    if not recipe.main_product or recipe.main_product == "" then
                        recipe_alt.localised_name = {"", {"recipe-name."..recipe.name}}
                    end
                else
                    local res_name  = ""
                    local prototype = nil

                    if recipe.results[1]["type"] then
                        res_name  = recipe.results[1]["name"]
                        prototype = data.raw[recipe.results[1]["type"]][res_name]
                    else
                        res_name  = recipe.results[1][1]
                        prototype = data.raw.item[res_name]
                    end

                    if res_name and not prototype then
                        for key, prototypes in pairs(data.raw) do
                            if key ~= "recipe" and key ~= "technology" and prototypes[res_name] then
                                prototype = prototypes[res_name]
                            end
                        end
                    end

                    if prototype and prototype.localised_name then
                        recipe_alt.localised_name = prototype.localised_name
                    elseif res_name and res_name ~= "" then
                        recipe_alt.main_product = res_name
                    end
                end
            end
        end

        if recipe_alt.ingredients then
            for _, ingredient in ipairs(recipe_alt.ingredients) do
                if ingredient.type and ingredient.type == "fluid" then
                    if not data.raw.recipe["empty-"..ingredient.name.."-barrel"] then recipe_alt.hidden = true end

                    ingredient.type = "item"
                    ingredient.name = ingredient.name..main_suffix_solid
                    ingredient.amount = math.ceil(ingredient.amount / compression_factor)
                end
            end

            recipe_alt.allow_intermediates = true
            recipe_alt.allow_as_intermediate = true

            recipe_alt.hide_from_player_crafting = settings.startup[main_name.."-hide"].value
            if settings.startup[main_name.."-alt-ex"].value then
                recipe_alt.hide_from_player_crafting = false

                if not recipe_alt.hidden then recipe.hide_from_player_crafting = true end
            end

            has_fluid = false
            if recipe_alt.results then
                for _, result in ipairs(recipe_alt.results) do
                    if result.type and result.type == "fluid" then has_fluid = true end
                end
            end
            if recipe_alt.category == "crafting-with-fluid" and not has_fluid then recipe_alt.category = "crafting" end
        end

		if recipe_alt.results then
			for _, result in ipairs(recipe_alt.results or {}) do
				if result.type=="fluid" then ---@cast result data.ItemProductPrototype
					has_fluid = true
					result.type = "item"
					if recipe_alt.main_product == result.name then recipe_alt.main_product= result.name..main_suffix_solid end
					result.name = result.name..main_suffix_solid
					result.amount = math.ceil(result.amount / compression_factor)
				end
			end
		end

        if not recipe_alt.icon and not recipe_alt.icons then
            local result_name = ""
            if     recipe_alt.main_product then result_name = recipe_alt.main_product
            elseif recipe_alt.results      then result_name = recipe_alt.results[1].name
			end

            for key, prototypes in pairs(data.raw) do
                if key ~= "recipe" and key ~= "technology" and prototypes[result_name] then
                    if prototypes[result_name].icon         then recipe_alt.icon          = prototypes[result_name].icon         end
                    if prototypes[result_name].icon_size    then recipe_alt.icon_size     = prototypes[result_name].icon_size    end
                    if prototypes[result_name].icons        then recipe_alt.icons         = prototypes[result_name].icons        end
                end
            end

			-- Remove existing overlays
			if recipe_alt.icons then
				for i = #recipe_alt.icons, 1, -1 do
					if recipe_alt.icons[i].icon == mod.path.."graphics/box-overlay_64.png" then
						table.remove(recipe_alt.icons, i)
					end
				end
			end

			-- set layer.icon_size
            if recipe_alt.icons then
                for _, layer in ipairs(recipe_alt.icons) do
                    if not layer.icon_size then layer.icon_size = recipe_alt.icon_size or 64 end
                end
            end
        end

		-- convert icon to icons
        if not recipe_alt.icons then
            recipe_alt.icons = {{icon = recipe_alt.icon, icon_size = recipe_alt.icon_size or 64, scale = 0.5}}
			recipe_alt.icon = nil
        end

		--add overlay
		if has_output_fluid then
			table.insert(recipe_alt.icons, 1,
				{icon = mod.path.."graphics/box-overlay_64_2.png", icon_size = 64, scale = 0.5})
		end
		if has_input_fluid then
			table.insert(recipe_alt.icons,
				{icon = mod.path.."graphics/box-input-overlay_64_2.png", icon_size = 64, scale = 0.5})
		end
        --[[table.insert(recipe_alt.icons,
            {icon = mod.path.."graphics/compress-overlay-alt_64_2.png", icon_size = 64,
             scale = 0.5, tint = {a = 0.96, b = 0.93, g = 0.96, r = 0.90}})--]]

		--[[--test: independend of "solidified-fluids" technology
		local tech = find_technology_for_recipe(recipe.name)
		if tech then
			table.insert(tech.effects, {type = "unlock-recipe", recipe = recipe_alt.name})
		end
		]]

		--if recipe.name == "electric-engine-unit" then error(serpent.block(recipe_alt)) end
        data:extend({ recipe_alt })
        ::recipe_continue::
    end
end
