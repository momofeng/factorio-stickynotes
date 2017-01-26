-- debug_status = 1
debug_mod_name = "StickyNotes"
debug_file = debug_mod_name .. "-debug.txt"
require("utils")
require("config")

local color_picker_interface = "color-picker"
local open_color_picker_button_name = "open_color_picker_stknt"
local color_picker_name = "color_picker_stknt"

--------------------------------------------------------------------------------------
local function menu_note( player, player_mem, open_or_close )
	if open_or_close == nil then
		open_or_close = (player.gui.left.flow_stknt == nil)
	end
	
	if player.gui.left.flow_stknt then
		player.gui.left.flow_stknt.destroy()
	end
	
	if open_or_close then
		local gui0
		local gui1, gui2, gui3
		local note = player_mem.note_sel
		
		if note then
			gui0 = player.gui.left.add({type = "flow", name = "flow_stknt", style = "achievements_flow_style", direction = "horizontal"})
			gui1 = gui0.add({type = "frame", name = "frm_stknt", caption = {"stknt-gui-title", note.n}, style = "frame_stknt_style"})
			gui1 = gui1.add({type = "flow", name = "flw_stknt", direction = "vertical", style = "flow_stknt_style"})
			
			local gui2 = gui1.add({type = "textfield", name = "txt_stknt", text = note.text, style = "textfield_stknt_style"})
			gui2.style.minimal_width = 400

			if use_color_picker and remote.interfaces[color_picker_interface] then
				-- use Color Picker mod if possible.
				gui1.add({type = "button", name = open_color_picker_button_name, caption = {"gui-train.color"}, style = "button_stknt_style"})
			else
				gui2 = gui1.add({type = "flow", name = "flw_stknt_colors", direction = "horizontal", style = "flow_stknt_style"})
				for name, color in pairs(colors) do
					gui3 = gui2.add({type = "button", name = "but_stknt_col_" .. name, caption = "@", style = "button_stknt_style"})
					gui3.style.font_color = color
				end
			end
			
			gui1.add({type = "checkbox", name = "chk_stknt_autoshow", caption = {"stknt-gui-autoshow"}, state = note.autoshow, 
				tooltip = {"stknt-gui-autoshow-tt"}, style = "checkbox_stknt_style"})
			gui1.add({type = "checkbox", name = "chk_stknt_mapmark", caption = {"stknt-gui-mapmark"}, state = (note.mapmark ~= nil), 
				tooltip = {"stknt-gui-mapmark-tt"}, style = "checkbox_stknt_style"})
			gui1.add({type = "checkbox", name = "chk_stknt_locked_force", caption = {"stknt-gui-locked-force"}, state = note.locked_force, 
				tooltip = {"stknt-gui-locked-force-tt"}, style = "checkbox_stknt_style"})
			if player.admin then
				gui1.add({type = "checkbox", name = "chk_stknt_locked_admin", caption = {"stknt-gui-locked-admin"}, state = note.locked_admin, 
					tooltip = {"stknt-gui-locked-force-tt"}, style = "checkbox_stknt_style"})
			end
			
			gui1.add({type = "button", name = "but_stknt_delete", caption = {"stknt-gui-delete"}, 
				tooltip = {"stknt-gui-delete-tt"}, style = "button_stknt_style"})
			gui1.add({type = "button", name = "but_stknt_close", caption = {"stknt-gui-close"}, 
				tooltip = {"stknt-gui-close-tt"}, style = "button_stknt_style"})
		end
	end
end

--------------------------------------------------------------------------------------
local function display_mapmark( note, on_or_off )
	if note.mapmark and note.mapmark.valid then
		note.mapmark.destroy()
	end

	note.mapmark = nil

	if on_or_off and note.entity and note.entity.valid then
		local mapmark = note.entity.surface.create_entity({name = "sticky-note-mapmark", force = game.forces.neutral, position = note.entity.position})
		if mapmark then
			mapmark.operable = false
			mapmark.active = false
			mapmark.backer_name = note.text
			note.mapmark = mapmark
		end
	end
end

--------------------------------------------------------------------------------------
local function show_note( note )
	if note.fly then return end
	
	if note.entity and note.entity.valid then
		local pos = note.entity.position
		local surf = note.entity.surface
		local force = note.entity.force
		local x = pos.x-1
		local y = pos.y
		
		local fly = surf.create_entity({name="flying-text",text=note.text,color=note.color,position={x=x,y=y}})
		if fly then
			note.fly = fly
			note.fly.active = false
			note.autohide_tick = game.tick + autohide_time
		end
	end
