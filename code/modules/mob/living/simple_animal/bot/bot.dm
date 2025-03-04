//Defines for bots are now found in code\__DEFINES\bots.dm

// AI (i.e. game AI, not the AI player) controlled bots
/mob/living/simple_animal/bot
	icon = 'icons/obj/aibots.dmi'
	layer = MOB_LAYER - 0.1
	light_range = 3
	stop_automated_movement = 1
	wander = 0
	healable = 0
	damage_coeff = list(BRUTE = 1, BURN = 1, TOX = 0, CLONE = 0, STAMINA = 0, OXY = 0)
	atmos_requirements = list("min_oxy" = 0, "max_oxy" = 0, "min_tox" = 0, "max_tox" = 0, "min_co2" = 0, "max_co2" = 0, "min_n2" = 0, "max_n2" = 0)
	minbodytemp = 0
	has_unlimited_silicon_privilege = 1
	sentience_type = SENTIENCE_ARTIFICIAL
	status_flags = 0 //no default canpush
	can_strip = 0

	speak_emote = list("states")
	friendly = "boops"
	bubble_icon = "machine"
	faction = list("neutral", "silicon")

	var/obj/machinery/bot_core/bot_core = null
	var/bot_core_type = /obj/machinery/bot_core
	var/list/users = list() //for dialog updates
	var/window_id = "bot_control"
	var/window_name = "Protobot 1.0" //Popup title
	var/window_width = 0 //0 for default size
	var/window_height = 0
	var/obj/item/paicard/paicard // Inserted pai card.
	var/allow_pai = 1 // Are we even allowed to insert a pai card.
	var/bot_name

	var/list/player_access = list()
	var/emagged = 0
	var/obj/item/card/id/access_card			// the ID card that the bot "holds"
	var/list/prev_access = list()
	var/on = 1
	var/open = 0//Maint panel
	var/locked = 1
	var/hacked = 0 //Used to differentiate between being hacked by silicons and emagged by humans.
	var/text_hack = ""		//Custom text returned to a silicon upon hacking a bot.
	var/text_dehack = "" 	//Text shown when resetting a bots hacked status to normal.
	var/text_dehack_fail = "" //Shown when a silicon tries to reset a bot emagged with the emag item, which cannot be reset.
	var/declare_message = "" //What the bot will display to the HUD user.
	var/frustration = 0 //Used by some bots for tracking failures to reach their target.
	var/base_speed = 2 //The speed at which the bot moves, or the number of times it moves per process() tick.
	var/turf/ai_waypoint //The end point of a bot's path, or the target location.
	var/list/path = list() //List of turfs through which a bot 'steps' to reach the waypoint, associated with the path image, if there is one.
	var/pathset = 0
	var/list/ignore_list = list() //List of unreachable targets for an ignore-list enabled bot to ignore.
	var/mode = BOT_IDLE //Standardizes the vars that indicate the bot is busy with its function.
	var/tries = 0 //Number of times the bot tried and failed to move.
	var/remote_disabled = 0 //If enabled, the AI cannot *Remotely* control a bot. It can still control it through cameras.
	var/mob/living/silicon/ai/calling_ai //Links a bot to the AI calling it.
	var/obj/item/radio/Radio //The bot's radio, for speaking to people.
	var/list/radio_config = null //which channels can the bot listen to
	var/radio_channel = "Common" //The bot's default radio channel
	var/auto_patrol = 0// set to make bot automatically patrol
	var/turf/patrol_target	// this is turf to navigate to (location of beacon)
	var/turf/summon_target	// The turf of a user summoning a bot.
	var/new_destination		// pending new destination (waiting for beacon response)
	var/destination			// destination description tag
	var/next_destination	// the next destination in the patrol route
	var/ignorelistcleanuptimer = 1 // This ticks up every automated action, at 300 we clean the ignore list
	var/robot_arm = /obj/item/robot_parts/r_arm

	var/blockcount = 0		//number of times retried a blocked path
	var/awaiting_beacon	= 0	// count of pticks awaiting a beacon response

	var/nearest_beacon			// the nearest beacon's tag
	var/turf/nearest_beacon_loc	// the nearest beacon's location

	var/model = "" //The type of bot it is.
	var/bot_purpose = "improve the station to the best of your ability"
	var/control_freq = BOT_FREQ		// bot control frequency
	var/bot_filter 				// The radio filter the bot uses to identify itself on the network.
	var/bot_type = 0 //The type of bot it is, for radio control.
	var/data_hud_type = DATA_HUD_DIAGNOSTIC //The type of data HUD the bot uses. Diagnostic by default.
	//This holds text for what the bot is mode doing, reported on the remote bot control interface.
	var/list/mode_name = list("In Pursuit","Preparing to Arrest", "Arresting", \
	"Beginning Patrol", "Patrolling", "Summoned by PDA", \
	"Cleaning", "Repairing", "Proceeding to work site", "Healing", \
	"Responding", "Navigating to Delivery Location", "Navigating to Home", \
	"Waiting for clear path", "Calculating navigation path", "Pinging beacon network", "Unable to reach destination")

	var/datum/atom_hud/data/bot_path/path_hud = new /datum/atom_hud/data/bot_path()
	var/path_image_icon = 'icons/obj/aibots.dmi'
	var/path_image_icon_state = "path_indicator"
	var/path_image_color = "#FFFFFF"
	var/reset_access_timer_id

	hud_possible = list(DIAG_STAT_HUD, DIAG_BOT_HUD, DIAG_HUD, DIAG_PATH_HUD = HUD_LIST_LIST)//Diagnostic HUD views

