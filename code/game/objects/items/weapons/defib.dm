//backpack item

/obj/item/defibrillator
	name = "defibrillator"
	desc = "A device that delivers powerful shocks to detachable paddles that resuscitate incapacitated patients."
	icon_state = "defibunit"
	item_state = "defibunit"
	slot_flags = SLOT_BACK
	force = 5
	throwforce = 6
	w_class = WEIGHT_CLASS_BULKY
	origin_tech = "biotech=4"
	actions_types = list(/datum/action/item_action/toggle_paddles)
	armor = list("melee" = 0, "bullet" = 0, "laser" = 0, "energy" = 0, "bomb" = 0, "bio" = 0, "rad" = 0, "fire" = 50, "acid" = 50)
	sprite_sheets = list(
		"Vox" = 'icons/mob/species/vox/back.dmi'
		)

	var/paddles_on_defib = TRUE //if the paddles are on the defib (TRUE)
	var/safety = TRUE //if you can zap people with the defibs on harm mode
	var/powered = FALSE //if there's a cell in the defib with enough power for a revive, blocks paddles from reviving otherwise
	var/obj/item/twohanded/shockpaddles/paddles
	var/obj/item/stock_parts/cell/high/cell = null
	var/combat = FALSE //can we revive through space suits?

/obj/item/defibrillator/get_cell()
	return cell

/obj/item/defibrillator/New() //starts without a cell for rnd
	..()
	paddles = make_paddles()
	update_icon()
	return

/obj/item/defibrillator/loaded/New() //starts with hicap
	..()
	paddles = make_paddles()
	cell = new(src)
	update_icon()
	return

/obj/item/defibrillator/update_icon()
	update_power()
	update_overlays()
	update_charge()

/obj/item/defibrillator/examine(mob/user)
	. = ..()
	. += "<span class='notice'>Ctrl-click to remove the paddles from the defibrillator.</span>"

/obj/item/defibrillator/proc/update_power()
	if(cell)
		if(cell.charge < paddles.revivecost)
			powered = FALSE
		else
			powered = TRUE
	else
		powered = FALSE

/obj/item/defibrillator/proc/update_overlays()
	overlays.Cut()
	if(paddles_on_defib)
		overlays += "[icon_state]-paddles"
	if(powered)
		overlays += "[icon_state]-powered"
	if(!cell)
		overlays += "[icon_state]-nocell"
	if(!safety)
		overlays += "[icon_state]-emagged"

/obj/item/defibrillator/proc/update_charge()
	if(powered && cell) //so it doesn't show charge if it's unpowered
		var/ratio = cell.charge / cell.maxcharge
		ratio = CEILING(ratio*4, 1) * 25
		overlays += "[icon_state]-charge[ratio]"

/obj/item/defibrillator/CheckParts(list/parts_list)
	..()
	cell = locate(/obj/item/stock_parts/cell) in contents
	update_icon()

/obj/item/defibrillator/ui_action_click()
	if(ishuman(usr) && Adjacent(usr))
		toggle_paddles()

/obj/item/defibrillator/CtrlClick()
	if(ishuman(usr) && Adjacent(usr))
		toggle_paddles()

/obj/item/defibrillator/attackby(obj/item/W, mob/user, params)
	if(istype(W, /obj/item/stock_parts/cell))
		var/obj/item/stock_parts/cell/C = W
		if(cell)
			to_chat(user, "<span class='notice'>[src] already has a cell.</span>")
		else
			if(C.maxcharge < paddles.revivecost)
				to_chat(user, "<span class='notice'>[src] requires a higher capacity cell.</span>")
				return
			user.drop_item()
			W.loc = src
			cell = W
			to_chat(user, "<span class='notice'>You install a cell in [src].</span>")

	if(istype(W, /obj/item/screwdriver))
		if(cell)
			cell.update_icon()
			cell.loc = get_turf(loc)
			cell = null
			to_chat(user, "<span class='notice'>You remove the cell from the [src].</span>")

	update_icon()
	return

