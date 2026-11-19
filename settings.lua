data:extend({
-- hidden settings first
	{
		hidden = true,
		type = "double-setting",
		name = "beshineis_tracers--acceleration",
		setting_type = "startup",
		default_value = 0.0,
		minimum_value = -0.1,
		maximum_value = 0.1,
		order = "h1",
		per_user = false
	},
	{
		hidden = true,
		forced_value = true,
		type = "double-setting",
		name = "beshineis_tracers--speed",
		setting_type = "startup",
		default_value = 1.85,
		minimum_value = 0.5,
		maximum_value = 4.0,
		order = "h2",
		per_user = false,
	},
	{
		hidden = true,
		type = "double-setting",
		name = "beshineis_tracers--speed_deviation",
		setting_type = "startup",
		default_value = 0.15,
		minimum_value = 0.0,
		maximum_value = 1.0,
		order = "h2",
		per_user = false
	},
	{
		hidden = true,
		type = "double-setting",
		name = "beshineis_tracers--scale",
		setting_type = "startup",
		default_value = 0.5,
		minimum_value = 0.1,
		maximum_value = 3,
		order = "h3",
		per_user = false
	},
	{
		hidden = true,
		type = "int-setting",
		name = "beshineis_tracers--brackets_count",
		setting_type = "startup",
		default_value = 10,
		minimum_value = 4,
		maximum_value = 16,
		order = "h4",
		per_user = false
	},

-- startup

	{
		type = "string-setting",
		name = "beshineis_tracers--special_entity_deviation_coef",
		description = "beshineis_tracers--special_entity_deviation_coef",
		setting_type = "startup",
		default_value = "",
		allow_blank = true,
		order = "s1",
		per_user = false,
		localised_description = {
			"mod-setting-description.beshineis_tracers--special_entity_deviation_coef",
			{"mod-setting-name.beshineis_tracers--mode_of_operation"},
			{"string-mod-setting.beshineis_tracers--mode_of_operation-unified"}
		}
	},
	{
		type = "double-setting",
		name = "beshineis_tracers--angle_deviation",
		setting_type = "startup",
		default_value = 3.0,
		minimum_value = 0.0,
		maximum_value = 180.0,
		order = "s3",
		per_user = false
	},
	{
		type = "double-setting",
		name = "beshineis_tracers--range_deviation",
		setting_type = "startup",
		default_value = 0.15,
		minimum_value = 0.0,
		maximum_value = 1.0,
		order = "s4",
		per_user = false
	},
	{
		type = "int-setting",
		name = "beshineis_tracers--minimal_bullet_range",
		setting_type = "startup",
		default_value = 15,
		minimum_value = 1,
		maximum_value = 100,
		order = "s5",
		per_user = false,
		localised_description = {
			"mod-setting-description.beshineis_tracers--minimal_bullet_range",
			{"mod-setting-name.beshineis_tracers--mode_of_operation"},
			{"string-mod-setting.beshineis_tracers--mode_of_operation-unified"},
			{"mod-setting-name.beshineis_tracers--range_deviation"}
		}
	},
	{
		type = "double-setting",
		name = "beshineis_tracers--collision_scale",
		setting_type = "startup",
		default_value = 1,
		minimum_value = 0.01,
		maximum_value = 30,
		order = "s6",
		per_user = false
	},
	{
		type = "string-setting",
		name = "beshineis_tracers--player_targeting",
		setting_type = "startup",
		default_value = "directional",
		allowed_values = {
			"directional",
			"entity_leading",
			"entity",
			"vanilla"
		},
		order = "s8",
		per_user = true,
		localised_description = {
			"mod-setting-description.beshineis_tracers--player_targeting",
			{"mod-setting-name.beshineis_tracers--mode_of_operation"},
			{"string-mod-setting.beshineis_tracers--mode_of_operation-unified"}
		}
	},
	{
		type = "int-setting",
		name = "beshineis_tracers--prediction_overshoot_ticks",
		setting_type = "startup",
		default_value = 0,
		minimum_value = -1000,
		maximum_value = 1000,
		order = "s9",
		per_user = false
	},
	{
		type = "double-setting",
		name = "beshineis_tracers--magazine_size_modifier",
		setting_type = "startup",
		default_value = 1.75,
		minimum_value = 0.0,
		maximum_value = 100,
		order = "s10",
		per_user = false
	},
	{
		type = "string-setting",
		name = "beshineis_tracers--mode_of_operation",
		setting_type = "startup",
		default_value = "projectile_spawner",
		allowed_values = {
			"unified",
			"projectile_spawner",
			-- "hidden_turret"
		},
		order = "s11",
		per_user = false
	},

	-- runtime
	{
		type = "bool-setting",
		name = "beshineis_tracers--debug",
		setting_type = "startup",
		default_value = true, -- TODO: remove?
		order = "z99",
		per_user = true
	},

})