/obj/item/radio/headset/bot
	requires_tcomms = FALSE
	canhear_range = 0

/obj/item/radio/headset/bot/recalculateChannels()
	var/mob/living/simple_animal/bot/B = loc
	if(istype(B))
		if(!B.radio_config)
			B.radio_config = list("AI Private" = 1)
			if(!(B.radio_channel in B.radio_config)) // put it first so it's the :h channel
				B.radio_config.Insert(1, "[B.radio_channel]")
				B.radio_config["[B.radio_channel]"] = 1
		config(B.radio_config)

/mob/living/simple_animal/bot/proc/get_mode()
	if(client) //Player bots do not have modes, thus the override. Also an easy way for PDA users/AI to know when a bot is a player.
		if(paicard)
			return "<b>pAI Controlled</b>"
		else
			return "<b>Autonomous</b>"
	else if(!on)
		return "<span class='bad'>Inactive</span>"
	else if(!mode)
		return "<span class='good'>Idle</span>"
	else
		return "<span class='average'>[mode_name[mode]]</span>"

/mob/living/simple_animal/bot/proc/turn_on()
	if(stat)
		return 0
	on = 1
	set_light(initial(light_range))
	update_icon()
	update_controls()
	diag_hud_set_botstat()
	return 1

/mob/living/simple_animal/bot/proc/turn_off()
	on = 0
	set_light(0)
	bot_reset() //Resets an AI's call, should it exist.
	update_icon()
	update_controls()

/mob/living/simple_animal/bot/New()
	..()
	GLOB.bots_list += src
	icon_living = icon_state
	icon_dead = icon_state
	access_card = new /obj/item/card/id(src)
//This access is so bots can be immediately set to patrol and leave Robotics, instead of having to be let out first.
	access_card.access += ACCESS_ROBOTICS
	set_custom_texts()
	Radio = new/obj/item/radio/headset/bot(src)
	Radio.follow_target = src
	add_language("Galactic Common", 1)
	add_language("Sol Common", 1)
	add_language("Tradeband", 1)
	add_language("Gutter", 1)
	add_language("Trinary", 1)
	default_language = GLOB.all_languages["Galactic Common"]

	bot_core = new bot_core_type(src)
	spawn(30)
		if(SSradio && bot_filter)
			SSradio.add_object(bot_core, control_freq, bot_filter)

	prepare_huds()
	for(var/datum/atom_hud/data/diagnostic/diag_hud in GLOB.huds)
		diag_hud.add_to_hud(src)
		diag_hud.add_hud_to(src)
		permanent_huds |= diag_hud
	diag_hud_set_bothealth()
	diag_hud_set_botstat()
	diag_hud_set_botmode()
	// give us the hud too!
	if(path_hud)
		path_hud.add_to_hud(src)
		path_hud.add_hud_to(src)


/mob/living/simple_animal/bot/med_hud_set_health()
	return //we use a different hud

/mob/living/simple_animal/bot/med_hud_set_status()
	return //we use a different hud

/mob/living/simple_animal/bot/update_canmove(delay_action_updates = 0)
	. = ..()
	if(!on)
		. = 0
	canmove = .

/mob/living/simple_animal/bot/Destroy()
	if(paicard)
		ejectpai()
	if(path_hud)
		QDEL_NULL(path_hud)
		path_hud = null
 	GLOB.bots_list -= src
	QDEL_NULL(Radio)
	QDEL_NULL(access_card)
	if(reset_access_timer_id)
		deltimer(reset_access_timer_id)
		reset_access_timer_id = null
	if(SSradio && bot_filter)
		SSradio.remove_object(bot_core, control_freq)
	QDEL_NULL(bot_core)
	return ..()

/mob/living/simple_animal/bot/death(gibbed)
	// Only execute the below if we successfully died
	. = ..()
	if(!.)
		return FALSE
	explode()

/mob/living/simple_animal/bot/proc/explode()
	qdel(src)

/mob/living/simple_animal/bot/emag_act(mob/user)
	if(locked) //First emag application unlocks the bot's interface. Apply a screwdriver to use the emag again.
		locked = 0
		emagged = 1
		to_chat(user, "<span class='notice'>You bypass [src]'s controls.</span>")
		return
	if(!locked && open) //Bot panel is unlocked by ID or emag, and the panel is screwed open. Ready for emagging.
		emagged = 2
		remote_disabled = 1 //Manually emagging the bot locks out the AI built in panel.
		locked = 1 //Access denied forever!
		bot_reset()
		turn_on() //The bot automatically turns on when emagged, unless recently hit with EMP.
		to_chat(src, "<span class='userdanger'>(#$*#$^^( OVERRIDE DETECTED</span>")
		show_laws()
		add_attack_logs(user, src, "Emagged")
		return
	else //Bot is unlocked, but the maint panel has not been opened with a screwdriver yet.
		to_chat(user, "<span class='warning'>You need to open maintenance panel first!</span>")

/mob/living/simple_animal/bot/examine(mob/user)
	. = ..()
	if(health < maxHealth)
		if(health > maxHealth/3)
			. += "<span class='notice'>[src]'s parts look loose.</span>"
		else
			. += "<span class='warning'>[src]'s parts look very loose!</span>"
	else
		. += "<span class='notice'>[src] is in pristine condition.</span>"

/mob/living/simple_animal/bot/adjustHealth(amount, updating_health = TRUE)
	if(amount > 0 && prob(10))
		new /obj/effect/decal/cleanable/blood/oil(loc)
	. = ..()

