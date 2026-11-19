local utils = require("libs/utils")
local math2d = require("math2d")

-- "unified", "projectile_spawner", "hidden_turret"
local mode_of_operation = settings.startup["beshineis_tracers--mode_of_operation"].value
if mode_of_operation ~= "projectile_spawner" then
	--early return, since no need for this logic
	return
end

local debug = (settings.startup["beshineis_tracers--debug"] or { value = false }).value

local player_targeting = settings.startup["beshineis_tracers--player_targeting"].value
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
local prediction_overshoot_ticks = settings.startup["beshineis_tracers--prediction_overshoot_ticks"].value or 0

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

local function get_ammo_range_bonus_and_ammo_name(entity, selected_inventory_index)
	local inv_define = ammo_inventory_map[entity.type]
	if not inv_define then
		return 1.0, nil
	end

	local ammo_inventory = entity.get_inventory(inv_define)

	if not ammo_inventory then
		return 1.0, nil
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
		return 1.0, nil
	end

	local ammo_name = ammo_stack.name
	local ammo_type = ammo_stack.prototype.get_ammo_type(ammo_source_type_map[entity.type] or "default")
	if ammo_type and ammo_type.range_modifier then
		return ammo_type.range_modifier, ammo_name
	end

	return 1.0, ammo_name
end

---@param entity LuaEntity
---@return double, double, string|nil
local function get_weapon_range_and_ammo_name(entity)
	local base_range = 0.0
	local range_mod = 1
	local ammo_name = nil

	if not entity or not entity.valid then
		return base_range, range_mod, ammo_name
	end

	if entity.prototype.attack_parameters and entity.prototype.attack_parameters.range then
		-- turrets should sink here
		base_range = entity.prototype.attack_parameters.range

		-- account for ammo bonuses
		range_mod, ammo_name = get_ammo_range_bonus_and_ammo_name(entity, nil)
	end

	if ammo_source_type_map[entity.type] ~= "turret" then
		-- player or vehicle
		local gun_inv = entity.get_inventory(defines.inventory.character_guns)
		if not gun_inv then
			return base_range, range_mod, ammo_name
		end

		local gun_stack = gun_inv[entity.selected_gun_index]

		if not gun_stack or not gun_stack.valid_for_read then
			return base_range, range_mod, ammo_name
		end

		base_range = gun_stack.prototype.attack_parameters.range

		-- account for ammo bonuses
		range_mod, ammo_name = get_ammo_range_bonus_and_ammo_name(entity, entity.selected_gun_index)
	end

	return base_range, range_mod, ammo_name
end

