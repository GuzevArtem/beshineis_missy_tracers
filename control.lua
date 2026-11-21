local utils = require("libs/utils")
local math2d = require("math2d")

---@type "unified"|"projectile_spawner"|"hidden_turret"
local mode_of_operation = tostring(settings.startup["beshineis_tracers--mode_of_operation"].value) or "projectile_spawner"
if mode_of_operation ~= "projectile_spawner" then
	--early return, since no need for this logic
	return
end

local DEBUG = false

---@param position ScriptRenderTarget
---@param color Color
---@param solid boolean|nil
---@param size double|nil in tiles
---@param thickness double|nil only if not solid, in pixels
local debug_draw_circle = function(reference_entity, position, color, solid, size, thickness)
	if DEBUG and position then rendering.draw_circle({
		color = color, -- {r = 1, g = 0, b = 0, a = 0.8}
		radius = size or 1, -- tiles
		width = thickness or 2, -- pixels
		filled = solid or true,
		target = position,
		surface = reference_entity.surface or game.player.surface,
		time_to_live = 60,  -- in ticks
		forces = { reference_entity.force.index }
	}) end
end
---@param start ScriptRenderTarget
---@param finish ScriptRenderTarget
---@param color Color
---@param thickness double|nil only if not solid, in pixels
local debug_draw_line = function(reference_entity, start, finish, color, thickness)
	if DEBUG and start and finish then rendering.draw_line({
		color = color, -- {r = 1, g = 0, b = 0, a = 0.8}
		from = start,
		to = finish,
		width = thickness or 2, -- pixels
		surface = reference_entity.surface or game.player.surface,
		time_to_live = 60,  -- in ticks
		forces = { reference_entity.force.index },
		draw_on_ground = true
	}) end
end

--- @type "directional"|"entity_leading"|"entity"|"vanilla"
local player_targeting = tostring(settings.startup["beshineis_tracers--player_targeting"].value) or "directional"
--[[ One day this setting will be runtime
local per_player_targeting_setting_map = {
}
script.on_player_removed(defines.events.on_player_removed, function (event)
	-- clear per player setting, since index can be reused
	if per_player_targeting_setting_map[event.player_index] then
		per_player_targeting_setting_map[event.player_index] = nil
	end
end)
]]
local minimal_bullet_range = tonumber(settings.startup["beshineis_tracers--minimal_bullet_range"].value) or 15 -- pistol as default minimal_bullet_range
local prediction_overshoot_ticks = tonumber(settings.startup["beshineis_tracers--prediction_overshoot_ticks"].value) or 0

local registered_tracers = (prototypes.mod_data["beshineis_tracers--mod_data-tracers"] or { data = {}}).data
local entity_configurations = (prototypes.mod_data["beshineis_tracers--mod_data-entity_configuration_overrides"] or { data = {}}).data

-- separate generator to minimize effect on main random
script.on_init(function()
	storage.generator = game.create_random_generator()
end)

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
	["character"] = "player"
}

local ammo_inventory_map = {
	["ammo-turret"] = defines.inventory.turret_ammo,
	["artillery-turret"] = defines.inventory.artillery_turret_ammo,
	["artillery-wagon"] = defines.inventory.artillery_wagon_ammo,
	["car"] = defines.inventory.car_ammo,
	["spider-vehicle"] = defines.inventory.spider_ammo,
	["character"] = defines.inventory.character_ammo
}