/mob/living/simple_animal/bot/updatehealth(reason = "none given")
	..(reason)
	diag_hud_set_bothealth()

/mob/living/simple_animal/bot/handle_automated_action()
	diag_hud_set_botmode()

	if(ignorelistcleanuptimer % 300 == 0) // Every 300 actions, clean up the ignore list from old junk
		for(var/uid in ignore_list)
			var/atom/referredatom = locateUID(uid)
			if(!referredatom || QDELETED(referredatom))
				ignore_list -= uid
		ignorelistcleanuptimer = 1
	else
		ignorelistcleanuptimer++

	if(!on)
		return

	switch(mode) //High-priority overrides are processed first. Bots can do nothing else while under direct command.
		if(BOT_RESPONDING)	//Called by the AI.
			call_mode()
			return
		if(BOT_SUMMON)		//Called by PDA
			bot_summon()
			return
	return 1 //Successful completion. Used to prevent child process() continuing if this one is ended early.

/mob/living/simple_animal/bot/attack_alien(mob/living/carbon/alien/user)
	user.changeNext_move(CLICK_CD_MELEE)
	user.do_attack_animation(src)
	apply_damage(rand(15,30), BRUTE)
	visible_message("<span class='danger'>[user] has slashed [src]!</span>")
	playsound(loc, 'sound/weapons/slice.ogg', 25, 1, -1)
	if(prob(10))
		new /obj/effect/decal/cleanable/blood/oil(loc)

/mob/living/simple_animal/bot/attack_animal(mob/living/simple_animal/M)
	M.do_attack_animation(src)
	if(M.melee_damage_upper == 0)
		return
	apply_damage(M.melee_damage_upper, BRUTE)
	visible_message("<span class='danger'>[M] has [M.attacktext] [src]!</span>")
	add_attack_logs(M, src, "Animal attacked", ATKLOG_ALL)
	if(prob(10))
		new /obj/effect/decal/cleanable/blood/oil(loc)

/mob/living/simple_animal/bot/attack_hand(mob/living/carbon/human/H)
	if(H.a_intent == INTENT_HELP)
		interact(H)
	else
		return ..()

/mob/living/simple_animal/bot/attack_ghost(mob/M)
	interact(M)

/mob/living/simple_animal/bot/attack_ai(mob/user)
	if(!topic_denied(user))
		interact(user)
	else
		to_chat(user, "<span class='warning'>[src]'s interface is not responding!</span>")

/mob/living/simple_animal/bot/proc/interact(mob/user)
	show_controls(user)

/mob/living/simple_animal/bot/attackby(obj/item/W, mob/user, params)
	if(istype(W, /obj/item/screwdriver))
		if(!locked)
			open = !open
			to_chat(user, "<span class='notice'>The maintenance panel is now [open ? "opened" : "closed"].</span>")
		else
			to_chat(user, "<span class='warning'>The maintenance panel is locked.</span>")
	else if(istype(W, /obj/item/card/id) || istype(W, /obj/item/pda))
		if(bot_core.allowed(user) && !open && !emagged)
			locked = !locked
			to_chat(user, "Controls are now [locked ? "locked." : "unlocked."]")
		else
			if(emagged)
				to_chat(user, "<span class='danger'>ERROR</span>")
			if(open)
				to_chat(user, "<span class='warning'>Please close the access panel before locking it.</span>")
			else
				to_chat(user, "<span class='warning'>Access denied.</span>")
	else if(istype(W, /obj/item/paicard))
		if(paicard)
			to_chat(user, "<span class='warning'>A [paicard] is already inserted!</span>")
		else if(allow_pai && !key)
			if(!locked && !open)
				var/obj/item/paicard/card = W
				if(card.pai && card.pai.mind)
					if(!card.pai.ckey || jobban_isbanned(card.pai, ROLE_SENTIENT))
						to_chat(user, "<span class='warning'>[W] is unable to establish a connection to [src].</span>")
						return
					if(!user.drop_item())
						return
					W.forceMove(src)
					paicard = card
					user.visible_message("[user] inserts [W] into [src]!","<span class='notice'>You insert [W] into [src].</span>")
					paicard.pai.mind.transfer_to(src)
					to_chat(src, "<span class='notice'>You sense your form change as you are uploaded into [src].</span>")
					bot_name = name
					name = paicard.pai.name
					faction = user.faction
					add_attack_logs(user, paicard.pai, "Uploaded to [src.bot_name]")
				else
					to_chat(user, "<span class='warning'>[W] is inactive.</span>")
			else
				to_chat(user, "<span class='warning'>The personality slot is locked.</span>")
		else
			to_chat(user, "<span class='warning'>[src] is not compatible with [W].</span>")
	else if(istype(W, /obj/item/hemostat) && paicard)
		if(open)
			to_chat(user, "<span class='warning'>Close the access panel before manipulating the personality slot!</span>")
		else
			to_chat(user, "<span class='notice'>You attempt to pull [paicard] free...</span>")
			if(do_after(user, 30 * W.toolspeed, target = src))
				if(paicard)
					user.visible_message("<span class='notice'>[user] uses [W] to pull [paicard] out of [bot_name]!</span>","<span class='notice'>You pull [paicard] out of [bot_name] with [W].</span>")
					ejectpai(user)
	else
		return ..()

