A mod that combines misfires with tracers without compromising the individual characteristics of the shooting entity.

Attempted to be as mod-compatible as possible, partially by reusing as many properties as possible from the entity itself, and partially by exposing configurations in the mod-data.

Based on https://mods.factorio.com/mod/ownlys_tracers_21_fork, but was heavily rewritten on the logic side.
The original behaviour can be enabled by choosing "Unified" mode of operation in the mode settings. However, some entities' properties will be lost in that mode.

# Warning
Mod is in an early development stage, and 'API' is expected to change.

# TODO
* Replace thumbnail with a unique one
* Find a way to make player_targeting "runtime-per-player" setting, keeping turrets(vehicles?) as startup.
* Redraw/extend library of tracers. (Currently missing blue-plutonium and purple-tungsten variations from common mods)
* Handle character/characters guns explicitly - give them suitable defaults, so player won't shoot from its stomach.

# Wishlist
* Support skins, in the way that projectile spawn position could/will be adjusted for skins with gun location that differs from vanilla
* Create satelite mod(s), that exposes individual configurations. Only these satellite mods will handle modded entities explicitly, but those mods require a settings generator of some kind. (As in Better Planets). Mods needed for: tracer settings per ammo; projectile/shell/deviation settings per gun(including vehicle gun's)/turret/armor(or 'naked' engineer)
* Add third mode of operation - codename "hidden-turret". It will create more prototypes, but should be practically without events at runtime. (Only callbacks for events that require entity swapping)

# Known issues
* Misaligned projectiles - figuring out how to properly set up projectile creation properties.
* Misaligned 'miss' effects - if nothing was hit, bullet will 'explode' 1-2 tiles farther, then at the actual hit position, giving the wrong expectation of range.
* Missing documentation on overridable mod-data (only some comments in code)
