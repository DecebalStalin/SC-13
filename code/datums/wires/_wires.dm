#define MAXIMUM_EMP_WIRES 3

/datum/wires
	interaction_flags = INTERACT_UI_INTERACT
	var/atom/holder = null // The holder (atom that contains these wires).
	var/holder_type = null // The holder's typepath (used to make wire colors common to all holders).
	var/proper_name = "Unknown" // The display name for the wire set shown in station blueprints. Not used if randomize is true or it's an item NT wouldn't know about (Explosives/Nuke)

	var/list/wires = list() // List of wires.
	var/list/cut_wires = list() // List of wires that have been cut.
	var/list/colors = list() // Dictionary of colors to wire.
	var/list/assemblies = list() // List of attached assemblies.
	var/randomize = 0 // If every instance of these wires should be random.
						// Prevents wires from showing up in station blueprints


/datum/wires/New(atom/holder)
	. = ..()
	if(!istype(holder, holder_type))
		CRASH("Wire holder is not of the expected type! holder: [holder.type], holder_type: [holder_type]")
		return

	src.holder = holder
	if(randomize)
		randomize()
	else
		if(!GLOB.wire_color_directory[holder_type])
			randomize()
			GLOB.wire_color_directory[holder_type] = colors
			GLOB.wire_name_directory[holder_type] = proper_name
		else
			colors = GLOB.wire_color_directory[holder_type]


/datum/wires/Destroy()
	holder = null
	assemblies = list()
	return ..()


/datum/wires/proc/add_duds(duds)
	while(duds)
		var/dud = WIRE_DUD_PREFIX + "[--duds]"
		if(dud in wires)
			continue
		wires += dud


/datum/wires/proc/randomize()
	var/static/list/possible_colors = list(
	"blue",
	"brown",
	"crimson",
	"cyan",
	"gold",
	"grey",
	"green",
	"magenta",
	"orange",
	"pink",
	"purple",
	"red",
	"silver",
	"violet",
	"white",
	"yellow"
	)

	var/list/my_possible_colors = possible_colors.Copy()

	for(var/wire in shuffle(wires))
		colors[pick_n_take(my_possible_colors)] = wire


/datum/wires/proc/shuffle_wires()
	colors.Cut()
	randomize()


/datum/wires/proc/repair()
	cut_wires.Cut()


/datum/wires/proc/get_wire(color)
	return colors[color]


/datum/wires/proc/get_color_of_wire(wire_type)
	for(var/color in colors)
		var/other_type = colors[color]
		if(wire_type == other_type)
			return color


/datum/wires/proc/get_attached(color)
	if(assemblies[color])
		return assemblies[color]
	return null


/datum/wires/proc/is_attached(color)
	if(assemblies[color])
		return TRUE


/datum/wires/proc/is_cut(wire)
	return (wire in cut_wires)


/datum/wires/proc/is_color_cut(color)
	return is_cut(get_wire(color))


/datum/wires/proc/is_all_cut()
	if(length(cut_wires) == length(wires))
		return TRUE


/datum/wires/proc/is_dud(wire)
	return dd_hasprefix(wire, WIRE_DUD_PREFIX)


/datum/wires/proc/is_dud_color(color)
	return is_dud(get_wire(color))


/datum/wires/proc/cut(wire, mob/user)
	if(user?.mind?.cm_skills && user.mind.cm_skills.engineer < SKILL_ENGINEER_ENGI)
		user.visible_message("<span class='notice'>[user] fumbles around figuring out the wiring.</span>",
		"<span class='notice'>You fumble around figuring out the wiring.</span>")
		var/fumbling_time = 20 * (SKILL_ENGINEER_ENGI - user.mind.cm_skills.engineer)
		if(!do_after(user, fumbling_time, TRUE, holder, BUSY_ICON_UNSKILLED))
			return

	if(is_cut(wire))
		cut_wires -= wire
		on_cut(wire, mend = TRUE)
	else
		cut_wires += wire
		on_cut(wire, mend = FALSE)


/datum/wires/proc/cut_color(color, mob/user)
	cut(get_wire(color), user)


/datum/wires/proc/cut_random()
	cut(wires[rand(1, length(wires))])


/datum/wires/proc/cut_all()
	for(var/wire in wires)
		cut(wire)