/mob/living/simple_animal/bot/welder_act(mob/user, obj/item/I)
	if(user.a_intent != INTENT_HELP)
		return
	if(user == src) //No self-repair dummy
		return
	. = TRUE
	if(health >= maxHealth)
		to_chat(user, "<span class='warning'>[src] does not need a repair!</span>")
		return
	if(!open)
		to_chat(user, "<span class='warning'>Unable to repair with the maintenance panel closed!</span>")
		return
	if(!I.use_tool(src, user, volume = I.tool_volume))
		return
	adjustBruteLoss(-10)
	add_fingerprint(user)
	user.visible_message("[user] repairs [src]!","<span class='notice'>You repair [src].</span>")

/mob/living/simple_animal/bot/bullet_act(obj/item/projectile/Proj)
	if(Proj && (Proj.damage_type == BRUTE || Proj.damage_type == BURN))
		if(prob(75) && Proj.damage > 0)
			do_sparks(5, 1, src)
	return ..()

/mob/living/simple_animal/bot/emp_act(severity)
	var/was_on = on
	stat |= EMPED
	var/obj/effect/overlay/pulse2 = new/obj/effect/overlay ( loc )
	pulse2.icon = 'icons/effects/effects.dmi'
	pulse2.icon_state = "empdisable"
	pulse2.name = "emp sparks"
	pulse2.anchored = 1
	pulse2.dir = pick(GLOB.cardinal)
	QDEL_IN(pulse2, 10)

	if(paicard)
		paicard.emp_act(severity)
		src.visible_message("[paicard] is flies out of [bot_name]!","<span class='warning'>You are forcefully ejected from [bot_name]!</span>")
		ejectpai(0)
	if(on)
		turn_off()
	spawn(severity*300)
		stat &= ~EMPED
		if(was_on)
			turn_on()

/mob/living/simple_animal/bot/rename_character(oldname, newname)
	if(!..(oldname, newname))
		return 0

	set_custom_texts()
	return 1

/mob/living/simple_animal/bot/proc/set_custom_texts() //Superclass for setting hack texts. Appears only if a set is not given to a bot locally.
	text_hack = "You hack [name]."
	text_dehack = "You reset [name]."
	text_dehack_fail = "You fail to reset [name]."

/mob/living/simple_animal/bot/proc/speak(message, channel) //Pass a message to have the bot say() it. Pass a frequency to say it on the radio.
	if((!on) || (!message))
		return
	if(channel)
		Radio.autosay(message, name, channel == "headset" ? null : channel)
	else
		say(message)
	return

//Generalized behavior code, override where needed!

/*
scan() will search for a given type (such as turfs, human mobs, or objects) in the bot's view range, and return a single result.
Arguments: The object type to be searched (such as "/mob/living/carbon/human"), the old scan result to be ignored, if one exists,
and the view range, which defaults to 7 (full screen) if an override is not passed.
If the bot maintains an ignore list, it is also checked here.

Example usage: patient = scan(/mob/living/carbon/human, oldpatient, 1)
The proc would return a human next to the bot to be set to the patient var.
Pass the desired type path itself, declaring a temporary var beforehand is not required.
*/
/mob/living/simple_animal/bot/proc/scan(atom/scan_type, atom/old_target, scan_range = DEFAULT_SCAN_RANGE)
	var/final_result
	for(var/scan in shuffle(view(scan_range, src))) //Search for something in range!
		var/atom/A = scan
		if(!istype(A, scan_type)) //Check that the thing we found is the type we want!
			continue //If not, keep searching!
		if((A.UID() in ignore_list) || (A == old_target) ) //Filter for blacklisted elements, usually unreachable or previously processed oness
			continue
		var/scan_result = process_scan(A) //Some bots may require additional processing when a result is selected.
		if(scan_result)
			final_result = scan_result
		else
			continue //The current element failed assessment, move on to the next.
		return final_result

//When the scan finds a target, run bot specific processing to select it for the next step. Empty by default.
/mob/living/simple_animal/bot/proc/process_scan(atom/scan_target)
	return scan_target


/mob/living/simple_animal/bot/proc/add_to_ignore(atom/A)
	if(ignore_list.len < 50) //This will help keep track of them, so the bot is always trying to reach a blocked spot.
		ignore_list |= A.UID()
	else  //If the list is full, insert newest, delete oldest.
		ignore_list.Cut(1, 2)
		ignore_list |= A.UID()
/*
Movement proc for stepping a bot through a path generated through A-star.
Pass a positive integer as an argument to override a bot's default speed.
*/
/mob/living/simple_animal/bot/proc/bot_move(dest, move_speed)

	if(!dest || !path || path.len == 0) //A-star failed or a path/destination was not set.
		set_path(null)
		return 0
	dest = get_turf(dest) //We must always compare turfs, so get the turf of the dest var if dest was originally something else.
	var/turf/last_node = get_turf(path[path.len]) //This is the turf at the end of the path, it should be equal to dest.
	if(get_turf(src) == dest) //We have arrived, no need to move again.
		return 1
	else if(dest != last_node) //The path should lead us to our given destination. If this is not true, we must stop.
		set_path(null)
		return 0
	var/step_count = move_speed ? move_speed : base_speed //If a value is passed into move_speed, use that instead of the default speed var.

	if(step_count >= 1 && tries < BOT_STEP_MAX_RETRIES)
		for(var/step_number = 0, step_number < step_count,step_number++)
			spawn(BOT_STEP_DELAY*step_number)
				bot_step(dest)
	else
		return 0
	return 1


/mob/living/simple_animal/bot/proc/bot_step(dest) //Step,increase tries if failed
	if(!path)
		return 0
	if(path.len > 1)
		Move(path[1], get_dir(src, path[1]), BOT_STEP_DELAY)
		if(get_turf(src) == path[1]) //Successful move
			increment_path()
			tries = 0
		else
			tries++
			return 0
	else if(path.len == 1)
		step_to(src, dest)
		set_path(null)
	return 1


