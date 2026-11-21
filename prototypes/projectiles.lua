local utils = require("libs/utils")

--#region startup settings

---@type table<string, projectile_archetype> | table
local archetypes_map = data.raw["mod-data"]["beshineis_tracers--mod_data-tracer_settings"].data
local default_projectile_prototype = data.raw["mod-data"]["beshineis_tracers--mod_data-tracer_template"].data
--#endregion

--#region lookups
local direct_action_additional_delivery = {
	{
		type = "instant",
		target_effects =
		{
			{
				type = "create-entity",
				entity_name = "visual-tracer-explosion-hit-normal", -- may be overriden by archetype
				tile_collision_mask = {layers={water_tile=true}},
				offsets = { { 0, 1 } }, -- offset explosion center closer to actual hit position. ABSOLUTE! NOT RELATIVE TO PROJECTILE
			},
			{
				type = "create-entity",
				entity_name = "water-splash",
				tile_collision_mask = {layers={ground_tile=true}},
				offsets = { { 0, 1 } }, -- offset splash center closer to actual hit position. ABSOLUTE! NOT RELATIVE TO PROJECTILE
			}
		},
	}
}
--#endregion

--#region helper functions

-- also aplies damage from archetype, if none is present on projectile itself
---@param tracer_prototype ProjectilePrototype
---@param archetype projectile_archetype
local function apply_cosmetic_effects(tracer_prototype, archetype)
	-- TODO: remove offsets from original cosmetic effects
	-- TODO: replace/append custom effects if needed

	for _, action in ipairs(tracer_prototype.action) do
		if action.type ~= "direct" then
			-- ignore indirect actions - will be applied by ammo itself
			goto next_action
		end

		-- Check direct action or delivery-based actions
		local action_deliveries = action.action_delivery
		if not action_deliveries then
			goto next_action
		end

		local target_effects = action_deliveries.target_effects
		if not target_effects then
			goto next_action
		end

		if not target_effects[1] then
			target_effects = { target_effects }
		end

		-- remove "explosion-hit" cosmetic (mostly from vanilla or vanilla derived projectiles)
		-- It has a nasty offsets and graphic is mediocore with tracers
		for index = #target_effects, 1, -1 do
			local effect = target_effects[index]
			if effect.type ~= "create-entity" then
				goto next_effect
			end

			if effect.entity_name == "explosion-hit" then
				table.remove(target_effects, index)
			end

			::next_effect::
		end

		::next_action::
	end


	local action_additional_delivery = direct_action_additional_delivery
	if archetype.explosion_filename then
		action_additional_delivery = table.deepcopy(direct_action_additional_delivery)
		action_additional_delivery[1].target_effects[1].entity_name = archetype.explosion_filename
	end

	if not tracer_prototype.action or #tracer_prototype.action == 0 then
		-- Strange case. Ammo was stripped from all actions or all non target deliveries. Should never happen, but assume some mods may affect this
		-- Assume it is a mod mishup, so adding cosmetic target delivery and a guessed damage to target
		tracer_prototype.action = {
			type = "direct",
			action_delivery = action_additional_delivery
		}

		if archetype.reference_damage and archetype.reference_damage > 0 then
			local damage = archetype.reference_damage
			-- append some predefined damage, so ammo will hurt
			tracer_prototype.action.action_delivery[#action_additional_delivery + 1] = {
				type = "instant",
				target_effects = {
					type = "damage",
					damage = {amount = damage, type = "physical"}
				}
			}
		end
	else
		-- just add cosmetic action
		tracer_prototype.action[#tracer_prototype.action + 1] = {
			type = "direct",
			action_delivery = action_additional_delivery
		}
	end
end

---@param ammo_prototype_name string
---@return projectile_archetype
local function match_archetype(ammo_prototype_name)
	for _, archetype in pairs(archetypes_map) do
		for _, str in ipairs(archetype.matching_strings) do
			if string.find(ammo_prototype_name, str) then
				return archetype
			end
		end
	end
	return archetypes_map["unknown"]
end

