/datum/wires/airalarm
	holder_type = /obj/machinery/alarm
	proper_name = "Air Alarm"


/datum/wires/airalarm/New(atom/holder)
	wires = list(
		WIRE_POWER,
		WIRE_IDSCAN, WIRE_AI,
		WIRE_PANIC, WIRE_ALARM
	)
	add_duds(3)
	return ..()


/datum/wires/airalarm/can_interact(mob/user)
	. = ..()
	if(!.)
		return FALSE
	var/obj/machinery/alarm/A = holder
	if(CHECK_BITFIELD(A.machine_stat, PANEL_OPEN) && A.buildstage == 2)
		return TRUE


/datum/wires/airalarm/get_status()
	var/obj/machinery/alarm/A = holder
	var/status
	status += "The interface light is [A.locked ? "red" : "green"].<br>"
	status += "The short indicator is [A.shorted ? "lit" : "off"].<br>"
	status += "The AI connection light is [!A.aidisabled ? "on" : "off"]."
	return status


/datum/wires/airalarm/on_pulse(wire)
	var/obj/machinery/alarm/A = holder
	switch(wire)
		if(WIRE_POWER) // Short out for a long time.
			if(!A.shorted)
				A.shorted = TRUE
				A.update_icon()
			addtimer(CALLBACK(A, /obj/machinery/alarm.proc/reset, wire), 1200)
		if(WIRE_IDSCAN) // Toggle lock.
			A.locked = !A.locked
		if(WIRE_AI) // Disable AI control for a while.
			if(!A.aidisabled)
				A.aidisabled = TRUE
			addtimer(CALLBACK(A, /obj/machinery/alarm.proc/reset, wire), 100)
		if(WIRE_PANIC) // Toggle panic siphon.
			if(!A.shorted)
				if(A.mode == AALARM_MODE_SCRUBBING)
					A.mode = AALARM_MODE_PANIC
				else
					A.mode = AALARM_MODE_SCRUBBING
				A.apply_mode(usr)
		if(WIRE_ALARM) // Clear alarms.
			var/area/AA = get_area(A)
			if(AA.atmosalert(0, holder))
				A.post_alert(0)
			A.update_icon()


/datum/wires/airalarm/on_cut(wire, mend)
	var/obj/machinery/alarm/A = holder
	switch(wire)
		if(WIRE_POWER) // Short out forever.
			A.shock(usr, 50)
			A.shorted = !mend
			A.update_icon()
		if(WIRE_IDSCAN)
			if(!mend)
				A.locked = TRUE
		if(WIRE_AI)
			A.aidisabled = mend // Enable/disable AI control.
		if(WIRE_PANIC) // Force panic syphon on.
			if(!mend && !A.shorted)
				A.mode = AALARM_MODE_PANIC
				A.apply_mode(usr)
		if(WIRE_ALARM) // Post alarm.
			var/area/AA = get_area(A)
			if(AA.atmosalert(2, holder))
				A.post_alert(2)
			A.update_icon()