if beshineis_tracers_utils then
	return beshineis_tracers_utils
end
local beshineis_tracers_utils_obj = {}


do
---Set of settings applied to any projectile created for ammo_prototype_name with name matching matching_strings
---@class projectile_archetype
---
---List of patterns to be found in ammo_prototype_name
---@field matching_strings table<string>
---
---Damage that will be set as base projectile damage, if ammo_prototype has none
---@field reference_damage double
---
---Piercing damage. If not provided it will be calculated as a scaled actual damage for ammo_prototype containing 'piercing' in its name
---@field piercing_damage double?
---
---Name of prototype that will be used as 'cosmetic' effect on hit.
---@field explosion_prototype_name string?
---
---Path to animation file. Some values are hardcoded for now:
---width = 16,
-- height = 496,
-- frame_count = 17,
-- shift - calculated from height
---
---@field animation_filename string
---
---Path to animation file (used for shotgun pellets). Some values are hardcoded for now:
---width = 16,
-- height = 496,
-- frame_count = 17,
-- shift - calculated from height
--
---@field tinted_animation_filename string?
---
---Projectile light settings
---
---@field light LightDefinition
---
local projectile_archetype={
}
end

beshineis_tracers_utils_obj.using_quality = (helpers.stage == "runtime" and script.feature_flags["quality"]) or (helpers.stage ~= "runtime" and feature_flags["quality"]) or false
---@type QualityName
beshineis_tracers_utils_obj.stub_quality = "quality_unknown"
-- empty if quality is absent
local deviation_scale_per_quality = {
	quality_unknown = 1, -- stub if quality not present
}

---@param quality_name QualityName
function beshineis_tracers_utils_obj.deviation_coef_for(quality_name)
	return deviation_scale_per_quality[quality_name] or 1
end

do -- prepare quality table
	local deviation_coef_reduction_per_quality_level = 0

	---@param quality_name string
	---@param quality QualityPrototype
	local function prepare_quality(quality_name, quality)
		deviation_scale_per_quality[quality_name] = 1 - math.max(0, math.min(1, quality.level * deviation_coef_reduction_per_quality_level))
	end

	if beshineis_tracers_utils_obj.using_quality and helpers.stage ~= "settings" then
		deviation_coef_reduction_per_quality_level = tonumber(settings.startup["beshineis_tracers--deviation_coef_reduction_per_quality_level"].value) or 0
		if deviation_coef_reduction_per_quality_level > 0 then
			if helpers.stage == "prototype" then
				for name, quality in pairs(data.raw["quality"]) do
					prepare_quality(name, quality)
				end
			elseif helpers.stage == "runtime" then
				for name, quality in pairs(prototypes.quality) do
					prepare_quality(name, quality)
				end
			end
		end
	end
end


---@param ammo_prototype_name string
---@param source_type AmmoSourceType
---@return string
function beshineis_tracers_utils_obj.generate_tracer_name(ammo_prototype_name, source_type)
	return string.format("visual-tracer-projectile_%s_%s", ammo_prototype_name, source_type)
end

---@param tracers table<string, table<string, string>>
---@param ammo_prototype_name string?
---@param source_type AmmoSourceType
---@return string
function beshineis_tracers_utils_obj.match_best_tracer(tracers, ammo_prototype_name, source_type)
	local tracer_name = tracers and ammo_prototype_name and tracers[ammo_prototype_name] and (tracers[ammo_prototype_name][source_type] or tracers[ammo_prototype_name]["default"])
	if not tracer_name then
		error(string.format("No tracer was defined for ammo=\"%s\" with source_type=\"%s\".", ammo_prototype_name, source_type))
	end
	return tracer_name
end

---@type table<CollisionLayerID, boolean>
beshineis_tracers_utils_obj.projectile_collision_mask = {
	object = true,
	player = true,
	trigger_target = true,
	train = true
}

---@type table<CollisionLayerID, boolean>
beshineis_tracers_utils_obj.projectile_collision_mask_inverted = {}

do -- generate inverted projectile_collision_mask
	if helpers.stage == "prototype" then
		-- "flying" is non vanilla, so we need to be sure, before adding potentially non-existing layer
		if data.raw["collision-layer"] and data.raw["collision-layer"]["flying"] then
			beshineis_tracers_utils_obj.projectile_collision_mask["flying"] = true
		end

		for name, _ in pairs(data.raw["collision-layer"]) do
			if not beshineis_tracers_utils_obj.projectile_collision_mask[name] then
				beshineis_tracers_utils_obj.projectile_collision_mask_inverted[name] = true
			end
		end
	elseif helpers.stage == "runtime" then
		-- "flying" is non vanilla, so we need to be sure, before adding potentially non-existing layer
		if prototypes.collision_layer and prototypes.collision_layer["flying"] then
			beshineis_tracers_utils_obj.projectile_collision_mask["flying"] = true
		end

		for name, _ in pairs(prototypes.collision_layer) do
			if not beshineis_tracers_utils_obj.projectile_collision_mask[name] then
				beshineis_tracers_utils_obj.projectile_collision_mask_inverted[name] = true
			end
		end
	end
end

---@type table<ForceID>
beshineis_tracers_utils_obj.non_targetable_forces = {
	"neutral"
}

---@type table<ForceID>
beshineis_tracers_utils_obj.targetable_forces = {
	"enemy"
}

do -- invert forces
	-- only runtime knows all forces
	if helpers.stage == "runtime" then
		script.on_event(defines.events.on_force_created, function(event)
			beshineis_tracers_utils_obj.targetable_forces[#beshineis_tracers_utils_obj.targetable_forces + 1] = event.force.name
		end)
	end
end

function beshineis_tracers_utils_obj.on_init()
	beshineis_tracers_utils_obj.non_targetable_forces = {}
	for name, _ in pairs(game.forces) do
		for non_name, _ in ipairs(beshineis_tracers_utils_obj.non_targetable_forces) do
			if non_name == name then
				break
			end
			beshineis_tracers_utils_obj.targetable_forces[#beshineis_tracers_utils_obj.targetable_forces + 1] = name
		end
	end
end

if helpers.stage == "runtime" then
	script.on_init(beshineis_tracers_utils_obj.on_init)
end

---@param force ForceID
function beshineis_tracers_utils_obj.get_targetable_forces_for(force)
	local result = { table.unpack(beshineis_tracers_utils_obj.targetable_forces) }
	for index, name in ipairs(result) do
		if name == force then
			table.remove(result, index)
			break
		end
	end
	return result
end

do
	local tracer_length_scale = tonumber(settings.startup["beshineis_tracers--tracer_length_scale"].value) or 0.5

	beshineis_tracers_utils_obj.projectile_animation_height_px = tracer_length_scale * 496
	local projectile_animation_height_tiles = beshineis_tracers_utils_obj.projectile_animation_height_px / 32 -- in tiles
	beshineis_tracers_utils_obj.projectile_animation_shift_y = projectile_animation_height_tiles / 2 or 0
end

beshineis_tracers_utils = beshineis_tracers_utils_obj
return beshineis_tracers_utils_obj
