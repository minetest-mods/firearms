
local random = math.random

local shoot = {
	description = "Shoot",
	func = function(player, player_info, weapon_info)
		local ammo
		player_info.ammo = player_info.ammo or { }
		if weapon_info then
			ammo = player_info.ammo and player_info.ammo[player_info.current_weapon.name]
		end
		-- No ammo left in magazine; must reload.
		if (not ammo) or (ammo == 0) then
			if weapon_info.sounds.empty then
				minetest.sound_play(weapon_info.sounds.empty)
			end
			return
		end
		if player_info.shoot_cooldown <= 0 then
			local player_pos = player:getpos()
			local player_dir = player:get_look_dir()
			if weapon_info.sounds.shoot then
				minetest.sound_play(weapon_info.sounds.shoot)
			end
			-- TODO: Calc this properly.
			local muzzle_pos = { x=player_pos.x, y=player_pos.y, z=player_pos.z, } 
			local spread = weapon_info.spread or 10
			local yaw = player:get_look_yaw()
			player_info.ammo[player_info.current_weapon.name] =
			  player_info.ammo[player_info.current_weapon.name] - 1
			muzzle_pos.y = muzzle_pos.y + 1.45
			muzzle_pos.x = muzzle_pos.x + (math.sin(yaw) / 2)
			muzzle_pos.z = muzzle_pos.z - (math.cos(yaw) / 2)
			if firearms.hud then
				firearms.hud.update_ammo_count(player,
				  player_info,
				  player_info.ammo[player_info.current_weapon.name]
				)
			end
			player_info.shoot_cooldown = (weapon_info.shoot_cooldown or 1)
			player_pos.y = player_pos.y + 1.625
			for n = 1, (weapon_info.pellets or 1) do
				local bullet_dir = {
					x = player_dir.x + (random(-spread, spread) / 1000),
					y = player_dir.y + (random(-spread, spread) / 1000),
					z = player_dir.z + (random(-spread, spread) / 1000),
				}
				local ent = pureluaentity.add(player_pos, "firearms:bullet")
				ent.player = player
				ent.player_info = player_info
				ent.bullet_info = { } -- TODO
				ent.object:setvelocity({
					x = bullet_dir.x * 20,
					y = bullet_dir.y * 20,
					z = bullet_dir.z * 20,
				})
				local v = random(100, 150)
				local bullet_vel = {
					x = bullet_dir.x * v,
					y = bullet_dir.y * v,
					z = bullet_dir.z * v,
				}
				ent.life = (weapon_info.range or 10) / 20
				minetest.add_particle(
					muzzle_pos,         -- pos
					bullet_vel, -- velocity
					{x=0, y=0, z=0},    -- acceleration
					0.5,                -- expirationtime
					2,                  -- size
					false,              -- collisiondetection
					"firearms_bullet.png", -- texture
					player:get_player_name()
				)
			end
		end
	end,
}

local function count_ammo(inv, name)
	-- TODO
	return 100
end

local reload = {
	description = "Reload",
	func = function(player, player_info, weapon_info)
		if weapon_info then
			local ammo = (player_info.ammo
			              and player_info.ammo[player_info.current_weapon.name]
			              or 0)
			-- TODO: Add support for more than one slot.
			local clipsize = (weapon_info.slots
			                  and weapon_info.slots[1]
			                  and weapon_info.slots[1].clipsize)
			if not clipsize then
				firearms.warning(("clipsize not defined for %s; cannot reload"):format(
				                  player_info.current_weapon.name
				                ))
				return
			end
			if ammo < clipsize then
				-- TODO
				local count = count_ammo()--(player:get_inventory():get_list("main"), "")
				if count > 0 then
					player_info.shoot_cooldown = weapon_info.reload_time or 3
					if weapon_info.sounds.reload then
						minetest.sound_play(weapon_info.sounds.reload)
					end
					local needed = math.min(clipsize - ammo, count)
					player_info.ammo = player_info.ammo or { }
					player_info.ammo[player_info.current_weapon.name] = ammo + needed
					if firearms.hud then
						firearms.hud.update_ammo_count(player,
						  player_info,
						  player_info.ammo[player_info.current_weapon.name]
						)
					end
				end
			end
		end
	end,
}

function set_scope(player, player_info, weapon_info, flag)
	if weapon_info and flag then
		firearms.hud.set_player_overlay(player, weapon_info.hud.overlay)
		firearms.set_player_fov(player, weapon_info.zoomed_fov or -100)
	else
		firearms.set_player_fov(player, weapon_info and weapon_info.fov or -100)
		firearms.hud.set_player_overlay(player, nil)
	end
	player_info.zoomed = flag
end

local toggle_scope = {
	description = "Toggle Scope",
	func = function(player, player_info, weapon_info)
		set_scope(player, player_info, weapon_info, not player_info.zoomed)
	end,
}

pureluaentity.register(":firearms:bullet", {
	find_collistion_point = function(ent)
		-- TODO:
		-- This should return the actual point where the bullet
		-- "collided" with it's target.
	end,
	on_step = function(self, dtime)
		local pos = self:getpos()
		local def = minetest.registered_nodes[minetest.get_node(pos).name]
		if def then
			if def.on_shoot then
				if def.on_shoot(pos, self.player, self.player_info, self.bullet_info) then
					return
				end
			end
			if def.walkable then
				local decal_pos = self.last_pos or pos
				minetest.add_particle(
					decal_pos,          -- pos
					{x=0, y=0, z=0},    -- velocity
					{x=0, y=0, z=0},    -- acceleration
					5,                  -- expirationtime
					2.5,                -- size
					false,              -- collisiondetection
					"firearms_bullet_decal.png" -- texture
					--""                  -- player
				)
				self.object:remove()
			end
		end
		self.last_pos = { x=pos.x, y=pos.y, z=pos.z }
		self.life = self.life - dtime
		if self.life <= 0 then
			self.object:remove()
		end
	end,
})

firearms.event.register("weapon_change", function(player, player_info, weapon_info)
	set_scope(player, player_info, weapon_info, false)
end)

-- Exports
firearms = firearms or { }
firearms.action = firearms.action or { }
firearms.action.shoot = shoot
firearms.action.reload = reload
firearms.action.toggle_scope = toggle_scope