/obj/item/defibrillator/emag_act(user as mob)
	if(safety)
		safety = FALSE
		to_chat(user, "<span class='warning'>You silently disable [src]'s safety protocols with the card.")
	else
		safety = TRUE
		to_chat(user, "<span class='notice'>You silently enable [src]'s safety protocols with the card.")

/obj/item/defibrillator/emp_act(severity)
	if(cell)
		deductcharge(1000 / severity)
	if(safety)
		safety = FALSE
		visible_message("<span class='notice'>[src] beeps: Safety protocols disabled!</span>")
		playsound(get_turf(src), 'sound/machines/defib_saftyoff.ogg', 50, 0)
	else
		safety = TRUE
		visible_message("<span class='notice'>[src] beeps: Safety protocols enabled!</span>")
		playsound(get_turf(src), 'sound/machines/defib_saftyon.ogg', 50, 0)
	update_icon()
	..()

/obj/item/defibrillator/verb/toggle_paddles()
	set name = "Toggle Paddles"
	set category = "Object"

	var/mob/living/carbon/human/user = usr
	var/obj/item/organ/external/temp2 = user.bodyparts_by_name["r_hand"]
	var/obj/item/organ/external/temp = user.bodyparts_by_name["l_hand"]

	if(paddles_on_defib)
		//Detach the paddles into the user's hands
		if(usr.incapacitated()) return

		if(!temp || !temp.is_usable() && !temp2 || !temp2.is_usable())
			to_chat(user, "<span class='warning'>You can't use your hand to take out the paddles!</span>")
			return

		if((usr.r_hand != null && usr.l_hand != null))
			to_chat(user, "<span class='warning'>You need a free hand to hold the paddles!</span>")
			return

		if(!usr.put_in_hands(paddles))
			to_chat(user, "<span class='warning'>You need a free hand to hold the paddles!</span>")
			return
		paddles.loc = user
		paddles_on_defib = FALSE
	else //remove in any case because some automatic shit
		remove_paddles(user)

	update_icon()
	for(var/X in actions)
		var/datum/action/A = X
		A.UpdateButtonIcon()

/obj/item/defibrillator/proc/make_paddles()
	return new /obj/item/twohanded/shockpaddles(src)

/obj/item/defibrillator/equipped(mob/user, slot)
	..()
	if(slot != slot_back)
		remove_paddles(user)
		update_icon()

/obj/item/defibrillator/item_action_slot_check(slot, mob/user)
	if(slot == slot_back)
		return TRUE

/obj/item/defibrillator/proc/remove_paddles(mob/user) // from your hands
	var/mob/living/carbon/human/M = user
	if(paddles in get_both_hands(M))
		M.unEquip(paddles)
		paddles_on_defib = TRUE
	update_icon()
	return

/obj/item/defibrillator/Destroy()
	if(!paddles_on_defib)
		var/M = get(paddles, /mob)
		remove_paddles(M)
	QDEL_NULL(paddles)
	QDEL_NULL(cell)
	return ..()

/obj/item/defibrillator/proc/deductcharge(var/chrgdeductamt)
	if(cell)
		if(cell.charge < (paddles.revivecost+chrgdeductamt))
			powered = FALSE
			update_icon()
		if(cell.use(chrgdeductamt))
			update_icon()
			return TRUE
		else
			update_icon()
			return FALSE

/obj/item/defibrillator/proc/cooldowncheck(var/mob/user)
	spawn(50)
		if(cell)
			if(cell.charge >= paddles.revivecost)
				user.visible_message("<span class='notice'>[src] beeps: Unit ready.</span>")
				playsound(get_turf(src), 'sound/machines/defib_ready.ogg', 50, 0)
			else
				user.visible_message("<span class='notice'>[src] beeps: Charge depleted.</span>")
				playsound(get_turf(src), 'sound/machines/defib_failed.ogg', 50, 0)
		paddles.cooldown = FALSE
		paddles.update_icon()
		update_icon()

/obj/item/defibrillator/compact
	name = "compact defibrillator"
	desc = "A belt-equipped defibrillator that can be rapidly deployed."
	icon_state = "defibcompact"
	item_state = "defibcompact"
	w_class = WEIGHT_CLASS_NORMAL
	slot_flags = SLOT_BELT
	origin_tech = "biotech=5"