end

--------------------------------------------------------------------------------------
local function hide_note( note )
	if note.fly and note.fly.valid then
		note.fly.destroy()
	end
	note.fly = nil
end

--------------------------------------------------------------------------------------
local function destroy_note( note )
	for i, player in pairs(game.players) do
		if player.connected then
			local player_mem = global.player_mem[i]
			
			if player_mem.note_sel == note then
				menu_note(player,player_mem,false)
				player_mem.note_sel = nil
			end
		end
	end
	
	hide_note(note)
	
	if note.mapmark and note.mapmark.valid then
		note.mapmark.destroy()
	end
	note.mapmark = nil
end

--------------------------------------------------------------------------------------
local function find_note( ent )
	for i=1,#global.notes do
		local note = global.notes[i]
		
		if note.entity == ent then
			return(note)
		end
	end
	
	return(nil)
end

--------------------------------------------------------------------------------------
local function add_note( entity )
	global.n_note = global.n_note + 1
	
	local note =
	{
		entity = entity, -- inactive/unoperable chest entity
		text = "text " .. global.n_note, -- text
		color = text_color_default, -- color
		n = global.n_note, -- number of the note
		fly = nil, -- text entity
		autoshow = false, -- if true, then note autoshows/hides
		autohide_tick = game.tick + autohide_time, -- tick when to autohide
		mapmark = nil, -- mark on the map
		locked_force = true, -- only modifiable by the same force
		locked_admin = false, -- only modifiable by admins
		editer = nil, -- player currently editing
		is_sign = (entity.name == "sticky-note" or entity.name == "sticky-sign"), -- is connected to a real note/sign object
	}
	
	if text_default ~= nil then
		note.text = text_default
	end
	
	show_note(note)
	
	table.insert(global.notes, note)
	
	if mapmark_default == true then
		display_mapmark(note,true)
	end
	
	return(note)
end

--------------------------------------------------------------------------------------
local function init_globals()
	-- initialize or update general globals of the mod
	debug_print( "init_globals" )
	
	global.tick = global.tick or 0
	global.player_mem = global.player_mem or {}
	
	global.notes = global.notes or {}
	global.n_note = global.n_note or 0
end

--------------------------------------------------------------------------------------
local function init_player(player)
	if global.player_mem == nil then return end
	
	-- initialize or update per player globals of the mod, and reset the gui
	debug_print( "init_player ", player.name, " connected=", player.connected )
	
	global.player_mem[player.index] = global.player_mem[player.index] or {}
	
	local player_mem = global.player_mem[player.index]
	player_mem.note_sel = player_mem.note_sel or nil
end

--------------------------------------------------------------------------------------
local function init_players()
	for _, player in pairs(game.players) do
		init_player(player)
	end
end

--------------------------------------------------------------------------------------
local function init_forces()
	for _,force in pairs(game.forces) do
		force.recipes["sticky-note"].enabled = force.technologies["sticky-notes"].researched
		force.recipes["sticky-sign"].enabled = force.technologies["sticky-notes"].researched
	end
end

--------------------------------------------------------------------------------------
local function on_init() 
	-- called once, the first time the mod is loaded on a game (new or existing game)
	debug_print( "on_init" )
	init_globals()
	init_players()
end

script.on_init(on_init)

--------------------------------------------------------------------------------------
local function on_configuration_changed(data)
	-- detect any mod or game version change
	if data.mod_changes ~= nil then
		local changes = data.mod_changes[debug_mod_name]
		if changes ~= nil then
			debug_print( "update mod: ", debug_mod_name, " ", tostring(changes.old_version), " to ", tostring(changes.new_version) )
		
			init_globals()
			init_forces()
			init_players()
			
			-- close all notes menu, by precaution
			
			for i, player in pairs(game.players) do
				if player.connected then
					local player_mem = global.player_mem[i]
					menu_note(player,player_mem,false)
					player_mem.note_sel = nil
				end
			end
			
			if changes.old_version and older_version(changes.old_version, "1.0.8") then
				message_all( "Sticky notes : please now use the ALT-W key instead of ENTER (or redefine it in the menu/options)." )
				message_all( "Sticky notes : you can now add a text on any entity on the map." )
			end
			
			if changes.old_version and older_version(changes.old_version, "1.0.12") then
				for i,note in pairs(global.notes) do
					local ent_name = note.entity.name
					note.locked_force = note.locked
					note.locked_admin = false
					note.is_sign = (ent_name == "sticky-note" or ent_name == "sticky-sign") 
				end
				
				message_all( "Sticky notes : new option to lock notes for admins." )
			end
		end
	end
