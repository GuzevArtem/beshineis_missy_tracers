A mod that combines misfires with tracers without compromising the individual characteristics of the shooting entity.

Attempted to be as mod-compatible as possible, partially by reusing as many properties as possible from the entity itself, and partially by exposing configurations in the mod-data.

Based on https://mods.factorio.com/mod/ownlys_tracers_21_fork, but was heavily rewritten on the logic side.
The original behaviour can be enabled by choosing "Unified" mode of operation in the mode settings. However, some entities' properties will be lost in that mode.

# Warning
Mod is in an early development stage, and 'API' is expected to change.


# Modes of operations
## Unified
Simplest and performance cheapest. Replaces target_effects for each ammo type with "projectile" that have custom prototype (overridable per ammo type) and misfire settings.
Range is fixed, damage is fixed (no turret or ammo quality bonuses applies).

## Lua
Generates unique projectile for each existing ammo type. Target effects from ammo type is MOVED to target_effects of projectile. Replace cosmetic explosion effect with custom one.
```lua
{
    type = "create-entity",
    name = "explosion-hit"
}
```
Sets ammo type target_effect as "script" with custom event id `"beshineis_tracers_spawn_bullet_projectile_event"`.
On shot script calculates deviation values, selects target entity (if required), extracts full range (`gun/turret range * quality range modifier * ammo range modifier`), extracts ammo damage bonus (only quality default multiplier for now), deduces target position, picks projectile prototype for that ammo, and spawns new projectile.

## [Redacted]
\[Redacted]
TBD

# Other mods compatibility
Should be compatible with most existing mods, except mods that do the same thing. Should not crash, but may not work as expected.

###Potential conflicts:
#### In all modes of operations:
- Mods that changes ammo_type.target_type, since it's necessary setting for proper animations and targetting
- Mods that REPLACES target_deliveries.target_effects, it may overwrite changes made by this one

#### In Mode of Operations=Unified
- Mods that changes ranges of turrets/guns beyond Minimal bullet fly range value. Turret will shoot, but bullets will never reach its target.
- Mods that adds range modifiers for ammo. Will be ignored.

#### In Mode of Operations=Lua
- Mods that applies base_damage_modifiers or bonus_damage_modifiers modifiers. Since both require projectile, there is no clear way to merge projectile setting automatically. Current behavior - both projectiles will spawn.
- Mods that alters turret ranges in unexpected ways. If mod replaces turret with another entity - it is expected to work fine, since script don't care, as long as reference to source_entity stays valid.

#### In Mode of Operations=\[Redacted]
...

# Overrides
During data stage `data.lua` mod exposes structs that can be overriden or extended by other mods.
This done to allow opt-out or customize entity settings by other mods.


### projectile_archetype
Contains settings used for projectile generation.

```lua
{
    type = "mod-data",
    name = "beshineis_tracers--mod_data-projectile_archetypes_overrides",
    data_type = "beshineis_tracers.tracer-settings",
    data = table<string, projectile_archetype>
}
```

```lua
---@class projectile_archetype
---@field matching_strings table<string>
---@field reference_damage double
---@field piercing_damage double?
---@field explosion_prototype_name string?
---@field animation_filename string
---@field tinted_animation_filename string?
---@field light LightDefinition
local projectile_archetype={
}
```
### default_projectile_prototype
Projectile prototype template