/obj/item/defibrillator/compact/item_action_slot_check(slot, mob/user)
	if(slot == slot_belt)
		return TRUE

/obj/item/defibrillator/compact/loaded/New()
	..()
	paddles = make_paddles()
	cell = new(src)
	update_icon()
	return

/obj/item/defibrillator/compact/combat
	name = "combat defibrillator"
	desc = "A belt-equipped blood-red defibrillator that can be rapidly deployed. Does not have the restrictions or safeties of conventional defibrillators and can revive through space suits."
	combat = TRUE
	safety = FALSE

/obj/item/defibrillator/compact/combat/loaded/New()
	..()
	paddles = make_paddles()
	cell = new(src)
	update_icon()
	return

/obj/item/defibrillator/compact/combat/attackby(obj/item/W, mob/user, params)
	if(W == paddles)
		paddles.unwield()
		toggle_paddles()
		update_icon()
		return

//paddles

/obj/item/twohanded/shockpaddles
	name = "defibrillator paddles"
	desc = "A pair of plastic-gripped paddles with flat metal surfaces that are used to deliver powerful electric shocks."
	icon_state = "defibpaddles"
	item_state = "defibpaddles"
	force = 0
	throwforce = 6
	w_class = WEIGHT_CLASS_BULKY
	resistance_flags = INDESTRUCTIBLE
	toolspeed = 1

	var/revivecost = 1000
	var/cooldown = FALSE
	var/busy = FALSE
	var/obj/item/defibrillator/defib

/obj/item/twohanded/shockpaddles/New(mainunit)
	..()
	if(check_defib_exists(mainunit, src))
		defib = mainunit
		loc = defib
		busy = FALSE
		update_icon()
	return

/obj/item/twohanded/shockpaddles/update_icon()
	icon_state = "defibpaddles[wielded]"
	item_state = "defibpaddles[wielded]"
	if(cooldown)
		icon_state = "defibpaddles[wielded]_cooldown"

/obj/item/twohanded/shockpaddles/suicide_act(mob/user)
	user.visible_message("<span class='danger'>[user] is putting the live paddles on [user.p_their()] chest! It looks like [user.p_theyre()] trying to commit suicide.</span>")
	defib.deductcharge(revivecost)
	playsound(get_turf(src), 'sound/machines/defib_zap.ogg', 50, 1, -1)
	return OXYLOSS

/obj/item/twohanded/shockpaddles/dropped(mob/user as mob)
	if(user)
		var/obj/item/twohanded/offhand/O = user.get_inactive_hand()
		if(istype(O))
			O.unwield()
		to_chat(user, "<span class='notice'>The paddles snap back into the main unit.</span>")
		defib.paddles_on_defib = TRUE
		loc = defib
		defib.update_icon()
		update_icon()
	return unwield(user)

/obj/item/twohanded/shockpaddles/on_mob_move(dir, mob/user)
	if(defib)
		var/turf/t = get_turf(defib)
		if(!t.Adjacent(user))
			defib.remove_paddles(user)

/obj/item/twohanded/shockpaddles/proc/check_defib_exists(mainunit, var/mob/living/carbon/human/M, var/obj/O)
	if(!mainunit || !istype(mainunit, /obj/item/defibrillator))	//To avoid weird issues from admin spawns
		M.unEquip(O)
		qdel(O)
		return FALSE
	else
		return TRUE