/mob/living/simple_animal/bot/proc/check_bot_access()
	if(mode != BOT_SUMMON && mode != BOT_RESPONDING)
		access_card.access = prev_access

/mob/living/simple_animal/bot/proc/call_bot(caller, turf/waypoint, message=TRUE)
	bot_reset() //Reset a bot before setting it to call mode.
	var/area/end_area = get_area(waypoint)

	//For giving the bot temporary all-access.
	var/obj/item/card/id/all_access = new /obj/item/card/id
	var/datum/job/captain/All = new/datum/job/captain
	all_access.access = All.get_access()

	set_path(get_path_to(src, waypoint, /turf/proc/Distance_cardinal, 0, 200, id=all_access))
	calling_ai = caller //Link the AI to the bot!
	ai_waypoint = waypoint

	if(path && path.len) //Ensures that a valid path is calculated!
		if(!on)
			turn_on() //Saves the AI the hassle of having to activate a bot manually.
		access_card = all_access //Give the bot all-access while under the AI's command.
		if(client)
			reset_access_timer_id = addtimer(CALLBACK (src, .proc/bot_reset), 600, TIMER_OVERRIDE|TIMER_STOPPABLE) //if the bot is player controlled, they get the extra access for a limited time
			to_chat(src, "<span class='notice'><span class='big'>Priority waypoint set by [calling_ai] <b>[caller]</b>. Proceed to <b>[end_area.name]</b>.</span><br>[path.len-1] meters to destination. You have been granted additional door access for 60 seconds.</span>")
		if(message)
			to_chat(calling_ai, "<span class='notice'>[bicon(src)] [name] called to [end_area.name]. [path.len-1] meters to destination.</span>")
		pathset = 1
		mode = BOT_RESPONDING
		tries = 0
	else
		if(message)
			to_chat(calling_ai, "<span class='danger'>Failed to calculate a valid route. Ensure destination is clear of obstructions and within range.</span>")
		calling_ai = null
		set_path(null)

/mob/living/simple_animal/bot/proc/call_mode() //Handles preparing a bot for a call, as well as calling the move proc.
//Handles the bot's movement during a call.
	var/success = bot_move(ai_waypoint, 3)
	if(!success)
		if(calling_ai)
			to_chat(calling_ai, "[bicon(src)] [get_turf(src) == ai_waypoint ? "<span class='notice'>[src] successfully arrived to waypoint.</span>" : "<span class='danger'>[src] failed to reach waypoint.</span>"]")
			calling_ai = null
		bot_reset()

/mob/living/simple_animal/bot/proc/bot_reset()
	if(calling_ai) //Simple notification to the AI if it called a bot. It will not know the cause or identity of the bot.
		to_chat(calling_ai, "<span class='danger'>Call command to a bot has been reset.</span>")
		calling_ai = null
	if(reset_access_timer_id)
		deltimer(reset_access_timer_id)
		reset_access_timer_id = null
 	set_path(null)
	summon_target = null
	pathset = 0
	access_card.access = prev_access
	tries = 0
	mode = BOT_IDLE
	diag_hud_set_botstat()
	diag_hud_set_botmode()




//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//Patrol and summon code!
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

/mob/living/simple_animal/bot/proc/bot_patrol()
	patrol_step()
	spawn(5)
		if(mode == BOT_PATROL)
			patrol_step()
	return

/mob/living/simple_animal/bot/proc/start_patrol()

	if(tries >= BOT_STEP_MAX_RETRIES) //Bot is trapped, so stop trying to patrol.
		auto_patrol = 0
		tries = 0
		speak("Unable to start patrol.")

		return

	if(!auto_patrol) //A bot not set to patrol should not be patrolling.
		mode = BOT_IDLE
		return

	if(patrol_target)		// has patrol target
		spawn(0)
			calc_path()		// Find a route to it
			if(path.len == 0)
				patrol_target = null
				return
			mode = BOT_PATROL
	else					// no patrol target, so need a new one
		speak("Engaging patrol mode.")
		find_patrol_target()
		tries++
	return

// perform a single patrol step

/mob/living/simple_animal/bot/proc/patrol_step()

	if(client)		// In use by player, don't actually move.
		return

	if(loc == patrol_target)		// reached target
		//Find the next beacon matching the target.
		if(!get_next_patrol_target())
			find_patrol_target() //If it fails, look for the nearest one instead.
		return

	else if(path.len && patrol_target)		// valid path
		var/turf/next = path[1]
		if(next == loc)
			increment_path()
			return


		var/moved = bot_move(patrol_target)//step_towards(src, next)	// attempt to move
		if(!moved) //Couldn't proceed the next step of the path BOT_STEP_MAX_RETRIES times
			spawn(2)
				calc_path()
				if(path.len == 0)
					find_patrol_target()
				tries = 0

	else	// no path, so calculate new one
		mode = BOT_START_PATROL

// finds the nearest beacon to self
/mob/living/simple_animal/bot/proc/find_patrol_target()
	send_status()
	nearest_beacon = null
	new_destination = null
	find_nearest_beacon()
	if(nearest_beacon)
		patrol_target = nearest_beacon_loc
		destination = next_destination
	else
		auto_patrol = 0
		mode = BOT_IDLE
		speak("Disengaging patrol mode.")
		send_status()

