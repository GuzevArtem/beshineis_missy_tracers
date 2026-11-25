A mod that combines misfires with tracers without compromising the individual characteristics of the shooting entity.

Attempted to be as mod-compatible as possible, partially by reusing as many properties as possible from the entity itself, and partially by exposing configurations in the mod-data.

Based on https://mods.factorio.com/mod/ownlys_tracers_21_fork, but was heavily rewritten on the logic side.
The original behaviour can be enabled by choosing "Unified" mode of operation in the mode settings. However, some entities' properties will be lost in that mode, as well as quality effects.

# Warning
Mod is in an early development stage, and 'API' is expected to change.


# Modes of operations
The mod features a few different modes it can run in.
Modes ultimately change behaviour, which could lead to gameplay and/or underlying implementation changes, causing some modes to be incompatible with other mods.
> In the future, I hope to find a silver bullet implementation and drop all other modes, but it is a long way from now.

> Recommended mode of operations - LUA, it provides the least compromises, but may be demanding in the late game (due to sheer number of projectiles created per frame)

## Unified
Simplest and performance-wise cheapest. Replaces target_effects for each ammo type with "projectile" that has a custom prototype (overridable per ammo type) and misfire settings.
Range is fixed, damage is fixed (no turret or ammo quality bonuses apply).

## Lua
Generates a unique projectile for each existing ammo type. Target effects from the ammo type is MOVED to the target_effects of the projectile. Replaces the cosmetic explosion effect with a custom one.
```lua
{
    type = "create-entity",
    name = "explosion-hit"
}
```
Sets ammo type target_effect as "script" with custom event id `"beshineis_tracers_spawn_bullet_projectile_event"`.
On shot, the script calculates deviation values, selects target entity (if required), extracts full range (`gun/turret range * quality range modifier * ammo range modifier`), extracts ammo damage bonus (only quality default multiplier for now), deduces target position, picks projectile prototype for that ammo, and spawns a new projectile.

## [Redacted]
\[Redacted]
TBD

# Other mods compatibility
Should be compatible with most existing mods, except mods that do the same thing. Should not crash, but may not work as expected.

###Potential conflicts:
#### In all modes of operation:
- Mods that change ammo_type.target_type, since it's a necessary setting for proper animations and targeting
- Mods that REPLACE target_deliveries.target_effects, it may overwrite changes made by this one

#### In Mode of Operations=Unified
- Mods that change ranges of turrets/guns beyond the Minimal bullet fly range value. Turret will shoot, but bullets will never reach its target.
- Mods that add range modifiers for ammo. Will be ignored.

#### In Mode of Operations=Lua
- Mods that apply base_damage_modifiers or bonus_damage_modifiers. Since both require a target effect with type="script", there is no clear way to merge those specific projectile creation settings automatically. Current behaviour: both projectiles will spawn, potentially hitting the target twice.
- Mods that alter turret ranges in unexpected ways. If a mod replaces a turret with another entity, it is expected to work fine, since scripts don't care, as long as the reference to source_entity stays valid.

#### In Mode of Operations=\[Redacted]
...

# Overrides
During the data stage `data.lua` mod exposes structs that can be overridden or extended by other mods.
This lets other mods opt out or customise entity settings. Since some logic is stored in ammo prototypes - it is impossible to opt out entirely, but it is possible to remove deviation.


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
        rotate_shift = true, -- since we are compensating for animation offset, we should align it with fire direction
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
Default values (if available) are set up through mod settings.
During `data-final-fixes.lua`, deviations (range and angle) are scaled by entity_deviation_coef_map (for found matched entities), that will create new configurations or alter existing ones for matched entities.
In `control.lua`, that data is applied during projectile spawn.

```
I'm not happy with the data structure, so it is subject to change and won't be disclosed here
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
* Replace thumbnail with a unique one
* Redraw/extend library of tracers. (Currently missing blue-plutonium and purple-tungsten variations from common mods)
* Handle character/characters' guns explicitly - give them suitable defaults, so the player won't shoot from their stomach.

# Wishlist
* Find a way to make player_targeting "runtime-per-player" setting, keeping turrets(vehicles?) as startup.
* Support skins, in the way that projectile spawn position could/will be adjusted for skins with gun location that differs from vanilla
* Create satelite mod(s), that exposes individual configurations. Only these satellite mods will handle modded entities explicitly, but those mods require a settings generator of some kind. (As in Better Planets). Mods needed for: tracer settings per ammo; projectile/shell/deviation settings per gun(including vehicle gun's)/turret/armor(or 'naked' engineer)
* Add third mode of operation - codename [Redacted]. It will create more prototypes, but should be practically without events at runtime. (Only callbacks for events that require entity swapping)

# TOTHINK:
* Cache calculations per entity (turrets don't change ammo often, target also tends to be the same for at least a few shots, so we can cache it, and recalculate only necessary logic)
* Simplify logic for non-observed turrets? (No player can see it, so we can 'pretend' that projectiles were shot, rather than calculating them explicitly) May create 'an observer' effect changing effectiveness of turrets depending of being observed or not.

# Known issues
* Misaligned projectiles - figuring out how to properly set up projectile creation properties. Default source position seems to be not exactly correct.
* Misaligned 'miss' effects - if nothing was hit, the bullet will 'explode' 1-2 tiles farther, then at the actual hit position, giving the wrong expectation of range.
* Missing some documentation on overridable mod-data (`entity_configuration_overrides`)