/obj/item/twohanded/shockpaddles/attack(mob/M, mob/user)
	var/tobehealed
	var/threshold = -HEALTH_THRESHOLD_DEAD
	var/mob/living/carbon/human/H = M

	if(busy)
		return
	if(!defib.powered)
		user.visible_message("<span class='notice'>[defib] beeps: Unit is unpowered.</span>")
		playsound(get_turf(src), 'sound/machines/defib_failed.ogg', 50, 0)
		return
	if(!wielded)
		to_chat(user, "<span class='boldnotice'>You need to wield the paddles in both hands before you can use them on someone!</span>")
		return
	if(cooldown)
		to_chat(user, "<span class='notice'>[defib] is recharging.</span>")
		return
	if(!ishuman(M))
		to_chat(user, "<span class='notice'>The instructions on [defib] don't mention how to revive that...</span>")
		return
	else
		if(user.a_intent == INTENT_HARM && !defib.safety)
			busy = TRUE
			H.visible_message("<span class='danger'>[user] has touched [H.name] with [src]!</span>", \
					"<span class='userdanger'>[user] has touched [H.name] with [src]!</span>")
			H.adjustStaminaLoss(50)
			H.Weaken(2)
			playsound(get_turf(src), 'sound/machines/defib_zap.ogg', 50, 1, -1)
			H.emote("gasp")
			if(!H.undergoing_cardiac_arrest() && (prob(10) || defib.combat)) // Your heart explodes.
				H.set_heartattack(TRUE)
			H.shock_internal_organs(100)
			add_attack_logs(user, M, "Stunned with [src]")
			defib.deductcharge(revivecost)
			cooldown = TRUE
			busy = FALSE
			update_icon()
			defib.cooldowncheck(user)
			return
		user.visible_message("<span class='warning'>[user] begins to place [src] on [M.name]'s chest.</span>", "<span class='warning'>You begin to place [src] on [M.name]'s chest.</span>")
		busy = TRUE
		update_icon()
		if(do_after(user, 30 * toolspeed, target = M)) //beginning to place the paddles on patient's chest to allow some time for people to move away to stop the process
			user.visible_message("<span class='notice'>[user] places [src] on [M.name]'s chest.</span>", "<span class='warning'>You place [src] on [M.name]'s chest.</span>")
			playsound(get_turf(src), 'sound/machines/defib_charge.ogg', 50, 0)
			var/mob/dead/observer/ghost = H.get_ghost(TRUE)
			if(ghost && !ghost.client)
				// In case the ghost's not getting deleted for some reason
				H.key = ghost.key
				log_runtime(EXCEPTION("Ghost of name [ghost.name] is bound to [H.real_name], but lacks a client. Deleting ghost."), src)

				QDEL_NULL(ghost)
			var/tplus = world.time - H.timeofdeath
			var/tlimit = DEFIB_TIME_LIMIT
			var/tloss = DEFIB_TIME_LOSS
			var/total_burn	= 0
			var/total_brute	= 0
			if(do_after(user, 20 * toolspeed, target = M)) //placed on chest and short delay to shock for dramatic effect, revive time is 5sec total
				for(var/obj/item/carried_item in H.contents)
					if(istype(carried_item, /obj/item/clothing/suit/space))
						if(!defib.combat)
							user.visible_message("<span class='notice'>[defib] buzzes: Patient's chest is obscured. Operation aborted.</span>")
							playsound(get_turf(src), 'sound/machines/defib_failed.ogg', 50, 0)
							busy = FALSE
							update_icon()
							return
				if(H.undergoing_cardiac_arrest())
					if(!H.get_int_organ(/obj/item/organ/internal/heart) && !H.get_int_organ(/obj/item/organ/internal/brain/slime)) //prevents defibing someone still alive suffering from a heart attack attack if they lack a heart
						user.visible_message("<span class='boldnotice'>[defib] buzzes: Resuscitation failed - Failed to pick up any heart electrical activity.</span>")
						playsound(get_turf(src), 'sound/machines/defib_failed.ogg', 50, 0)
						busy = FALSE
						update_icon()
						return
					else
						var/obj/item/organ/internal/heart/heart = H.get_int_organ(/obj/item/organ/internal/heart)
						if(heart.status & ORGAN_DEAD)
							user.visible_message("<span class='boldnotice'>[defib] buzzes: Resuscitation failed - Heart necrosis detected.</span>")
							playsound(get_turf(src), 'sound/machines/defib_failed.ogg', 50, 0)
							busy = FALSE
							update_icon()
							return
						H.set_heartattack(FALSE)
						H.shock_internal_organs(100)
						user.visible_message("<span class='boldnotice'>[defib] pings: Cardiac arrhythmia corrected.</span>")
						M.visible_message("<span class='warning'>[M]'s body convulses a bit.")
						playsound(get_turf(src), 'sound/machines/defib_zap.ogg', 50, 1, -1)
						playsound(get_turf(src), "bodyfall", 50, 1)
						playsound(get_turf(src), 'sound/machines/defib_success.ogg', 50, 0)
						defib.deductcharge(revivecost)
						busy = FALSE
						cooldown = TRUE
						update_icon()
						defib.cooldowncheck(user)
						return
				if(H.stat == DEAD)
					var/health = H.health
					M.visible_message("<span class='warning'>[M]'s body convulses a bit.")
					playsound(get_turf(src), "bodyfall", 50, 1)
					playsound(get_turf(src), 'sound/machines/defib_zap.ogg', 50, 1, -1)
					for(var/obj/item/organ/external/O in H.bodyparts)
						total_brute	+= O.brute_dam
						total_burn	+= O.burn_dam
					if(total_burn <= 180 && total_brute <= 180 && !H.suiciding && !ghost && tplus < tlimit && !(NOCLONE in H.mutations) && (H.mind && H.mind.is_revivable()) && (H.get_int_organ(/obj/item/organ/internal/heart) || H.get_int_organ(/obj/item/organ/internal/brain/slime)))
						tobehealed = min(health + threshold, 0) // It's HILARIOUS without this min statement, let me tell you
						tobehealed -= 5 //They get 5 of each type of damage healed so excessive combined damage will not immediately kill them after they get revived
						H.adjustOxyLoss(tobehealed)
						H.adjustToxLoss(tobehealed)
						H.adjustFireLoss(tobehealed)
						H.adjustBruteLoss(tobehealed)
						user.visible_message("<span class='boldnotice'>[defib] pings: Resuscitation successful.</span>")
						playsound(get_turf(src), 'sound/machines/defib_success.ogg', 50, 0)
						H.update_revive()
						H.KnockOut()
						H.Paralyse(5)
						H.emote("gasp")
						if(tplus > tloss)
							H.setBrainLoss( max(0, min(99, ((tlimit - tplus) / tlimit * 100))))

						if(ishuman(H.pulledby)) // for some reason, pulledby isnt a list despite it being possible to be pulled by multiple people
							excess_shock(user, H, H.pulledby)
						for(var/obj/item/grab/G in H.grabbed_by)
							if(ishuman(G.assailant))
								excess_shock(user, H, G.assailant)

						H.shock_internal_organs(100)
						H.med_hud_set_health()
						H.med_hud_set_status()
						defib.deductcharge(revivecost)
						add_attack_logs(user, M, "Revived with [src]")
					else
						if(tplus > tlimit|| !H.get_int_organ(/obj/item/organ/internal/heart))
							user.visible_message("<span class='boldnotice'>[defib] buzzes: Resuscitation failed - Heart tissue damage beyond point of no return for defibrillation.</span>")
						else if(total_burn >= 180 || total_brute >= 180)
							user.visible_message("<span class='boldnotice'>[defib] buzzes: Resuscitation failed - Severe tissue damage detected.</span>")
						else if(ghost)
							if(!ghost.can_reenter_corpse) // DNR or AntagHUD
								user.visible_message("<span class='notice'>[defib] buzzes: Resucitation failed: No electrical brain activity detected.</span>")
							else
								user.visible_message("<span class='notice'>[defib] buzzes: Resuscitation failed: Patient's brain is unresponsive. Further attempts may succeed.</span>")
								to_chat(ghost, "<span class='ghostalert'>Your heart is being defibrillated. Return to your body if you want to be revived!</span> (Verbs -> Ghost -> Re-enter corpse)")
								window_flash(ghost.client)
								ghost << sound('sound/effects/genetics.ogg')
						else
							user.visible_message("<span class='notice'>[defib] buzzes: Resuscitation failed.</span>")
						playsound(get_turf(src), 'sound/machines/defib_failed.ogg', 50, 0)
						defib.deductcharge(revivecost)
					update_icon()
					cooldown = TRUE
					defib.cooldowncheck(user)
				else
					user.visible_message("<span class='notice'>[defib] buzzes: Patient is not in a valid state. Operation aborted.</span>")
					playsound(get_turf(src), 'sound/machines/defib_failed.ogg', 50, 0)
		busy = FALSE
		update_icon()