---@param entity LuaEntity
---@param selected_inventory_index integer?
---@return double -- range_modifier
---@return string? -- ammo_name
---@return LuaQualityPrototype? -- quality
local function get_ammo_range_bonus_and_ammo_name(entity, selected_inventory_index)
	local inv_define = ammo_inventory_map[entity.type]
	if not inv_define then
		return 1.0, nil, nil
	end

	local ammo_inventory = entity.get_inventory(inv_define)

	if not ammo_inventory then
		return 1.0, nil, nil
	end

	local ammo_stack
	if selected_inventory_index then
		ammo_stack = ammo_inventory[selected_inventory_index]
	else
		-- first non empty slot is used by default
		for i = 1, #ammo_inventory do
			if ammo_inventory[i].valid_for_read then
				ammo_stack = ammo_inventory[i]
				break
			end
		end
	end

	if not ammo_stack or not ammo_stack.valid_for_read then
		return 1.0, nil, nil
	end

	local ammo_name = ammo_stack.name
	local ammo_type = ammo_stack.prototype.get_ammo_type(ammo_source_type_map[entity.type] or "default")
	local quality = ammo_stack.quality
	if ammo_type and ammo_type.range_modifier then
		return ammo_type.range_modifier, ammo_name, quality
	end

	return 1.0, ammo_name, quality
end

---@param entity LuaEntity
---@return LuaItemPrototype|LuaEntityPrototype|nil?
---@return LuaQualityPrototype?
---@return QualityName
local function get_active_weapon_prototype_with_quality(entity)
	if ammo_source_type_map[entity.type] == "turret" then
		-- return turret as is
		return entity.prototype, (utils.using_quality and entity.quality) or nil, (utils.using_quality and entity.quality.name) or utils.stub_quality
	elseif ammo_source_type_map[entity.type] == "player" then
		-- characters hold guns with its own quality
		local gun_inv = entity.get_inventory(defines.inventory.character_guns)
		if not gun_inv then
			return nil, nil, utils.stub_quality
		end

		local gun = gun_inv[entity.selected_gun_index]
		return gun.prototype, (utils.using_quality and gun.quality) or nil, (utils.using_quality and gun.quality.name) or utils.stub_quality
	elseif ammo_source_type_map[entity.type] == "vehicle" then
		-- vehicle hold own guns, but quality is stored on vehicle itself
		return entity.prototype.indexed_guns[entity.selected_gun_index], (utils.using_quality and entity.quality) or nil, (utils.using_quality and entity.quality.name) or utils.stub_quality
	else
		error("Unexpected ammo source_type \"".. ammo_source_type_map[entity.type] .. "\"")
	end
end

---@param entity LuaEntity
---@return double
---@return double
---@return string?
---@return LuaQualityPrototype?
local function get_weapon_range_and_ammo_name_and_quality(entity)
	local base_range = 0.0
	local range_mod = 1
	local ammo_name = nil
	local quality = nil

	if not entity or not entity.valid then
		return base_range, range_mod, ammo_name
	end

	local prototype, quality, _ = get_active_weapon_prototype_with_quality(entity)
	if prototype and prototype.attack_parameters then
		base_range = prototype.attack_parameters.range * ((utils.using_quality and quality and quality.range_multiplier) or 1)
	else
		base_range = minimal_bullet_range
	end

	-- account for ammo bonuses
	range_mod, ammo_name, quality = get_ammo_range_bonus_and_ammo_name(entity, (ammo_source_type_map[entity.type] ~= "turret" and entity.selected_gun_index) or nil)

	return base_range, range_mod, ammo_name, quality
end

---@param event EventData.on_script_trigger_effect
---@param shooter LuaEntity
---@param start_pos MapPosition
---@param projectile_speed double?
---@return MapPosition?
local function calculate_target_pos(event, shooter, start_pos, projectile_speed)
	local target_entity = event.target_entity
	if target_entity == shooter and shooter.shooting_target then
		target_entity = shooter.shooting_target
	end

	local target_pos = (target_entity and target_entity.position) or event.target_position
	if not target_pos then
		return nil
	end

	if target_entity and mode_of_operation ~= "unified" and projectile_speed and projectile_speed > 0 then
		-- apply prediction
		local target_vel = target_entity.speed or 0
		local target_dir = target_entity.orientation -- rotation value [0, 1), 0 - north, 0.25 - east, 0.5 - south, 0.75 - west

		-- Simple linear velocity vector approximation
		local vx = math.sin(target_dir * 2 * math.pi) * target_vel
		local vy = -math.cos(target_dir * 2 * math.pi) * target_vel

		local dx = target_pos.x - start_pos.x -- horizontal offset to target
		local dy = target_pos.y - start_pos.y -- vertical offset to target
		local distance = math.sqrt(dx * dx + dy * dy)
		if distance > 0 then
			-- projectile_speed is in tiles per tick, 60 ticks per second
			local flight_time = distance / projectile_speed + prediction_overshoot_ticks -- deliberatly using average speed for prediction

			target_pos.x = target_pos.x + (vx * flight_time)
			target_pos.y = target_pos.y + (vy * flight_time)
		end
	end
	return target_pos