---@param ammo_prototype_name string
---@param ammo_types table<AmmoSourceType, AmmoType>
---@param archetype projectile_archetype
---@param registered_tracers table
local function populate_tracers_per_ammo_type(ammo_prototype_name, ammo_types, archetype, registered_tracers)
	for source_type, ammo_type in pairs(ammo_types) do
		---@type ProjectilePrototype
		local tracer_prototype = table.deepcopy(default_projectile_prototype)
		tracer_prototype.name = utils.generate_tracer_name(ammo_prototype_name, source_type)
		tracer_prototype.light = archetype.light
		tracer_prototype.animation.filename = archetype.animation_filename

		tracer_prototype.action = {}

		local total_damage = 0

		local actions = table.deepcopy(ammo_type.action)
		if not actions then
			actions = {}
		elseif not actions[1] then
			actions = {actions}
		end

		for _, action in ipairs(actions) do
			if action.type ~= "direct" then
				-- ignore indirect actions - will be applied by ammo itself
				goto next_action
			end

			-- Check direct action or delivery-based actions
			local action_deliveries = action.action_delivery
			if not action_deliveries then
				goto next_action
			end

			local target_effects = action_deliveries.target_effects
			if not target_effects then
				goto next_action
			end
			if not target_effects[1] then
				target_effects = {target_effects}
			end

			-- gather total cumulitive damage from all possible effects
			for _, effect in pairs(target_effects) do
				if effect.type ~= "damage" or not effect.damage or not effect.damage.amount then
					goto next_effect
				end
				effect.damage.amount = effect.damage.amount
				if effect.damage.type ~= "physical" then
					goto next_effect
				end
				total_damage = total_damage + effect.damage.amount
				::next_effect::
			end

			-- remove all source effects
			action_deliveries.source_effects = nil

			-- stealing action
			tracer_prototype.action[#tracer_prototype.action + 1] = action

			::next_action::
		end

		-- deduce piercing value
		if archetype.piercing_damage and archetype.piercing_damage > 0 then
			tracer_prototype.piercing_damage = archetype.piercing_damage
		elseif string.find(ammo_prototype_name, "piercing", 1, true) then
			-- just guessing at this point
			-- collect all total damage and scale by some amount

			total_damage = total_damage * 25 -- scale it up, red mag~200, accounting for legendary variation too
			if total_damage == 0 then
				total_damage = 100 -- some random, but not ridiculus number
			end

			tracer_prototype.piercing_damage = total_damage
		end

		-- modify cosmetic explosion
		apply_cosmetic_effects(tracer_prototype, archetype)

		-- register prototype
		if not registered_tracers[ammo_prototype_name] then
			registered_tracers[ammo_prototype_name] = {}
		end
		registered_tracers[ammo_prototype_name][source_type] = tracer_prototype.name

		data:extend({
			tracer_prototype
		})
	end
end

local function populate_tracer_prototypes()
	-- first - collect all existing ammo_types

	-- ammo_type.name -> ammo_type.source_type -> ammo_prototype
	local ammo_type_map = {}

	for name, ammo_prototype in pairs(data.raw["ammo"]) do
		-- discard non bullet ammos
		if not ammo_prototype or ammo_prototype.ammo_category ~= "bullet" then
			goto next_ammo_prototype
		end

		if not ammo_prototype.ammo_type[1] then
			-- simple case - only "default" source_type
			ammo_type_map[name] = {}
			ammo_type_map[name]["default"] = ammo_prototype.ammo_type
		else
			for _, ammo_type in ipairs(ammo_prototype.ammo_type) do
				if not ammo_type then
					goto continue -- should never happen
				end

				if not ammo_type_map[name] then
					ammo_type_map[name] = {}
				end

				if ammo_type_map[name][ammo_type.source_type] then
					error(string.format("Multiple ammo_types with the same source_type=\"%s\" registered for ammo \"%s\". Not expected by this mod.", ammo_type.source_type, name))
				end

				ammo_type_map[name][ammo_type.source_type] = ammo_type
				-- Yes we have ignored target_filter entirely
				::continue::
			end
		end

		::next_ammo_prototype::
	end

	if table_size(ammo_type_map) == 0 then
		error(string.format("All available ammo prototypes[%d] are inapplicable for this mod. It most likely caused by other mod, not yet known to be incompetible.", table_size(data.raw["ammo"])))
	end

	---@type table<string, table<string, string>> ammo_prototype_name -> source_type -> tracer_name
	local registered_tracers = {}
	-- generate tracers
	for ammo_prototype_name, ammo_types in pairs(ammo_type_map) do
		local archetype = match_archetype(ammo_prototype_name)

		populate_tracers_per_ammo_type(ammo_prototype_name, ammo_types, archetype, registered_tracers)
	end

	if table_size(registered_tracers) > 0 then
		-- expose final tracer names for lookup later or from other mods
		data:extend({
			{
				type = "mod-data",
				name = "beshineis_tracers--mod_data-tracers",
				data_type = "beshineis_tracers.tracers",
				data = registered_tracers
			}
		})
	end
end
--#endregion

do
	populate_tracer_prototypes()
end
