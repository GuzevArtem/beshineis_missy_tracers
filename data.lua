require("prototypes/explosions")
local utils = require("libs/utils")

do -- projectile configurations
	local projectile_collision_scale = tonumber(settings.startup["beshineis_tracers--collision_scale"].value) or 1

	---@type ProjectilePrototype
	local default_projectile_prototype = {
		type = "projectile",
		name = "visual-tracer-projectile-prototype-should-not-be-registered", -- will be adjusted per ammo_type
		flags = {"not-on-map"},
		hit_at_collision_position = true,
		height = 1,
		force_condition = "not-same",--"not-friend",--
		collision_box = { { -0.45 * projectile_collision_scale, -0.3}, { 0.45 * projectile_collision_scale + 0.5, 0.3} },
		hit_collision_mask = {
			layers = utils.projectile_collision_mask,
			not_colliding_with_itself = true
		},
		direction_only = true,
		piercing_damage = 0,
		acceleration = tonumber(settings.startup["beshineis_tracers--acceleration"].value) or 0,
		animation = {
			filename = "__beshineis_missy_tracers__/graphics/railgun-beam-yv.png",
			priority = "extra-high",
			width = 16,
			height = utils.projectile_animation_height_px,
			frame_count = 17,
			animation_speed = 1,
			draw_as_glow = true,
			blend_mode = "additive",
			shift = {0, utils.projectile_animation_shift_y}, -- offset to compensate for trail not yet present on the first frame. In tiles.
			rotate_shift = true, -- since we compensating for animation offset, we should align it with fire direction
			scale = 1,
		},
		light = {intensity = 0.5, size = 4, color = {r = 1, g = 0.8, b = 0.4} },
		action = nil -- to be populated on generation phase
	}


	--- @type table<string, projectile_archetype>
	local archetypes_map = {}
	archetypes_map["unknown"] = {
		matching_strings = { },
		reference_damage = 0,
		piercing_damage = 0,
		explosion_filename = "visual-tracer-explosion-hit-normal",
		animation_filename = "__beshineis_missy_tracers__/graphics/railgun-beam-yv.png",
		tinted_animation_filename = "__beshineis_missy_tracers__/graphics/railgun-beam-y.png",
		light = {intensity = 0.5, size = 4, color = {r = 1, g = 0.8, b = 0.4} }
	}
	archetypes_map["normal"] = {
		matching_strings = { "firearm-magazine" },
		reference_damage = 5,
		piercing_damage = 0,
		explosion_filename = "visual-tracer-explosion-hit-normal",
		animation_filename = "__beshineis_missy_tracers__/graphics/railgun-beam-yv.png",
		tinted_animation_filename = "__beshineis_missy_tracers__/graphics/railgun-beam-y.png",
		light = {intensity = 0.5, size = 4, color = {r = 1, g = 0.8, b = 0.4} }
	}
	archetypes_map["piercing"] = {
		matching_strings = {"piercing-rounds-magazine", "piercing"},
		reference_damage = 8,
		explosion_filename = "visual-tracer-explosion-hit-piercing",
		animation_filename = "__beshineis_missy_tracers__/graphics/railgun-beam-rv.png",
		tinted_animation_filename = "__beshineis_missy_tracers__/graphics/railgun-beam-r.png",
		light = {intensity = 0.6, size = 4, color = {r = 1, g = 0.6, b = 0.3} }
	}
	archetypes_map["uranium"] = {
		matching_strings = {"uranium-rounds-magazine", "uranium"},
		reference_damage = 24,
		explosion_filename = "visual-tracer-explosion-hit-uranium",
		animation_filename = "__beshineis_missy_tracers__/graphics/railgun-beam-gv.png",
		tinted_animation_filename = "__beshineis_missy_tracers__/graphics/railgun-beam-g.png",
		light = {intensity = 0.6, size = 4, color ={r = 0.7, g = 1, b = 0.5} }
	}
	archetypes_map["plutonium"] = {
		matching_strings = {"plutonium-rounds-magazine", "plutonium"},
		reference_damage = 48, -- from ceres
		explosion_filename = "visual-tracer-explosion-hit-normal",
		animation_filename = "__beshineis_missy_tracers__/graphics/railgun-beam-gv.png", -- TODO: need blue variation
		tinted_animation_filename = "__beshineis_missy_tracers__/graphics/railgun-beam-g.png",
		light = {intensity = 0.6, size = 4, color = {r = 0.3, g = 0.3, b = 1.0} }
	}
	archetypes_map["promethium"] = {
		matching_strings = {"promethium-rounds-magazine", "promethium"},
		reference_damage = 48, -- from Nexus
		explosion_filename = "visual-tracer-explosion-hit-normal",
		animation_filename = "__beshineis_missy_tracers__/graphics/railgun-beam-rv.png",
		tinted_animation_filename = "__beshineis_missy_tracers__/graphics/railgun-beam-r.png",
		light = {intensity = 0.6, size = 4, color = {r = 1.0, g = 0.15, b = 0.5} }
	}
	archetypes_map["tungsten"] = {
		matching_strings = {"tungsten-rounds-magazine", "tungsten"},
		reference_damage = 16, -- from tungsten-ammo mod
		explosion_filename = "visual-tracer-explosion-hit-normal",
		animation_filename = "__beshineis_missy_tracers__/graphics/railgun-beam-gv.png", -- TODO: need purple variation
		tinted_animation_filename = "__beshineis_missy_tracers__/graphics/railgun-beam-g.png",
		light = {intensity = 0.6, size = 4, color = {r = 0.4, g = 0.1, b = 0.45} }
	}
	--[[
	MOD AMMO EXTENSTION POINT
	Just adjust string matching and add base tracer_prototype if needed
	Or override prototype below
	]]--

	--expose tracer prototype template
	data:extend({
		{
			type = "mod-data",
			name = "beshineis_tracers--mod_data-tracer_template",
			data_type = "beshineis_tracers.tracer-template",
			data = default_projectile_prototype
		}
	})

	-- expose tracer archetypes, so it can be modified/extended by other mods
	data:extend({
		{
			type = "mod-data",
			name = "beshineis_tracers--mod_data-tracer_settings",
			data_type = "beshineis_tracers.tracer-settings",
			data = archetypes_map
		}
	})