/*
 * user = the person using the defib
 * origin = person being revived
 * affecting = person being shocked with excess energy from the defib
*/
/obj/item/twohanded/shockpaddles/proc/excess_shock(mob/user, mob/living/carbon/human/origin, mob/living/carbon/human/affecting)
	if(user == affecting)
		return

	if(electrocute_mob(affecting, defib.cell, origin)) // shock anyone touching them >:)
		var/obj/item/organ/internal/heart/HE = affecting.get_organ_slot("heart")
		if(HE.parent_organ == "chest" && affecting.has_both_hands()) // making sure the shock will go through their heart (drask hearts are in their head), and that they have both arms so the shock can cross their heart inside their chest
			affecting.visible_message("<span class='danger'>[affecting]'s entire body shakes as a shock travels up their arm!</span>", \
							"<span class='userdanger'>You feel a powerful shock travel up your [affecting.hand ? affecting.get_organ("l_arm") : affecting.get_organ("r_arm")] and back down your [affecting.hand ? affecting.get_organ("r_arm") : affecting.get_organ("l_arm")]!</span>")
			affecting.set_heartattack(TRUE)

/obj/item/borg_defib
	name = "defibrillator paddles"
	desc = "A pair of mounted paddles with flat metal surfaces that are used to deliver powerful electric shocks."
	icon_state = "defibpaddles0"
	item_state = "defibpaddles0"
	force = 0
	w_class = WEIGHT_CLASS_BULKY
	var/revivecost = 1000
	var/cooldown = FALSE
	var/busy = FALSE
	var/safety = TRUE
	flags = NODROP
	toolspeed = 1