end

script.on_configuration_changed(on_configuration_changed)

--------------------------------------------------------------------------------------
local function on_player_created(event)
	-- called at player creation
	local player = game.players[event.player_index]
	debug_print( "player created ", player.name )
	
	init_player(player)
	
	if debug_status == 1 then
		if #game.players > 1 then
			local force = game.create_force(player.name .. "-force")
			player.force = force
		end
		local inv = player.get_inventory(defines.inventory.player_quickbar)
		inv.insert({name="sticky-note", count=50})
		inv.insert({name="sticky-sign", count=50})
	end
end

script.on_event(defines.events.on_player_created, on_player_created )

--------------------------------------------------------------------------------------
local function on_player_joined_game(event)
	-- called in SP(once) and MP(at every connect), eventually after on_player_created
	local player = game.players[event.player_index]
	debug_print( "player joined ", player.name )
	
	init_player(player)
end

script.on_event(defines.events.on_player_joined_game, on_player_joined_game )

--------------------------------------------------------------------------------------
local function on_creation( event )
	local ent = event.created_entity
	local force = ent.force
	local ent_name = ent.name
	
	if ent_name == "sticky-note" or ent_name == "sticky-sign" then
		debug_print( "on_creation ", ent_name )
		
		ent.force = force
		ent.destructible = false
		ent.operable = false
		-- ent.minable = false
		
		add_note(ent)
	end
end

script.on_event(defines.events.on_built_entity, on_creation )
script.on_event(defines.events.on_robot_built_entity, on_creation )

--------------------------------------------------------------------------------------
local function on_destruction( event )
	local ent = event.entity
	local ent_name = ent.name
	
	for i,note in pairs(global.notes) do
		if note.entity == ent then
			debug_print( "on_destruction ", ent_name )
			destroy_note(note)
			table.remove(global.notes,i)
			break
		end
	end
end

script.on_event(defines.events.on_entity_died, on_destruction )
script.on_event(defines.events.on_robot_pre_mined, on_destruction )
script.on_event(defines.events.on_preplayer_mined_item, on_destruction )

--------------------------------------------------------------------------------------
local function on_tick(event)
	if global.tick <= 0 then 
		--  auto show notes
		global.tick = 28
		
		for _, player in pairs(game.players) do
			local selected = player.selected
			
			if selected then
				local note = find_note(selected)
				if note and note.autoshow then
					show_note(note)
				end
			end
		end
		
	elseif global.tick == 13 then
		-- cleaning and auto hiding notes
		
		for i=#global.notes,1,-1 do
			local note = global.notes[i]
			
			if note.entity and note.entity.valid then
				if note.autoshow and note.fly and note.editer == nil and game.tick > note.autohide_tick then
					hide_note(note)
				end
			else
				destroy_note(note)
				table.remove(global.notes,i)
			end
		end
	end
	
	global.tick = global.tick -1 
end

script.on_event(defines.events.on_tick, on_tick)

--------------------------------------------------------------------------------------
local function on_gui_text_changed(event)
	local player = game.players[event.player_index]
	local event_name = event.element.name

	debug_print( "on_gui_text_changed ", player.name, " ", event_name )
	
	if event_name == "txt_stknt" then
		local player_mem = global.player_mem[player.index]
		local note = player_mem.note_sel
		
		if note then
			note.text = event.element.text
			hide_note(note)
			show_note(note)
			if note.mapmark then
				display_mapmark(note,true)
			end
		end
	end
end

script.on_event(defines.events.on_gui_text_changed,on_gui_text_changed)