/mob/living/simple_animal/bot/proc/get_next_patrol_target()
	// search the beacon list for the next target in the list.
	for(var/obj/machinery/navbeacon/NB in GLOB.navbeacons["[z]"])
		if(NB.location == next_destination) //Does the Beacon location text match the destination?
			destination = new_destination //We now know the name of where we want to go.
			patrol_target = NB.loc //Get its location and set it as the target.
			next_destination = NB.codes["next_patrol"] //Also get the name of the next beacon in line.
			return 1

/mob/living/simple_animal/bot/proc/find_nearest_beacon()
	for(var/obj/machinery/navbeacon/NB in GLOB.navbeacons["[z]"])
		var/dist = get_dist(src, NB)
		if(nearest_beacon) //Loop though the beacon net to find the true closest beacon.
			//Ignore the beacon if were are located on it.
			if(dist>1 && dist<get_dist(src,nearest_beacon_loc))
				nearest_beacon = NB.location
				nearest_beacon_loc = NB.loc
				next_destination = NB.codes["next_patrol"]
			else
				continue
		else if(dist > 1) //Begin the search, save this one for comparison on the next loop.
			nearest_beacon = NB.location
			nearest_beacon_loc = NB.loc
	patrol_target = nearest_beacon_loc
	destination = nearest_beacon

/mob/living/simple_animal/bot/proc/bot_control_message(command, mob/user, user_turf)
	switch(command)
		if("stop")
			to_chat(src, "<span class='warning big'>STOP PATROL</span>")
		if("go")
			to_chat(src, "<span class='warning big'>START PATROL</span>")
		if("summon")
			var/area/a = get_area(user_turf)
			to_chat(src, "<span class='warning big'>PRIORITY ALERT: [user] in [a.name]!</span>")
		if("home")
			to_chat(src, "<span class='warning big'>RETURN HOME!</span>")
		if("ejectpai")
		else
			to_chat(src, "<span class='warning'>Unidentified control sequence recieved: [command]</span>")

/obj/machinery/bot_core/receive_signal(datum/signal/signal)
	owner.receive_signal(signal)

/mob/living/simple_animal/bot/proc/receive_signal(datum/signal/signal)
	if(!on)
		return 1 //ACCESS DENIED

	var/recv = signal.data["command"]
	var/user = signal.data["user"]

	// process all-bot input
	if(recv == "bot_status" && (!signal.data["active"] || signal.data["active"] == src))
		send_status()
		return 1

	// check to see if we are the commanded bot
	if(signal.data["active"] == src)
		if(emagged == 2 || remote_disabled) //Emagged bots do not respect anyone's authority! Bots with their remote controls off cannot get commands.
			return 1
		if(client)
			bot_control_message(recv, user, signal.data["target"] ? signal.data["target"] : "Unknown")
		// process control input
		switch(recv)
			if("stop")
				bot_reset() //HOLD IT!!
				auto_patrol = 0

			if("go")
				auto_patrol = 1

			if("summon")
				bot_reset()
				var/list/user_access = signal.data["useraccess"]
				summon_target = signal.data["target"]	//Location of the user
				if(user_access.len != 0)
					access_card.access = user_access + prev_access //Adds the user's access, if any.
				mode = BOT_SUMMON
				calc_summon_path()
				speak("Responding.", radio_channel)

			else
				return 0
	return 1

// send a radio signal with a single data key/value pair
/mob/living/simple_animal/bot/proc/post_signal(var/freq, var/key, var/value)
	post_signal_multiple(freq, list("[key]" = value) )

// send a radio signal with multiple data key/values
/mob/living/simple_animal/bot/proc/post_signal_multiple(var/freq, var/list/keyval)
	if(!is_station_level(z)) //Bot control will only work on station.
		return
	var/datum/radio_frequency/frequency = SSradio.return_frequency(freq)
	if(!frequency)
		return

	var/datum/signal/signal = new()
	signal.source = bot_core
	signal.transmission_method = 1
	signal.data = keyval
	spawn()
		if(signal.data["type"] == bot_type)
			frequency.post_signal(bot_core, signal, filter = bot_filter)
		else
			frequency.post_signal(bot_core, signal)

// signals bot status etc. to controller
/mob/living/simple_animal/bot/proc/send_status()
	if(remote_disabled || emagged == 2)
		return
	var/list/kv = list(
	"type" = bot_type,
	"name" = name,
	"loca" = get_area(src),	// area
	"mode" = mode
	)
	post_signal_multiple(control_freq, kv)

/mob/living/simple_animal/bot/proc/bot_summon() // summoned to PDA
	summon_step()

// calculates a path to the current destination
// given an optional turf to avoid
/mob/living/simple_animal/bot/proc/calc_path(turf/avoid)
	check_bot_access()
	set_path(get_path_to(src, patrol_target, /turf/proc/Distance_cardinal, 0, 120, id=access_card, exclude=avoid))

/mob/living/simple_animal/bot/proc/calc_summon_path(turf/avoid)
	check_bot_access()
	spawn()
		set_path(get_path_to(src, summon_target, /turf/proc/Distance_cardinal, 0, 150, id=access_card, exclude=avoid))
		if(!path.len) //Cannot reach target. Give up and announce the issue.
			speak("Summon command failed, destination unreachable.",radio_channel)
			bot_reset()

/mob/living/simple_animal/bot/proc/summon_step()

	if(client)		// In use by player, don't actually move.
		return

	if(loc == summon_target)		// Arrived to summon location.
		bot_reset()
		return

	else if(path.len && summon_target)		//Proper path acquired!
		var/turf/next = path[1]
		if(next == loc)
			increment_path()
			return

		var/moved = bot_move(summon_target, 3)	// Move attempt
		if(!moved)
			spawn(2)
				calc_summon_path()
				tries = 0

	else	// no path, so calculate new one
		calc_summon_path()