/obj/item/borg_defib/attack(mob/M, mob/user)
	var/tobehealed
	var/threshold = -HEALTH_THRESHOLD_DEAD
	var/mob/living/carbon/human/H = M

	if(busy)
		return
	if(cooldown)
		to_chat(user, "<span class='notice'>[src] is recharging.</span>")
	if(!ishuman(M))
		to_chat(user, "<span class='notice'>This unit is only designed to work on humanoid lifeforms.</span>")
		return
	else
		if(user.a_intent == INTENT_HARM && !safety)
			busy = TRUE
			H.visible_message("<span class='danger'>[user] has touched [H.name] with [src]!</span>", \
					"<span class='userdanger'>[user] has touched [H.name] with [src]!</span>")
			H.adjustStaminaLoss(50)
			H.Weaken(2)
			if(!H.undergoing_cardiac_arrest() && prob(10)) // Your heart explodes.
				H.set_heartattack(TRUE)
			H.shock_internal_organs(100)
			playsound(get_turf(src), 'sound/machines/defib_zap.ogg', 50, 1, -1)
			H.emote("gasp")
			add_attack_logs(user, M, "Stunned with [src]")
			if(isrobot(user))
				var/mob/living/silicon/robot/R = user
				R.cell.use(revivecost)
			cooldown = TRUE
			busy = FALSE
			update_icon()
			spawn(50)
				cooldown = FALSE
				update_icon()
			return
		user.visible_message("<span class='warning'>[user] begins to place [src] on [M.name]'s chest.</span>", "<span class='warning'>You begin to place [src] on [M.name]'s chest.</span>")
		busy = TRUE
		update_icon()
		if(do_after(user, 30 * toolspeed, target = M)) //beginning to place the paddles on patient's chest to allow some time for people to move away to stop the process
			user.visible_message("<span class='notice'>[user] places [src] on [M.name]'s chest.</span>", "<span class='warning'>You place [src] on [M.name]'s chest.</span>")
			playsound(get_turf(src), 'sound/machines/defib_charge.ogg', 50, 0)
			var/mob/dead/observer/ghost = H.get_ghost()
			if(ghost && !ghost.client)
				// In case the ghost's not getting deleted for some reason
				H.key = ghost.key
				log_runtime(EXCEPTION("Ghost of name [ghost.name] is bound to [H.real_name], but lacks a client. Deleting ghost."), H)

				QDEL_NULL(ghost)
			var/tplus = world.time - H.timeofdeath
			var/tlimit = 3000 //past this much time the patient is unrecoverable (in deciseconds)
			var/tloss = 600 //brain damage starts setting in on the patient after some time left rotting
			var/total_burn	= 0
			var/total_brute	= 0
			if(do_after(user, 20 * toolspeed, target = M)) //placed on chest and short delay to shock for dramatic effect, revive time is 5sec total
				if(H.stat == DEAD)
					var/health = H.health
					M.visible_message("<span class='warning'>[M]'s body convulses a bit.")
					playsound(get_turf(src), "bodyfall", 50, 1)
					playsound(get_turf(src), 'sound/machines/defib_zap.ogg', 50, 1, -1)
					for(var/obj/item/organ/external/O in H.bodyparts)
						total_brute	+= O.brute_dam
						total_burn	+= O.burn_dam
					if(total_burn <= 180 && total_brute <= 180 && !H.suiciding && !ghost && tplus < tlimit && !(NOCLONE in H.mutations) && (H.mind && H.mind.is_revivable()))
						tobehealed = min(health + threshold, 0) // It's HILARIOUS without this min statement, let me tell you
						tobehealed -= 5 //They get 5 of each type of damage healed so excessive combined damage will not immediately kill them after they get revived
						H.adjustOxyLoss(tobehealed)
						H.adjustToxLoss(tobehealed)
						H.adjustFireLoss(tobehealed)
						H.adjustBruteLoss(tobehealed)
						user.visible_message("<span class='notice'>[user] pings: Resuscitation successful.</span>")
						playsound(get_turf(src), 'sound/machines/defib_success.ogg', 50, 0)
						H.update_revive(FALSE)
						H.KnockOut(FALSE)
						H.Paralyse(5)
						H.emote("gasp")
						if(tplus > tloss)
							H.setBrainLoss( max(0, min(99, ((tlimit - tplus) / tlimit * 100))))
						H.shock_internal_organs(100)
						if(isrobot(user))
							var/mob/living/silicon/robot/R = user
							R.cell.use(revivecost)
						add_attack_logs(user, M, "Revived with [src]")
					else
						if(tplus > tlimit)
							user.visible_message("<span class='warning'>[user] buzzes: Resuscitation failed - Heart tissue damage beyond point of no return for defibrillation.</span>")
						else if(total_burn >= 180 || total_brute >= 180)
							user.visible_message("<span class='warning'>[user] buzzes: Resuscitation failed - Severe tissue damage detected.</span>")
						else if(ghost)
							user.visible_message("<span class='notice'>[user] buzzes: Resuscitation failed: Patient's brain is unresponsive. Further attempts may succeed.</span>")
							to_chat(ghost, "<span class='ghostalert'>Your heart is being defibrillated. Return to your body if you want to be revived!</span> (Verbs -> Ghost -> Re-enter corpse)")
							window_flash(ghost.client)
							ghost << sound('sound/effects/genetics.ogg')
						else
							user.visible_message("<span class='warning'>[user] buzzes: Resuscitation failed.</span>")
						playsound(get_turf(src), 'sound/machines/defib_failed.ogg', 50, 0)
						if(isrobot(user))
							var/mob/living/silicon/robot/R = user
							R.cell.use(revivecost)
					update_icon()
					cooldown = TRUE
					spawn(50)
						cooldown = FALSE
						update_icon()
				else
					user.visible_message("<span class='notice'>[user] buzzes: Patient is not in a valid state. Operation aborted.</span>")
					playsound(get_turf(src), 'sound/machines/defib_failed.ogg', 50, 0)
		busy = FALSE
		update_icon()
