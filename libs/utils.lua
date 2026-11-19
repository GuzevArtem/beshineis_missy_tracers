if beshineis_tracers_utils then
	return beshineis_tracers_utils
end
local beshineis_tracers_utils_obj = {}


do
---@class projectile_archetype
---@field matching_strings string[]
---@field reference_damage double
---@field explosion_filename string?
---@field animation_filename string
---@field tinted_animation_filename string
---@field light LightDefinition
local projectile_archetype={
}
end



---@param ammo_prototype_name string
---@param source_type AmmoSourceType
---@return string
function beshineis_tracers_utils_obj.generate_tracer_name(ammo_prototype_name, source_type)
	return string.format("visual-tracer-projectile_%s_%s", ammo_prototype_name, source_type)
end

---@param tracers table<string, table<string, string>>
---@param ammo_prototype_name string|nil
---@param source_type AmmoSourceType
---@return string
function beshineis_tracers_utils_obj.match_best_tracer(tracers, ammo_prototype_name, source_type)
	local tracer_name = tracers and ammo_prototype_name and tracers[ammo_prototype_name] and (tracers[ammo_prototype_name][source_type] or tracers[ammo_prototype_name]["default"])

	if not tracer_name then
		error(string.format("No tracer was defined for ammo=\"%s\" with source_type=\"%s\".", ammo_prototype_name, source_type))
	end
	return tracer_name
end

beshineis_tracers_utils = beshineis_tracers_utils_obj
return beshineis_tracers_utils_obj