script.on_event(defines.events.on_script_trigger_effect, function(event)
	if event.effect_id ~= "beshineis_tracers--spawn-bullet-projectile" then
		return
	end

	local shooter = event.source_entity
	if not shooter or not shooter.valid then
		return
	end

	---@param position ScriptRenderTarget
	---@param color Color
	---@param solid boolean|nil
	---@param size double|nil in tiles
	---@param thickness double|nil only if not solid, in pixels
	local debug_draw_circle = function(position, color, solid, size, thickness)
		if debug and position then rendering.draw_circle({
			color = color, -- {r = 1, g = 0, b = 0, a = 0.8}
			radius = size or 1, -- tiles
			width = thickness or 2, -- pixels
			filled = solid or true,
			target = position,
			surface = shooter.surface or game.player.surface,
			time_to_live = 60,  -- in ticks
			forces = { shooter.force.index }
		}) end
	end
	---@param start ScriptRenderTarget
	---@param finish ScriptRenderTarget
	---@param color Color
	---@param thickness double|nil only if not solid, in pixels
	local debug_draw_line = function(start, finish, color, thickness)
		if debug and start and finish then rendering.draw_line({
			color = color, -- {r = 1, g = 0, b = 0, a = 0.8}
			from = start,
			to = finish,
			width = thickness or 2, -- pixels
			surface = shooter.surface or game.player.surface,
			time_to_live = 60,  -- in ticks
			forces = { shooter.force.index },
			draw_on_ground = true
		}) end
	end

	local cfg = entity_configurations[shooter.name] or entity_configurations["default"]

	-- event.source_position should already contain barrel_offset
	local start_pos = event.source_position or shooter.position

	-- shot direction vectror components
	local nx, ny

	do
		--[[ one day this setting will be runtime...
		if shooter.player and not per_player_targeting_setting_map[shooter.player.index] then
			per_player_targeting_setting_map[shooter.player.index] = settings.get_player_settings(shooter.player)["beshineis_tracers--player_targeting"].value
		end
		]]

		-- Determine target coordinates
		local target_pos
		-- per_player_targeting_setting_map[shooter.player.index] == "directional"
		if shooter.type == "character" and shooter.player and player_targeting == "directional" then
			if not shooter.shooting_state.state then
				return
			end
			target_pos = shooter.shooting_state.position
		else
			local target_entity = event.target_entity
			if target_entity == shooter then
				target_entity = shooter.shooting_target
			end

			target_pos = (target_entity and target_entity.position) or event.target_position
			if not target_pos then
				return
			end

			if target_entity and mode_of_operation ~= "unified" and cfg.projectile_speed > 0 then
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
					local flight_time = distance / cfg.projectile_speed + prediction_overshoot_ticks -- deliberatly using average speed for prediction

					target_pos.x = target_pos.x + (vx * flight_time)
					target_pos.y = target_pos.y + (vy * flight_time)
				end
			end
		end

		local dx = target_pos.x - start_pos.x -- horizontal offset to target
		local dy = target_pos.y - start_pos.y -- vertical offset to target
		local dist = math.sqrt(dx * dx + dy * dy)

		if dist > 0 then
			-- Normalized direction vector
			nx = dx / dist
			ny = dy / dist
		else
			-- fallback to shooter orientation
			nx = math.sin(shooter.orientation * 2 * math.pi)
			ny = -math.cos(shooter.orientation * 2 * math.pi)
		end
	end

	-- Deviation calculation
	local range_deviation_coef = 1.0
	local max_range_deviation_coef = 1.0
	if cfg.range_deviation and cfg.range_deviation > 0 then
		max_range_deviation_coef = 1 + cfg.range_deviation/2

		if cfg.direction_deviation and cfg.direction_deviation > 0 then
			-- find random point inside unit circle, arbitrary picked axis controls range deviation percent, other - angle deviation percent
			local paired_random_values = math2d.position.rotate_vector({storage.generator() * 0.5, 0}, storage.generator() * 360)
			range_deviation_coef = 1 + paired_random_values.x * cfg.range_deviation -- how much we over/under shoot target

			local angular_deviation_value = paired_random_values.y * cfg.direction_deviation -- how much we miss target

			-- apply angular deviation
			local angular_deviation = math2d.position.rotate_vector({nx, ny}, angular_deviation_value)
			nx = angular_deviation.x
			ny = angular_deviation.y
		end
	end

	local max_range
	local range
	local base_range, range_modifier, ammo_name = get_weapon_range_and_ammo_name(shooter)

	-- apply range deviation, account for ammo range bonuses - higher bonus, higher the deviation, since bullets don't affect spread
	range = base_range * range_deviation_coef * range_modifier
	max_range = base_range * max_range_deviation_coef * range_modifier


	local spawn_pos = start_pos
	-- Project target point out to max range so the directional shot doesn't stop short
	local end_pos = {
		x = start_pos.x + nx * range,
		y = start_pos.y + ny * range,
	}

	debug_draw_circle(shooter.position, { r = 0, g = 0, b = 255}, true, 0.15)
	debug_draw_circle(event.source_position, { r = 255, g = 0, b = 255}, true, 0.15)
	debug_draw_circle(end_pos, { r = 255, g = 0, b = 0}, true, 0.15)
	debug_draw_line(spawn_pos, end_pos, { r = 255, g = 255, b = 0})

	local projectile_speed_deviaton = cfg.projectile_speed_deviaton
	local projectile_speed = cfg.projectile_speed
	if projectile_speed_deviaton > 0 then
		projectile_speed = projectile_speed + (2.0 * storage.generator() - 1.0) * cfg.projectile_speed_deviaton
	end

	local tracer = cfg.projectile_override.tracer_name or utils.match_best_tracer(registered_tracers, ammo_name, ammo_source_type_map[shooter.type])

	shooter.surface.create_entity({
			name = tracer,
			position = spawn_pos,
			force = shooter.force,
			source = shooter,
			target = end_pos,
			speed = projectile_speed,
			max_range = range,
			-- propagate values below from ammo?
			base_damage_modifiers = {},
			bonus_damage_modifiers = {}
	})
end)