/mob/living/simple_animal/bot/proc/openedDoor(obj/machinery/door/D)
	frustration = 0

/mob/living/simple_animal/bot/show_inv()
	return

/mob/living/simple_animal/bot/proc/show_controls(mob/M)
	users |= M
	var/dat = {"<meta charset="UTF-8">"}
	dat += get_controls(M)
	var/datum/browser/popup = new(M,window_id,window_name,350,600)
	popup.set_content(dat)
	popup.open()
	onclose(M,window_id,ref=src)
	return

/mob/living/simple_animal/bot/proc/update_controls()
	for(var/mob/M in users)
		show_controls(M)

/mob/living/simple_animal/bot/proc/get_controls(mob/M)
	return "PROTOBOT - NOT FOR USE"

/mob/living/simple_animal/bot/Topic(href, href_list)
	if(href_list["close"])// HUE HUE
		if(usr in users)
			users.Remove(usr)
		return 1

	if(topic_denied(usr))
		to_chat(usr, "<span class='warning'>[src]'s interface is not responding!</span>")
		return 1
	add_fingerprint(usr)

	if((href_list["power"]) && (bot_core.allowed(usr) || !locked || usr.can_admin_interact()))
		if(on)
			turn_off()
		else
			turn_on()

	switch(href_list["operation"])
		if("patrol")
			auto_patrol = !auto_patrol
			bot_reset()
		if("remote")
			remote_disabled = !remote_disabled
		if("hack")
			handle_hacking(usr)
		if("ejectpai")
			if(paicard && (!locked || issilicon(usr) || usr.can_admin_interact()))
				to_chat(usr, "<span class='notice'>You eject [paicard] from [bot_name]</span>")
				ejectpai(usr)
	update_controls()

/mob/living/simple_animal/bot/proc/canhack(mob/M)
	return ((issilicon(M) && (!emagged || hacked)) || M.can_admin_interact())

/mob/living/simple_animal/bot/proc/handle_hacking(mob/M) // refactored out of Topic/ to allow re-use by TGUIs
	if(!canhack(M))
		return
	if(emagged != 2)
		emagged = 2
		hacked = TRUE
		locked = TRUE
		to_chat(M, "<span class='warning'>[text_hack]</span>")
		show_laws()
		bot_reset()
		add_attack_logs(M, src, "Hacked")
	else if(!hacked)
		to_chat(M, "<span class='userdanger'>[text_dehack_fail]</span>")
	else
		emagged = FALSE
		hacked = FALSE
		to_chat(M, "<span class='notice'>[text_dehack]</span>")
		show_laws()
		bot_reset()
		add_attack_logs(M, src, "Dehacked")

/mob/living/simple_animal/bot/proc/update_icon()
	icon_state = "[initial(icon_state)][on]"

// Machinery to simplify topic and access calls
/obj/machinery/bot_core
	use_power = NO_POWER_USE
	var/mob/living/simple_animal/bot/owner = null

/obj/machinery/bot_core/New(loc)
	..()
	owner = loc
	if(!istype(owner))
		qdel(src)

/mob/living/simple_animal/bot/proc/topic_denied(mob/user) //Access check proc for bot topics! Remember to place in a bot's individual Topic if desired.
	if(user.can_admin_interact())
		return FALSE
	if(user.incapacitated() || !(issilicon(user) || in_range(src, user)))
		return TRUE
	if(emagged == 2) //An emagged bot cannot be controlled by humans, silicons can if one hacked it.
		if(!hacked) //Manually emagged by a human - access denied to all.
			return TRUE
		else if(!issilicon(user)) //Bot is hacked, so only silicons are allowed access.
			return TRUE
	if(locked && !issilicon(user))
		return TRUE
	return FALSE

/mob/living/simple_animal/bot/proc/hack(mob/user)
	var/hack
	if(issilicon(user) || user.can_admin_interact()) //Allows silicons or admins to toggle the emag status of a bot.
		hack += "[emagged == 2 ? "Software compromised! Unit may exhibit dangerous or erratic behavior." : "Unit operating normally. Release safety lock?"]<BR>"
		hack += "Harm Prevention Safety System: <A href='?src=[UID()];operation=hack'>[emagged ? "<span class='bad'>DANGER</span>" : "Engaged"]</A><BR>"
	else if(!locked) //Humans with access can use this option to hide a bot from the AI's remote control panel and PDA control.
		hack += "Remote network control radio: <A href='?src=[UID()];operation=remote'>[remote_disabled ? "Disconnected" : "Connected"]</A><BR>"
	return hack

/mob/living/simple_animal/bot/proc/showpai(mob/user)
	var/eject = ""
	if(!locked || issilicon(usr) || user.can_admin_interact())
		if(paicard || allow_pai)
			eject += "Personality card status: "
			if(paicard)
				if(client)
					eject += "<A href='?src=[UID()];operation=ejectpai'>Active</A>"
				else
					eject += "<A href='?src=[UID()];operation=ejectpai'>Inactive</A>"
			else if(!allow_pai || key)
				eject += "Unavailable"
			else
				eject += "Not inserted"
			eject += "<BR>"
		eject += "<BR>"
	return eject

