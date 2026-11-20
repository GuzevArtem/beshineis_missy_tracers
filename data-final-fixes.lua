require("prototypes/projectiles") -- here since we are stealing all target effects that may be added by other mods
local utils = require("libs/utils")
--local VisualTracerAnim = require("libs/VisualTracerAnim")

--[[
Appliable only for hidden entity, so removed for now

-- Idea:
-- Collect all range variations
-- Subdivide them within some range brackets
-- Sort turrets/guns per bracket
-- For each entity in brakket assign bracket specific entity flag
-- Create actions for each bracket, with range set to that value
-- So 18,20,22 will fall in one bracket with range of 22
-- While 32,36 - will fall in other bracket with range of 36


---@param name string
---@param entity AmmoTurretPrototype|GunPrototype wrapped in table
---@param collectedRanges table out parameter
local function collectRanges (name, entity, collectedRanges)
	if not entity then
		return
	end

	if not entity.attack_parameters or entity.attack_parameters.ammo_category ~= "bullet" then
		return
	end

	if not collectedRanges[name] then
		collectedRanges[name] = entity.attack_parameters.range
	else
		-- one prototype twice? O_o
		collectedRanges[name] = math.max(collectedRanges[name], entity.attack_parameters.range)
	end
end

---@class Bracket
---@field range double
---@field minimal_range double
---@field entity_ids [string]
local Bracket = {}
Bracket.__index = Bracket

---@param range double
---@param entity_ids string|[string]
function Bracket:new(range, entity_ids)
	local instance = setmetatable({}, self)
	instance.range = range or 0
	instance.minimal_range = range or 0
	if not entity_ids then
		-- should never happen
		instance.entity_ids = {}
	else
		if type(entity_ids) == "table" then
			-- actually array is expected, but lua :(
			instance.entity_ids = entity_ids
		else
			instance.entity_ids =  { entity_ids }
		end
	end
	return instance
end

---@param bracket Bracket
function Bracket:merge(bracket)
	self.range = math.max(self.range, bracket.range)
	self.minimal_range = math.min(self.minimal_range, bracket.range)
	for i = 1, #bracket.entity_ids do
		self.entity_ids[#self.entity_ids + 1] = bracket.entity_ids[i]
	end
	return self
end

---@param range double
---@param entity_id string
function Bracket:add(range, entity_id)
	self.range = math.max(self.range, range)
	self.minimal_range = math.min(self.minimal_range, range)
	self.entity_ids[#self.entity_ids + 1] = entity_id
	return self
end

function Bracket:average_range()
	return 0.5 * (self.range + self.minimal_range)
end

local function prepare_brackets ()
	local collectedRanges = {}

	for name, prototype in pairs(data.raw["ammo-turret"]) do
		collectRanges(name, prototype, collectedRanges)
	end

	for name, prototype in pairs(data.raw["gun"]) do
		collectRanges(name, prototype, collectedRanges)
	end

	local absolute_minimal_range = settings.startup["beshineis_tracers--minimal_bullet_range"].value

	-- sort, long range - last
	-- stupid WA, since lua can't sort table when string is key...
	local collectedRangesSorted = {}
	for key,value in pairs(collectedRanges) do
		local pair = {}
		pair[key] = value
		table.insert(collectedRangesSorted, pair)
	end

	-- 2. Sort the keys alphabetically
	table.sort(collectedRangesSorted, function(range_a, range_b)
			local _, v_a = next(range_a)
			local _, v_b = next(range_b)
			return v_a < v_b
		end)

	-- Do initial bracket sorting
	local brackets = {} -- array
	local last_bracket_id = 0
	local last_range = 0/0 -- abusing x <= Nan is always false

	local brackets_count = 0

	for _, entityid_range in ipairs(collectedRangesSorted) do
		local entity_id, range = next(entityid_range)
		if range <= last_range then
			-- extend existing bracket
			brackets[last_bracket_id]:add(range, entity_id)
		else
			-- add new one
			last_range = math.max(absolute_minimal_range, range)
			last_bracket_id = last_bracket_id + 1
			brackets[#brackets + 1] = Bracket:new(range, entity_id)
			brackets_count = brackets_count + 1
		end
	end

	local target_brackets_count = settings.startup["beshineis_tracers--brackets_count"].value

	if target_brackets_count < 4 then
		error("beshineis_tracers--brackets_count, should be at least 4 to make sense")
	end

	while target_brackets_count < brackets_count do
		-- brackets merging required

		-- find smallest range deviation available
		local smallest_range_deviation_value = 0/0 -- abusing x < Nan == false for all x
		local smallest_range_deviation_index = -1
		for i = 2, brackets_count do
			-- measuring from range center to range center, so ranges [1,2,3,4] will collapse into [2,4], not into [3,4] after 2 iterations
			local range_deviation = brackets[i]:average_range() - brackets[i-1]:average_range()

			if range_deviation < smallest_range_deviation_value then
				smallest_range_deviation_value = range_deviation
				smallest_range_deviation_index = i-1
			end
		end

		if smallest_range_deviation_index >= 0 then
			-- do merge
			brackets[smallest_range_deviation_index]:merge(brackets[smallest_range_deviation_index + 1])
			table.remove(brackets, smallest_range_deviation_index + 1)
			-- do not forget to decrease count
			brackets_count = brackets_count - 1
		end
	end

	-- TODO:
	-- apply overrides from "beshineis_tracers--special_entity_deviation_coef"


	for i = 1, brackets_count do
		local bracket = brackets[i]
		for e = 1, table_size(bracket.entity_ids) do
			local entity_id = bracket.entity_ids[e]

		end
	end

end

prepare_brackets()
]]--

--- @type "directional"|"entity_leading"|"entity"|"vanilla"
local player_targeting = tostring(settings.startup["beshineis_tracers--player_targeting"].value) or "directional"
---@type "unified"|"projectile_spawner"|"hidden_turret"
local mode_of_operation = tostring(settings.startup["beshineis_tracers--mode_of_operation"].value) or "projectile_spawner"

local entity_configurations = data.raw["mod-data"]["beshineis_tracers--mod_data-entity_configuration_overrides"].data

-- list of everything that could fire bullets
local ammo_source_type_map = {
	["ammo-turret"] = "turret",
	["fluid-turret"] = "turret",
	["turret"] = "turret",
	["artillery-turret"] = "turret",
	["artillery-wagon"] = "vehicle",
	["locomotive"] = "vehicle",
	["cargo-wagon"] = "vehicle",
	["fluid-wagon"] = "vehicle",
	["car"] = "vehicle",
	["spider-vehicle"] = "vehicle",
	["character"] = "player",
	["gun"] = "player" -- added here, since working with prototypes, not runtime entities
}

-- adjust barrel offstes based on configuration
do
	---comment
	---@param name string
	---@return TurretPrototype|GunPrototype|UnitPrototype|CombatRobotPrototype|ActiveDefenseEquipmentPrototype|EntityPrototype|nil
	local find_applicable_entity = function (name)
		for entity_type, source_type in pairs(ammo_source_type_map) do
			if entity_type == "character" then
				-- character has no applicable, only his equipped gun does
				goto next_entity_type
			end

			if source_type == "vehicle" then
				-- exclude vehicles since applicable values are stored only in their guns
				goto next_entity_type
			end

			local entity = data.raw[entity_type][name]
			if entity then
				return entity
			end

			::next_entity_type::
		end
		return nil
	end

	-- TEMPORARY FOR TESTING TODO: REMOVE
	entity_configurations["gun-turret"] = {
		projectile_override = {
			projectile_center = nil, --{ x = 0.0, y = 0.0}, -- shift rotation pivot from turret position (for off axis turrets mostly)
			projectile_creation_distance = nil, --0.0, -- shift projectile along turret orientation from projectile_center
			projectile_orientation_offset = nil, --0.0,
			true_collinear_ejection = true, -- auto orient along shooting direction
			use_shooter_direction = false,
			apply_projection_to_projectile_creation_position = true,
			-- overridable properties:
			-- gun.attack_parameters.projectile_creation_distance = math.max(0.1,settings.startup["beshineis_tracers--scale"].value-0.5)
			-- turret.attack_parameters.projectile_creation_distance = turret.attack_parameters.projectile_creation_distance + math.max(0,settings.startup["beshineis_tracers--scale"].value*1.3-0.35)
		},

		shell_particle_override = {
			center = nil, --{ x = 0.0, y = 0.0}, -- shift rotation pivot from turret position (usually same as projectile_center)
			creation_distance = nil, --0.0,
			creation_distance_orientation = nil, --0.0
			-- overridable properties:
			-- turret.attack_parameters.shell_particle.creation_distance=(turret.attack_parameters.shell_particle.creation_distance or -1.88) + 1
		},

		-- only for runtime
		projectile_speed = settings.startup["beshineis_tracers--speed"].value or 1.85,
		projectile_speed_deviaton = settings.startup["beshineis_tracers--speed_deviation"].value or 0.15,
		range_deviation = settings.startup["beshineis_tracers--range_deviation"].value or 0.15, -- coefficient
		direction_deviation = settings.startup["beshineis_tracers--angle_deviation"].value or 5, -- in degrees
	}

	for name, configuration in pairs(entity_configurations) do
		if name == "default" then
			-- our special configuration, just skip it
			goto next_entity_configuration
		end

		local entity = find_applicable_entity(name)
		if not entity then
			error(string.format("Entity not found \"%s\". Check per entity configurations.", name))
		end

		-- only guns and turrets allowed here
		---@type AttackParameters -- actually ProjectileAttackParameters
		local entity_attack_parameters = entity.attack_parameters
		if not entity_attack_parameters then
			log("No attack_parameters for entity \"" .. name .. "\" (".. entity.type .. ")")
			goto next_entity_configuration
		end

		if entity_attack_parameters.type ~= "projectile" then
			-- only projectile capable entities can be affected
			goto next_entity_configuration
		end

		if entity_attack_parameters.ammo_category ~= "bullet" then
			-- only bullets are applicable for now
			goto next_entity_configuration
		end

		-- apply configurations
		if configuration.projectile_override then
			log("Applying barrel configuration override for entity \"" .. name .. "\" (".. entity.type .. ")")
			for key, value in pairs(configuration.projectile_override) do
				-- override all configured non nil properties
				if value then
					entity_attack_parameters[key] = value
				end
			end
		end

		if configuration.shell_particle_override and entity_attack_parameters.shell_particle then
			log("Applying barrel configuration override for entity \"" .. name .. "\" (".. entity.type .. ")")
			local shell_particle = entity_attack_parameters.shell_particle
			for key, value in pairs(configuration.shell_particle_override) do
				-- override all configured non nil properties
				if value then
					shell_particle[key] = value
				end
			end
		end

		::next_entity_configuration::
	end
end

-- adjust deviation overrides for special entities
if mode_of_operation ~= "unified" then
	local entity_deviation_coef_map = data.raw["mod-data"]["beshineis_tracers--mod_data-entity_deviation_override_map"].data
	local default_entity_configuration = entity_configurations["default"] or error("Missing beshineis_tracers--mod_data-entity_deviation_override_map[\"default\"]. Some rude mod may have removed it.")

	---@param name string
	---@param coefficient double
	local apply_configuration = function (name, coefficient)
		local configuration = entity_configurations[name]
		if not configuration then
			configuration = table.deepcopy(default_entity_configuration)
			entity_configurations[name] = configuration
		end

		-- scale deviation
		configuration.range_deviation = configuration.range_deviation * coefficient
		configuration.angle_deviation_deviation = configuration.range_deviation * coefficient
	end

	for entity_name_pattern, coefficient_value in pairs(entity_deviation_coef_map) do
		local coefficient = tonumber(coefficient_value)
		if not coefficient then
			error(string.format("Corrupted deviation coefficient \"%s\" assosiated with entity name pattern \"%s\"", tostring(coefficient_value), entity_name_pattern))
		end

		local any_found = false
		for entity_type, _ in pairs(ammo_source_type_map) do
			if data.raw[entity_type][entity_name_pattern] then
				-- exact match - skip pattern recognition
				any_found = true
				apply_configuration(entity_name_pattern, coefficient)
				break -- entity names are unique, go to next pattern
			else
				for name, prototype in pairs(data.raw[entity_type]) do
					-- filter non projectile weapons
					if not prototype or not prototype.attack_parameters or prototype.attack_parameters.type ~= "projectile" then
						goto next_prototype
					end

					if name:match(entity_name_pattern) then
						any_found = true

						apply_configuration(name, coefficient)
					end

					::next_prototype::
				end
			end
			if not any_found then
				error(string.format("No entity prototypes satisfy pattern \"%s\". Please check setting \"special_entity_deviation_coef\"", entity_name_pattern))
			end
		end
	end
end

---@param ammo_type AmmoType
---@param ammo_name string
local function mmodify_ammo_per_ammo_type (ammo_type, ammo_name)
	if not ammo_type then
		return
	end

	local actions = ammo_type.action
	if actions and actions.type then
		actions = {actions}
	else
		actions = {}
	end

	local projectile_actions = {}

	if mode_of_operation == "unified" then
		local tracer = utils.generate_tracer_name(ammo_name, ammo_type.source_type or "default")

		projectile_actions = {
			{
				type = "direct",
				action_delivery =
				{
					type = "projectile",
					projectile = tracer,
					starting_speed = settings.startup["beshineis_tracers--speed"].value,
					starting_speed_deviation = settings.startup["beshineis_tracers--speed_deviation"].value,
					direction_deviation = math.rad(tonumber(settings.startup["beshineis_tracers--angle_deviation"].value) or 0),
					range_deviation = settings.startup["beshineis_tracers--range_deviation"].value,
					max_range = settings.startup["beshineis_tracers--minimal_bullet_range"].value, -- Overrides max range for all bullets
				},
			}
		}
	elseif mode_of_operation == "projectile_spawner" then
		projectile_actions = {
			{
				type = "direct",
				action_delivery =
				{
					type = "instant",
					source_effects = {
						{
							type = "script",
							effect_id = "beshineis_tracers--spawn-bullet-projectile"
						}
					}
				},
			}
		}
	elseif mode_of_operation == "hidden_turret" then
		error("mode_of_operation=hidden_turret not implemented yet.")
	else
		error(string.format("Unknown mode_of_operation value =%s", tostring(mode_of_operation)))
	end

	-- append existing actions (only source_effects for direct actions)
	for _, action in ipairs(actions) do
		if action.type ~= "direct" then
			-- append as is
			projectile_actions[#projectile_actions + 1] = action
    		goto continue
		end

		local should_copy = true
		local modified_action = action
		if not modified_action.action_delivery[1] then
			modified_action.action_delivery = {modified_action.action_delivery}
		end

		for index, action_delivery in ipairs(modified_action.action_delivery) do
			if #action_delivery.source_effects == 0 then
				-- interested only in source effects
				break
			end

			if #action_delivery.target_effects > 0 then
				if should_copy then
					should_copy = false
					modified_action = table.deepcopy(modified_action)
				end
				modified_action.action_delivery[index].target_effects = nil
			end

			projectile_actions[#projectile_actions + 1] = modified_action
		end

		::continue::
	end

	-- change only actions! everything else left as is
	ammo_type.action = projectile_actions
end

---@param ammo AmmoItemPrototype
local function modify_ammo (ammo)
	if not ammo then
		return
	end

	if ammo.ammo_category ~= "bullet" then
		return
	end

	-- scale ammo per magazine, so it will be additive to other mods
	if settings.startup["beshineis_tracers--magazine_size_modifier"].value ~=1 then
		ammo.magazine_size = ammo.magazine_size * settings.startup["beshineis_tracers--magazine_size_modifier"].value
	end

	if not ammo.ammo_type then
		return
	end

	local player_ammo_types = {}
	local default_ammo_types = {}
	local created_ammo_types = {}
	if ammo.ammo_type[1] then
		local found_player_ammo_type = false
		local last_default_ammo_type_copy = nil
		for _, ammo_type in ipairs(ammo.ammo_type) do
			if ammo_type.source_type == "player" then
				found_player_ammo_type = true
				player_ammo_types[#player_ammo_types + 1] = ammo_type
				if player_targeting == "vanilla" then
					-- do not modify vanilla targeting
					goto next_ammo_type
				end
			end
			if ammo_type.source_type == "default" then
				default_ammo_types[#default_ammo_types + 1] = ammo_type
				last_default_ammo_type_copy = table.deepcopy(ammo_type)
			end
			mmodify_ammo_per_ammo_type(ammo_type, ammo.name)

			::next_ammo_type::
		end

		if not found_player_ammo_type and last_default_ammo_type_copy and player_targeting == "vanilla" then
			local new_player_ammo_type = table.deepcopy(ammo.ammo_type)
			new_player_ammo_type.source_type = "player"
			player_ammo_types[#player_ammo_types + 1] = new_player_ammo_type
			created_ammo_types[#created_ammo_types + 1] = new_player_ammo_type
		end
	else
		if not ammo.ammo_type.source_type then
			ammo.ammo_type.source_type = "default"
		end

		if ammo.ammo_type.source_type == "player" then
			player_ammo_types[#player_ammo_types + 1] = ammo.ammo_type
			if player_targeting == "vanilla" then
				-- do not modify vanilla targeting
				goto skip_player_targeting_modifications
			end
		elseif player_targeting == "vanilla" and ammo.ammo_type.source_type == "default" then
			local new_player_ammo_type = table.deepcopy(ammo.ammo_type)
			new_player_ammo_type.source_type = "player"
			player_ammo_types[#player_ammo_types + 1] = new_player_ammo_type
			created_ammo_types[#created_ammo_types + 1] = new_player_ammo_type
		end

		-- "default" source_type is mandatory only if multiple ammo_types are defined, that may not be the case in general
		if ammo.ammo_type.source_type == "default" then
			default_ammo_types[#default_ammo_types + 1] = ammo.ammo_type
		end

		mmodify_ammo_per_ammo_type(ammo.ammo_type, ammo.name)

		::skip_player_targeting_modifications::
	end

	if #player_ammo_types == 0 and #default_ammo_types > 0 then
		-- clone existing
		player_ammo_types = table.deepcopy(default_ammo_types)
		for i = 1, #player_ammo_types do
			player_ammo_types[i].source_type = "player"
			created_ammo_types[#created_ammo_types + 1] = player_ammo_types[i]
		end
	end

	-- modify existing/created player ammo_types
	for _, ammo_type in ipairs(player_ammo_types) do
		if ammo_type.source_type ~= "player" then
			-- sanity check
			error("local player_ammo_types variable contains ammo_type with  source_type~=\"player\". Broken mod logic.")
		end

		-- allow player to shoot in target direction, without explicitly locking on entity
		if player_targeting == "directional" then
			ammo_type.target_type = "direction"
			ammo_type.force_clamp_to_max_range = true
		elseif player_targeting == "entity_leading" then
			--ammo_type.target_type = "position" -- breaks prediction
			--ammo_type.clamp_position = true
			ammo_type.force_clamp_to_max_range = true
		end
	end

	-- append created_ammo_types to ammo
	if #created_ammo_types > 0 then
		if not ammo.ammo_type[1] then
			ammo.ammo_type = { ammo.ammo_type }
		end

		for _, ammo_type in ipairs(created_ammo_types) do
			ammo.ammo_type[#ammo.ammo_type + 1] = ammo_type
		end
	end

end

for _, prototype in pairs(data.raw["ammo"]) do
	modify_ammo(prototype)
end

local function modify_shotguns_pellets ()
	---@type table<string, projectile_archetype> | table
	local archetypes_map = data.raw["mod-data"]["beshineis_tracers--mod_data-tracer_settings"].data

	local shotgun_scale = 2/3
	local shotgun_tint = {r=0.5,g=0.5,b=0.5,a=0.5}
	local animation_template = {
		filename = "__beshineis_missy_tracers__/graphics/railgun-beam-y.png",
		priority = "extra-high",
		width = 16,
		height = 496,
		frame_count = 17,
		animation_speed = 1,
		draw_as_glow = true,
		blend_mode = "additive",
		shift = {0, 6.75*shotgun_scale},
		rotate_shift =true,
		scale = shotgun_scale,
		tint = shotgun_tint,
	}

	for name, projectile_prototype in pairs(data.raw["projectile"]) do
		if not projectile_prototype or not string.find(name, "shotgun-pellet") then
			goto next_projectile
		end

		-- inverted search, searching fs any archetype's strings matches name
		local archetype
		for archetype_name, archetype_candidate in pairs(archetypes_map) do
			for _, str in ipairs(archetype_candidate.matching_strings) do
				if string.find(name, str) then
					archetype = archetype_candidate
					goto archetype_found
				end
			end
		end
		--if we are here - no archetypes found
		archetype = archetypes_map["unknown"]
		::archetype_found::

		-- do update projectile
		projectile_prototype.animation = table.deepcopy(animation_template)
		projectile_prototype.animation.filename = archetype.tinted_animation_filename or archetype.animation_filename
		::next_projectile::
	end
end

local leading_configuration = {
	projectile_speed = tonumber(settings.startup["beshineis_tracers--speed"].value),
	tick_ahead = tonumber(settings.startup["beshineis_tracers--prediction_overshoot_ticks"].value)
}

modify_shotguns_pellets()
if mode_of_operation ~= "projectile_spawner" then

	-- projectile_spawner has custom projectile offset, and should have custom prediction
	for _,turret in pairs(data.raw["ammo-turret"]) do
		if turret.attack_parameters and turret.attack_parameters.ammo_category == "bullet" then
			turret.attack_parameters.apply_projection_to_projectile_creation_position = true
			turret.attack_parameters.lead_target_for_projectile_speed = leading_configuration.projectile_speed
			turret.attack_parameters.lead_target_for_projectile_delay = leading_configuration.tick_ahead

--[[
			-- adjust projectile spawn positions (TODO: works bad, to be replaced with generic configuration instead)
			-- TODO: seems to not do a thing
			if turret.attack_parameters.projectile_creation_distance then
				--turret.attack_parameters.projectile_creation_distance = turret.attack_parameters.projectile_creation_distance + math.max(0,settings.startup["beshineis_tracers--scale"].value*1.3-0.35)

				turret.attack_parameters.projectile_creation_distance = turret.attack_parameters.projectile_creation_distance-1
				if turret.attack_parameters.shell_particle then
					turret.attack_parameters.shell_particle.creation_distance=(turret.attack_parameters.shell_particle.creation_distance or -1.88) + 1
				end
			end
]]--
		end
	end
end

if player_targeting ~= "vanilla" then
	if player_targeting ~= "entity_leading" then
		for _, gun in pairs(data.raw["gun"]) do
			if gun.attack_parameters and gun.attack_parameters.ammo_category == "bullet" then
				gun.attack_parameters.lead_target_for_projectile_speed = leading_configuration.projectile_speed
				gun.attack_parameters.lead_target_for_projectile_delay = leading_configuration.tick_ahead
			end
		end
	end
end