/datum/wires/proc/pulse(wire, mob/user)
	if(is_cut(wire))
		return

	if(user.mind?.cm_skills && user.mind.cm_skills.engineer < SKILL_ENGINEER_ENGI)
		user.visible_message("<span class='notice'>[usr] fumbles around figuring out the wiring.</span>",
		"<span class='notice'>You fumble around figuring out the wiring.</span>")
		var/fumbling_time = 20 * (SKILL_ENGINEER_ENGI - user.mind.cm_skills.engineer)
		if(!do_after(user, fumbling_time, TRUE, holder, BUSY_ICON_UNSKILLED) || is_cut(wire))
			return

	on_pulse(wire, user)


/datum/wires/proc/pulse_color(color, mob/user)
	pulse(get_wire(color), user)


/datum/wires/proc/pulse_assembly(obj/item/assembly/S)
	for(var/color in assemblies)
		if(S == assemblies[color])
			pulse_color(color)
			return TRUE


/datum/wires/proc/attach_assembly(color, obj/item/assembly/S)
	if(istype(S) && S.attachable && !is_attached(color))
		assemblies[color] = S
		S.forceMove(holder)
		S.connected = src
		return S


/datum/wires/proc/detach_assembly(color)
	var/obj/item/assembly/S = get_attached(color)
	if(!istype(S))
		return
	assemblies -= color
	S.connected = null
	S.forceMove(get_turf(S))
	return S


/datum/wires/proc/emp_pulse()
	var/list/possible_wires = shuffle(wires)
	var/remaining_pulses = MAXIMUM_EMP_WIRES

	for(var/wire in possible_wires)
		if(!prob(33))
			continue
		pulse(wire)
		remaining_pulses--
		if(!remaining_pulses)
			break


/datum/wires/proc/get_status()
	return


/datum/wires/proc/on_cut(wire, mend = FALSE)
	return


/datum/wires/proc/on_pulse(wire, user)
	return
// End Overridable Procs


/datum/wires/can_interact(mob/user)
	. = ..()
	if(!.)
		return FALSE

	if(!user.CanReach(holder))
		return FALSE

	return TRUE


/datum/wires/ui_interact(mob/user, ui_key = "main", datum/nanoui/ui, force_open = TRUE)
	var/list/data = list()
	var/list/payload = list()
	var/reveal_wires = FALSE

	for(var/color in colors)
		payload.Add(list(list(
			"color" = color,
			"wire" = ((reveal_wires && !is_dud_color(color)) ? get_wire(color) : null),
			"cut" = is_color_cut(color),
			"attached" = is_attached(color)
		)))

	data["wires"] = payload
	data["status"] = get_status()

	ui = SSnano.try_update_ui(user, src, ui_key, ui, data, force_open)
	if(!ui)
		ui = new(user, src, ui_key, "wires.tmpl", holder, 500, 150 + length(wires) * 30)
		ui.set_initial_data(data)
		ui.open()

	return TRUE


/datum/wires/Topic(href, href_list)
	. = ..()
	if(.)
		return

	var/target_wire = href_list["wire"]
	var/obj/item/I = usr.get_active_held_item()

	if(href_list["cut"])
		if(!iswirecutter(I))
			to_chat(usr, "<span class='warning'>You need wirecutters!</span>")
			return

		cut_color(target_wire, usr)
		. = TRUE

	else if(href_list["pulse"])
		if(!ismultitool(I))
			to_chat(usr, "<span class='warning'>You need a multitool!</span>")
			return

		pulse_color(target_wire, usr)
		. = TRUE

	else if(href_list["attach"])
		if(is_attached(target_wire))
			I = detach_assembly(target_wire)
			if(!I)
				return

			usr.put_in_hands(I)
			. = TRUE
		else
			if(!istype(I, /obj/item/assembly))
				to_chat(usr, "<span class='warning'>You need an assembly!</span>")
				return

			var/obj/item/assembly/A = I
			if(!A.attachable)
				to_chat(usr, "<span class='warning'>You need an attachable assembly!</span>")
				return

			if(!usr.temporarilyRemoveItemFromInventory(A))
				return
			if(!attach_assembly(target_wire, A))
				A.forceMove(get_turf(usr))
			. = TRUE


#undef MAXIMUM_EMP_WIRES