end

do -- entity configurations
	local default_entity_configuration = {
		projectile_override = {
			tracer_name = nil,
			height = nil, -- 1 how much 'above' ground projectile sprite is offset. In tiles?
			projectile_center = nil, --{ x = 0.0, y = 0.0}, -- shift rotation pivot from turret position (for off axis turrets mostly)
			projectile_creation_distance = nil, --0.0, -- shift projectile along turret orientation from projectile_center
			projectile_orientation_offset = nil, --0.0,
			true_collinear_ejection = nil, --true, -- auto orient along shooting direction
			use_shooter_direction = nil, --false,
			apply_projection_to_projectile_creation_position = nil, --false,
		},

		shell_particle_override = { -- CircularParticleCreationSpecification
			center = nil, --{ x = 0.0, y = 0.0}, -- shift rotation pivot from turret position (usually same as projectile_center)
			creation_distance = nil, --{ x = 0.0, y = 0.0}, -- shift projectile along turret orientation from projectile_center
			creation_distance_orientation = nil, -- 0.0
			direction = nil, --0.0, -- direction of shell ejection relative to barrel orientation [0, 1), 0 - forward, 0.25 - right, 0.5 - backwards, 0.75 - left
			angle_deviation = nil, --0.0
			height = nil, --0.0, -- height of shell above ground when spawned
			height_deviation = nil, --0.0
			--name = nil, -- no shell overrides for now
			speed = nil, --0.0
			speed_deviation = nil, --0.0
			starting_frame_speed = nil, --0.0
			starting_frame_speed_deviation = nil, --0.0
			use_source_position = nil, --false
			vertical_speed = nil, --0.0
			vertical_speed_deviation = nil, --0.0
		},

		-- only for runtime
		projectile_speed = settings.startup["beshineis_tracers--speed"].value or 1.85, -- in tiles per second
		projectile_speed_deviaton = settings.startup["beshineis_tracers--speed_deviation"].value or 0.15, -- in tiles per second
		range_deviation = settings.startup["beshineis_tracers--range_deviation"].value or 0.15, -- coefficient
		angle_deviation = settings.startup["beshineis_tracers--angle_deviation"].value or 3, -- in degrees
	}

	-- expose full preparsed configuration for mods to edit
	data:extend({
		{
			type = "mod-data",
			name = "beshineis_tracers--mod_data-entity_configuration_overrides",
			data_type = "beshineis_tracers.entity_configuration",
			data = { default = default_entity_configuration }
		}
	})
end

do -- entity deviation coefficient preparsed (not expected, but may be edited by other mods)
	local entity_deviation_coef_map = {}

	local entity_deviation_coef_str = settings.startup["beshineis_tracers--special_entity_deviation_coef"].value
	if entity_deviation_coef_str then
		for entity_name_pattern, deviation_coefficient in string.gmatch(tostring(entity_deviation_coef_str), "([^:;]+):([%d%.]+)") do
			local num = tonumber(deviation_coefficient)
			if num ~= nil and num == num and math.abs(num) ~= math.huge then
				-- don't check entityid, since it may not yer be registered
				entity_deviation_coef_map[entity_name_pattern] = num
			else
				error(string.format("Corrupted configuration for entity name \"%s\". Coefficient is not a valid number %f", entity_name_pattern, num))
			end
		end
	end

	-- expose raw configuration for overrides
	data:extend({
		{
			type = "mod-data",
			name = "beshineis_tracers--mod_data-entity_deviation_override_map",
			data_type = "beshineis_tracers.entity_deviation_override",
			data = entity_deviation_coef_map
		}
	})
end

-- append custom-event
data:extend({
	{
		type = "custom-event",
		name = "beshineis_tracers_spawn_bullet_projectile_event"
	}
})