end

script.on_event("beshineis_tracers_spawn_bullet_projectile_event",
---@param event EventData.on_script_trigger_effect
function(event)
	if not event.effect_id or event.effect_id ~= "beshineis_tracers--spawn-bullet-projectile" then
		return
	end

	local shooter = event.source_entity
	if not shooter or not shooter.valid then
		return
	end

	local shooting_entity_name = shooter.name
	local shooting_entity_quality_name = utils.stub_quality
	-- if we are in a vehicle, or it is a character - actual shooting entity will be selected gun
	if ammo_source_type_map[shooter.type] ~= "turret" then
		local prototype, _, quality_name = get_active_weapon_prototype_with_quality(shooter)
		if prototype then
			shooting_entity_name = prototype.name
		end
		shooting_entity_quality_name = quality_name
	end

	local cfg = entity_configurations[shooting_entity_name] or entity_configurations["default"]

	-- event.source_position should already contain barrel_offset
	local start_pos = event.source_position or shooter.position

	-- shot direction vectror components
	local shot_direction = { x = nil, y = nil }

	do
		--[[ one day this setting will be runtime...
		if shooter.player and not per_player_targeting_setting_map[shooter.player.index] then
			per_player_targeting_setting_map[shooter.player.index] = settings.get_player_settings(shooter.player)["beshineis_tracers--player_targeting"].value
		end
		]]

		-- Determine target coordinates
		local target_pos
		-- per_player_targeting_setting_map[shooter.player.index] == "directional"
		if shooter.type == "character" and shooter.player then
			if shooter.shooting_state.state == defines.shooting.not_shooting then
				error("Shooting event fired, but shooter isn't shooting.")
			end
			target_pos = shooter.shooting_state.position
		elseif ammo_source_type_map[shooter.type] == "vehicle" then
			local shooting_character
			if shooter.driver_is_gunner then
				shooting_character = shooter.get_driver()
			else
				shooting_character = shooter.get_passenger() or shooter.get_driver()
			end

			if shooting_character then
				target_pos = shooting_character.shooting_state.position

				-- bandage fix: turret is not rotating toward cursor location, so we can force its rotation while shooting (event is already shared)
				if player_targeting == "directional" then
					local dx = target_pos.x - start_pos.x
					local dy = target_pos.y - start_pos.y
					-- atan2(dx, -dy) aligns 0 radians with North and increases clockwise
					local angle = math.atan2(dx, -dy)
					local expected_turret_orientation = (angle / (2 * math.pi)) % 1
					-- insta snap
					if not shooter.prototype.turret_rotation_speed or shooter.prototype.turret_rotation_speed >= 1 then
						shooter.relative_turret_orientation = (expected_turret_orientation - shooter.orientation) % 1
					else
						local target_relative_orientation = (expected_turret_orientation - shooter.orientation) % 1
						local delta = math.abs(target_relative_orientation - shooter.relative_turret_orientation)
						local positive = target_relative_orientation > shooter.relative_turret_orientation
						local change = ((positive and 1) or -1) * math.min(delta, shooter.prototype.turret_rotation_speed)
						shooter.relative_turret_orientation = (change + shooter.relative_turret_orientation) % 1
					end
				end
			else
				-- just some point in direction of gun orientation
				local turret_orientation = (shooter.orientation + shooter.relative_turret_orientation) % 1
				target_pos.x = start_pos + math.sin(turret_orientation * 2 * math.pi) * minimal_bullet_range
				target_pos.y = start_pos + -math.cos(turret_orientation * 2 * math.pi) * minimal_bullet_range
			end
		else
			-- turret
			target_pos = calculate_target_pos(event, shooter, start_pos, cfg.projectile_speed)
		end

		if not target_pos then
			return -- should never happen
		end

		local dx = target_pos.x - start_pos.x -- horizontal offset to target
		local dy = target_pos.y - start_pos.y -- vertical offset to target
		local dist = math.sqrt(dx * dx + dy * dy)

		if dist > 0 then
			-- Normalized direction vector
			shot_direction.x = dx / dist
			shot_direction.y = dy / dist
		else
			-- fallback to shooter orientation
			shot_direction.x = math.sin(shooter.orientation * 2 * math.pi)
			shot_direction.y = -math.cos(shooter.orientation * 2 * math.pi)
		end
	end

	-- Deviation calculation
	local actual_range_deviation = (cfg.range_deviation * utils.deviation_coef_for(shooting_entity_quality_name) ) or 0
	local actual_angle_deviation = (cfg.angle_deviation * utils.deviation_coef_for(shooting_entity_quality_name) ) or 0

	local range_deviation_coef = 1.0
	local max_range_deviation_coef = 1.0

	if actual_range_deviation > 0 or actual_angle_deviation > 0 then
		-- find random point inside unit circle, arbitrary picked axis controls range deviation percent, other - angle deviation percent
		local paired_random_values = math2d.position.rotate_vector({storage.generator() * 0.5, 0}, storage.generator() * 360)

		if actual_range_deviation > 0 then
			max_range_deviation_coef = 1 + actual_range_deviation/2
			range_deviation_coef = 1 + paired_random_values.x * actual_range_deviation -- how much we over/under shoot target
		end

		if actual_angle_deviation > 0 then
			local angular_deviation_value = paired_random_values.y * actual_angle_deviation -- how much we miss target

			-- apply angular deviation
			shot_direction = math2d.position.rotate_vector(shot_direction, angular_deviation_value)
		end
	end

	local max_range
	local range
	local base_range, range_modifier, ammo_name, ammo_quality = get_weapon_range_and_ammo_name_and_quality(shooter)

	-- apply range deviation, account for ammo range bonuses - higher bonus, higher the deviation, since bullets don't affect spread
	range = base_range * range_deviation_coef * range_modifier
	max_range = base_range * max_range_deviation_coef * range_modifier


	local spawn_pos = start_pos
	-- Project target point out to max range so the directional shot doesn't stop short
	local end_pos = {
		x = start_pos.x + shot_direction.x * range,
		y = start_pos.y + shot_direction.y * range,
	}

	debug_draw_circle(shooter, shooter.position, { r = 0, g = 0, b = 255}, true, 0.15)
	debug_draw_circle(shooter, event.source_position, { r = 255, g = 0, b = 255}, true, 0.15)
	debug_draw_circle(shooter, end_pos, { r = 255, g = 0, b = 0}, true, 0.15)
	debug_draw_line(shooter, spawn_pos, end_pos, { r = 255, g = 255, b = 0})

	local projectile_speed_deviaton = cfg.projectile_speed_deviaton
	local projectile_speed = cfg.projectile_speed
	if projectile_speed_deviaton > 0 then
		projectile_speed = projectile_speed + (2.0 * storage.generator() - 1.0) * cfg.projectile_speed_deviaton
	end

	-- not using quality variation of projectile, using instead ammo_quality.default_multiplier as base_damage_modifiers
	local tracer = cfg.projectile_override.tracer_name or utils.match_best_tracer(registered_tracers, ammo_name, ammo_source_type_map[shooter.type])
	local base_damage_modifiers = {}
	if ammo_quality then
		base_damage_modifiers = {
			damage_modifier = ammo_quality.default_multiplier
		}
	end

	shooter.surface.create_entity({
			name = tracer,
			position = spawn_pos,
			force = shooter.force,
			source = shooter,
			target = end_pos,
			speed = projectile_speed,
			max_range = range,
			base_damage_modifiers = base_damage_modifiers,
			-- May conflit with other mods :(
			bonus_damage_modifiers = {}
	})
end)