```lua
---@type ProjectilePrototype
local default_projectile_prototype = {
    type = "projectile",
    name = "visual-tracer-projectile-prototype-should-not-be-registered", -- will be adjusted per ammo_type
    flags = {"not-on-map"},
    hit_at_collision_position = true,
    height = 1,
    force_condition = "not-same",
    collision_box = { { -0.45 * projectile_collision_scale, -0.3}, { 0.45 * projectile_collision_scale + 0.5, 0.3} },
    hit_collision_mask = {
        layers = { object = true, player = true, trigger_target = true, train = true}, -- will contain flying=true if relevant collision layer exists
        not_colliding_with_itself = true
    },
    direction_only = true,
    piercing_damage = 0, -- will be set from archetype (if present) or generated for 'piercing' ammo
    acceleration = tonumber(settings.startup["beshineis_tracers--acceleration"].value) or 0,
    animation = {
        filename = "__beshineis_missy_tracers__/graphics/railgun-beam-yv.png", -- to be replaced from archetype
        priority = "extra-high",
        width = 16,
        height = utils.projectile_animation_height_px, -- 496
        frame_count = 17,
        animation_speed = 1,
        draw_as_glow = true,
        blend_mode = "additive",
        shift = {0, utils.projectile_animation_shift_y}, -- offset to compensate for trail not yet present on the first frame. In tiles.
        rotate_shift = true, -- since we compensating for animation offset, we should align it with fire direction
        scale = 1,
    },
    light = {intensity = 0.5, size = 4, color = {r = 1, g = 0.8, b = 0.4} }, -- to be replaced from archetype
    action = nil -- to be populated during projectile generation phase
}
```

```lua
{
    type = "mod-data",
    name = "beshineis_tracers--mod_data-tracer_template",
    data_type = "beshineis_tracers.tracer-template",
    data = default_projectile_prototype
}
```

### entity_deviation_coef_map
Simplified configuration to adjust deviation scale per entity.
Exact name (or pattern) = deviation scale

```lua
-- example
entity_deviation_coef_map["gun-turret"] = 2.0
entity_deviation_coef_map[".*sniper.*"] = 0.01
```

```lua
{
    type = "mod-data",
    name = "beshineis_tracers--mod_data-entity_deviation_override_map",
    data_type = "beshineis_tracers.entity_deviation_override",
    data = entity_deviation_coef_map
}
```

### default_entity_configuration/entity_configuration_overrides

Final configuration that will be applied for each entity.
Exact entity prototype name - configuration.
Default values (if available) are settup through mod settings.
During `data-final-fixes.lua` deviations (range and angle) are scaled by entity_deviation_coef_map (for found matched entities), that will create new configurations or alter existing for matched entities.
In `control.lua` that data is applied during projectile spawn.

```
I'm not happy with data structure, so it is a subject to change
```

```lua
{
    type = "mod-data",
    name = "beshineis_tracers--mod_data-entity_configuration_overrides",
    data_type = "beshineis_tracers.entity_configuration",
    data = { default = default_entity_configuration }
}
```


# TODO
* Check damage bonuses from shooting entity (seems to be ignored)
* Check damage scale with research (Same thing)
* Replace thumbnail with a unique one
* Redraw/extend library of tracers. (Currently missing blue-plutonium and purple-tungsten variations from common mods)
* Handle character/characters guns explicitly - give them suitable defaults, so player won't shoot from its stomach.

# Wishlist
* Find a way to make player_targeting "runtime-per-player" setting, keeping turrets(vehicles?) as startup.
* Support skins, in the way that projectile spawn position could/will be adjusted for skins with gun location that differs from vanilla
* Create satelite mod(s), that exposes individual configurations. Only these satellite mods will handle modded entities explicitly, but those mods require a settings generator of some kind. (As in Better Planets). Mods needed for: tracer settings per ammo; projectile/shell/deviation settings per gun(including vehicle gun's)/turret/armor(or 'naked' engineer)
* Add third mode of operation - codename [Redacted]. It will create more prototypes, but should be practically without events at runtime. (Only callbacks for events that require entity swapping)

# Known issues
* Misaligned projectiles - figuring out how to properly set up projectile creation properties. Default source posiotion seems to be not exactly correct.
* Misaligned 'miss' effects - if nothing was hit, bullet will 'explode' 1-2 tiles farther, then at the actual hit position, giving the wrong expectation of range.
* Missing documentation on overridable mod-data (only some comments in code)
