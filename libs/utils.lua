if beshineis_tracers_utils then
	return beshineis_tracers_utils
end
local beshineis_tracers_utils_obj = {}


do
---@class projectile_archetype
---@field matching_strings table<string>
---@field reference_damage double
---@field piercing_damage double?
---@field explosion_filename string?
---@field animation_filename string
---@field tinted_animation_filename string?
---@field light LightDefinition
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
---@return string?
function beshineis_tracers_utils_obj.match_best_tracer(tracers, ammo_prototype_name, source_type)
	return tracers and ammo_prototype_name and tracers[ammo_prototype_name] and (tracers[ammo_prototype_name][source_type] or tracers[ammo_prototype_name]["default"])
end



beshineis_tracers_utils = beshineis_tracers_utils_obj
return beshineis_tracers_utils_obj
