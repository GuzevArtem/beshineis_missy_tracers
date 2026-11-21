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
		hidden = not feature_flags["quality"],
		type = "double-setting",
		name = "beshineis_tracers--deviation_coef_reduction_per_quality_level",
		description = "beshineis_tracers--deviation_coef_reduction_per_quality_level",
		setting_type = "startup",
		default_value = 0.1,
		minimum_value = 0,
		maximum_value = 1,
		order = "s0",
		per_user = false,
		localised_description = {
			"mod-setting-description.beshineis_tracers--deviation_coef_reduction_per_quality_level",
			{"mod-setting-name.beshineis_tracers--mode_of_operation"},
			{"string-mod-setting.beshineis_tracers--mode_of_operation-unified"},
			{"mod-setting-name.beshineis_tracers--angle_deviation"},
			{"string-mod-setting.beshineis_tracers--range_deviation"}
		}
	},
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

-- resistances section
	{
		type = "double-setting",
		name = "beshineis_tracers--resistance_tree_flat",
		setting_type = "startup",
		default_value = 2,
		order = "r1f",
		per_user = false
	},
	{
		type = "double-setting",
		name = "beshineis_tracers--resistance_tree_percent",
		setting_type = "startup",
		default_value = 65,
		order = "r1p",
		per_user = false
	},
	{
		type = "double-setting",
		name = "beshineis_tracers--resistance_rock_flat",
		setting_type = "startup",
		default_value = 4,
		order = "r2f",
		per_user = false
	},
	{
		type = "double-setting",
		name = "beshineis_tracers--resistance_rock_percent",
		setting_type = "startup",
		default_value = 75,
		order = "r2p",
		per_user = false
	},
	{
		type = "double-setting",
		name = "beshineis_tracers--resistance_stompershell_flat",
		setting_type = "startup",
		default_value = 4,
		order = "r3f",
		per_user = false
	},
	{
		type = "double-setting",
		name = "beshineis_tracers--resistance_stompershell_percent",
		setting_type = "startup",
		default_value = 75,
		order = "r3p",
		per_user = false
	},

})