--------------------------------------------------------------------------------------
local function on_gui_click(event)
	local player = game.players[event.player_index]
	local event_name = event.element.name
	local prefix = string.sub(event_name,1,14)
	local suffix = string.sub(event_name,15)
	
	
	debug_print( "on_gui_click ", player.name, " ", event_name )

	if event_name == "but_stknt_close" then
		local player_mem = global.player_mem[player.index]
		local note = player_mem.note_sel
		
		if note then
			note.editer = nil
		end
		
		menu_note(player,player_mem,false)
		player_mem.note_sel = nil
		
	elseif event_name == "but_stknt_delete" then
		local player_mem = global.player_mem[player.index]
		local note = player_mem.note_sel
		
		if note then
			for i,note2 in pairs(global.notes) do
				if note2 == note then
					destroy_note(note)
					table.remove(global.notes,i)
					break
				end
			end
			menu_note(player,player_mem,false)
			if note.is_sign then
				note.entity.minable = true
				note.entity.destroy()
			end
			player_mem.note_sel = nil
		end
		
	elseif prefix == "but_stknt_col_" then
		local player_mem = global.player_mem[player.index]
		local note = player_mem.note_sel
		local color = colors[suffix]
		
		if color and note then
			note.color = color
			hide_note(note)
			show_note(note)
		end
		
	elseif event_name == "chk_stknt_autoshow" then
		local player_mem = global.player_mem[player.index]
		local note = player_mem.note_sel
		
		if note then
			note.autoshow = event.element.state
			if note.autoshow then
				hide_note(note)
			else
				show_note(note)
			end
		end
		
	elseif event_name == "chk_stknt_mapmark" then
		local player_mem = global.player_mem[player.index]
		local note = player_mem.note_sel
		
		if note then	
			if event.element.state then
				display_mapmark(note,true)
			else
				display_mapmark(note,false)
			end
		end
	
	elseif event_name == "chk_stknt_locked_force" then
		local player_mem = global.player_mem[player.index]
		local note = player_mem.note_sel
		
		note.locked_force = event.element.state
		
	elseif event_name == "chk_stknt_locked_admin" then
		if player.admin then
			local player_mem = global.player_mem[player.index]
			local note = player_mem.note_sel
		
			note.locked_admin = event.element.state
			
			if note.is_sign then
				if note.locked_admin then
					note.entity.minable = false
				else
					note.entity.minable = true
				end
			end
		end
		
	elseif event_name == open_color_picker_button_name then
		-- open color picker.
		local flow = player.gui.left.flow_stknt
		if flow then
			if flow[color_picker_name] then
				flow[color_picker_name].destroy()
			else
				remote.call(color_picker_interface, "add_instance",
					{
						parent = flow,
						container_name = color_picker_name,
						color = global.player_mem[player.index].note_sel and global.player_mem[player.index].note_sel.color,
						show_ok_button = true,
						-- result_caption = "@@@@@@"
					}
				)
			end
		end
	end
end

script.on_event(defines.events.on_gui_click, on_gui_click)

--------------------------------------------------------------------------------------
function on_hotkey_write(event)
	local player = game.players[event.player_index]
	local player_mem = global.player_mem[player.index]
	local selected = player.selected
	local note = nil
	
	if selected and player.force.technologies["sticky-notes"].researched then
		note = find_note(selected)
		
		if note == nil and player.force == selected.force then
			-- add a new note
			local type = selected.type
			
			-- do not add a text on movable objects or rails.
		
			if type ~= "car" 
				and type ~= "tank" 
				and type ~= "player" 
				and type ~= "unit" 
				and type ~= "unit-spawner" 
				and type ~= "straight-rail" 
				and type ~= "curved-rail" 
				and type ~= "locomotive" 
				and type ~= "cargo-wagon" 
				and type ~= "logistic-robot" 
				and type ~= "construction-robot" 
				and type ~= "combat-robot" 
			then
				note = add_note(selected)
			end
		end
	end
	
	local previous = player_mem.note_sel
	
	if previous ~= note then
		-- hide the previous menu
		if previous then
			previous.editer = nil
			menu_note(player,player_mem,false)
			player_mem.note_sel = nil
		end
		
		-- show the new menu
		if note and (note.editer == nil or not note.editer.connected) and (note.entity.force == player.force or not note.locked_force) and (player.admin or not note.locked_admin) then
			player_mem.note_sel = note
			note.editer = player
			menu_note(player,player_mem,true)
		end
	end
end

script.on_event("notes_write_hotkey", on_hotkey_write)

--------------------------------------------------------------------------------------
if remote.interfaces[color_picker_interface] then
	-- color picker events.
   script.on_event(remote.call(color_picker_interface, "on_color_updated"), 
	   function(event)
		  if event.container.name == color_picker_name then
			 local player_mem = global.player_mem[event.player_index]
			 local note = player_mem.note_sel
			 local color = event.color
			 
			 if color and note then
				note.color = color
				hide_note(note)
				show_note(note)
			 end
		  end
	   end
   )
   
   script.on_event(remote.call(color_picker_interface, "on_ok_button_clicked"), 
	   function(event)
		  if event.container.name == color_picker_name then
				event.container.destroy()
			end
	   end
   )
end

--------------------------------------------------------------------------------------
local interface = {}

function interface.clean()
	debug_print( "clean" )
	
	for i,note in pairs(global.notes) do
		destroy_note(note)
	end
	
	global.notes = {}
end

remote.add_interface( "notes", interface )

-- /c remote.call( "notes", "clean" )