/mob/living/simple_animal/bot/proc/ejectpai(mob/user = null, announce = 1)
	if(paicard)
		if(mind && paicard.pai)
			mind.transfer_to(paicard.pai)
		else if(paicard.pai)
			paicard.pai.key = key
		else
			ghostize(0) // The pAI card that just got ejected was dead.
		key = null
		paicard.forceMove(loc)
		if(user)
			add_attack_logs(user, paicard.pai, "Ejected from [src.bot_name],")
		else
			add_attack_logs(src, paicard.pai, "Ejected")
		if(announce)
			to_chat(paicard.pai, "<span class='notice'>You feel your control fade as [paicard] ejects from [bot_name].</span>")
		paicard = null
		name = bot_name
		faction = initial(faction)

/mob/living/simple_animal/bot/proc/ejectpairemote(mob/user)
	if(bot_core.allowed(user) && paicard)
		speak("Ejecting personality chip.", radio_channel)
		ejectpai(user)

/mob/living/simple_animal/bot/Login()
	. = ..()
	access_card.access += player_access
	diag_hud_set_botmode()
	show_laws()

/mob/living/simple_animal/bot/Logout()
	. = ..()
	bot_reset()

/mob/living/simple_animal/bot/revive(full_heal = 0, admin_revive = 0)
	if(..())
		update_icon()
		. = 1

/mob/living/simple_animal/bot/ghost()
	if(stat != DEAD) // Only ghost if we're doing this while alive, the pAI probably isn't dead yet.
		..()
	if(paicard && (!client || stat == DEAD))
		ejectpai(0)

/mob/living/simple_animal/bot/sentience_act()
	faction -= "silicon"

/mob/living/simple_animal/bot/verb/show_laws()
	set name = "Show Directives"
	set category = "IC"

	to_chat(src, "<b>Directives:</b>")
	if(paicard && paicard.pai && paicard.pai.master && paicard.pai.pai_law0)
		to_chat(src, "<span class='warning'>Your master, [paicard.pai.master], may overrule any and all laws.</span>")
		to_chat(src, "0. [paicard.pai.pai_law0]")
	if(emagged >= 2)
		to_chat(src, "<span class='danger'>1. #$!@#$32K#$</span>")
	else
		to_chat(src, "1. You are a machine built to serve the station's crew and AI(s).")
		to_chat(src, "2. Your function is to [bot_purpose].")
		to_chat(src, "3. You cannot serve your function if you are broken.")
		to_chat(src, "4. Serve your function to the best of your ability.")
	if(paicard && paicard.pai && paicard.pai.pai_laws)
		to_chat(src, "<b>Supplemental Directive(s):</b>")
		to_chat(src, "[paicard.pai.pai_laws]")

/mob/living/simple_animal/bot/get_access()
	. = ..()

	if(access_card)
		. |= access_card.GetAccess()

/mob/living/simple_animal/bot/proc/door_opened(obj/machinery/door/D)
	frustration = 0

/mob/living/simple_animal/bot/handle_message_mode(var/message_mode, var/message, var/verb, var/speaking, var/used_radios)
	switch(message_mode)
		if("intercom")
			for(var/obj/item/radio/intercom/I in view(1, src))
				spawn(0)
					I.talk_into(src, message, null, verb, speaking)
				used_radios += I
		if("headset")
			Radio.talk_into(src, message, null, verb, speaking)
			used_radios += Radio
		else
			if(message_mode)
				Radio.talk_into(src, message, message_mode, verb, speaking)
				used_radios += Radio

/mob/living/simple_animal/bot/is_mechanical()
	return 1

/mob/living/simple_animal/bot/proc/set_path(list/newpath)
	path = newpath ? newpath : list()
	if(!path_hud)
		return
	var/list/path_huds_watching_me = list(GLOB.huds[DATA_HUD_DIAGNOSTIC_ADVANCED])
	if(path_hud)
		path_huds_watching_me += path_hud
	for(var/V in path_huds_watching_me)
		var/datum/atom_hud/H = V
		H.remove_from_hud(src)

	var/list/path_images = hud_list[DIAG_PATH_HUD]
	QDEL_LIST(path_images)
	if(newpath)
		for(var/i in 1 to newpath.len)
			var/turf/T = newpath[i]
			var/direction = NORTH
			if(i > 1)
				var/turf/prevT = path[i - 1]
				var/image/prevI = path[prevT]
				direction = get_dir(prevT, T)
				if(i > 2)
					var/turf/prevprevT = path[i - 2]
					var/prevDir = get_dir(prevprevT, prevT)
					var/mixDir = direction|prevDir
					if(mixDir in GLOB.diagonals)
						prevI.dir = mixDir
						if(prevDir & (NORTH|SOUTH))
							var/matrix/ntransform = matrix()
							ntransform.Turn(90)
							if((mixDir == NORTHWEST) || (mixDir == SOUTHEAST))
								ntransform.Scale(-1, 1)
							else
								ntransform.Scale(1, -1)
							prevI.transform = ntransform
			var/mutable_appearance/MA = new /mutable_appearance()
			MA.icon = path_image_icon
			MA.icon_state = path_image_icon_state
			MA.layer = ABOVE_OPEN_TURF_LAYER
			MA.plane = 0
			MA.appearance_flags = RESET_COLOR|RESET_TRANSFORM
			MA.color = path_image_color
			MA.dir = direction
			var/image/I = image(loc = T)
			I.appearance = MA
			path[T] = I
			path_images += I

	for(var/V in path_huds_watching_me)
		var/datum/atom_hud/H = V
		H.add_to_hud(src)


/mob/living/simple_animal/bot/proc/increment_path()
	if(!path || !path.len)
		return
	var/image/I = path[path[1]]
	if(I)
		I.icon = null
	path.Cut(1, 2)

/mob/living/simple_animal/bot/proc/drop_part(obj/item/drop_item, dropzone)
	new drop_item(dropzone)
