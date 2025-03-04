//This is the gamemode file for the ported goon gamemode vampires.
//They get a traitor objective and a blood sucking objective
/datum/game_mode
	var/list/datum/mind/vampires = list()
	var/list/datum/mind/vampire_enthralled = list() //those controlled by a vampire
	var/list/vampire_thralls = list() //vammpires controlling somebody

/datum/game_mode/vampire
	name = "vampire"
	config_tag = "vampire"
	restricted_jobs = list("AI", "Cyborg")
	protected_jobs = list("Security Officer", "Warden", "Detective", "Head of Security", "Captain", "Blueshield", "Nanotrasen Representative", "Security Pod Pilot", "Magistrate", "Chaplain", "Brig Physician", "Internal Affairs Agent", "Nanotrasen Navy Officer", "Special Operations Officer", "Syndicate Officer")
	protected_species = list("Machine")
	required_players = 15
	required_enemies = 1
	recommended_enemies = 4

	var/const/prob_int_murder_target = 50 // intercept names the assassination target half the time
	var/const/prob_right_murder_target_l = 25 // lower bound on probability of naming right assassination target
	var/const/prob_right_murder_target_h = 50 // upper bound on probability of naimg the right assassination target

	var/const/prob_int_item = 50 // intercept names the theft target half the time
	var/const/prob_right_item_l = 25 // lower bound on probability of naming right theft target
	var/const/prob_right_item_h = 50 // upper bound on probability of naming the right theft target

	var/const/prob_int_sab_target = 50 // intercept names the sabotage target half the time
	var/const/prob_right_sab_target_l = 25 // lower bound on probability of naming right sabotage target
	var/const/prob_right_sab_target_h = 50 // upper bound on probability of naming right sabotage target

	var/const/prob_right_killer_l = 25 //lower bound on probability of naming the right operative
	var/const/prob_right_killer_h = 50 //upper bound on probability of naming the right operative
	var/const/prob_right_objective_l = 25 //lower bound on probability of determining the objective correctly
	var/const/prob_right_objective_h = 50 //upper bound on probability of determining the objective correctly

	var/vampire_amount = 4

/datum/game_mode/vampire/announce()
	to_chat(world, "<B>Текущий игровой режим — Вампиры!</B>")
	to_chat(world, "<B>На станции есть вампиры из Космотрансильвании. Берегите свои шеи и кровь!</B>")

/datum/game_mode/vampire/pre_setup()

	if(config.protect_roles_from_antagonist)
		restricted_jobs += protected_jobs

	var/list/datum/mind/possible_vampires = get_players_for_role(ROLE_VAMPIRE)

	var/vampire_scale = 10
	if(config.traitor_scaling)
		vampire_scale = config.traitor_scaling
	vampire_amount = 1 + round(num_players() / vampire_scale)
	log_game("Number of vampires chosen: [vampire_amount]")

	if(possible_vampires.len>0)
		for(var/i = 0, i < vampire_amount, i++)
			if(!possible_vampires.len) break
			var/datum/mind/vampire = pick(possible_vampires)
			possible_vampires -= vampire
			vampires += vampire
			vampire.restricted_roles = restricted_jobs
			modePlayer += vampires
			var/datum/mindslaves/slaved = new()
			slaved.masters += vampire
			vampire.som = slaved //we MIGT want to mindslave someone
			vampire.special_role = SPECIAL_ROLE_VAMPIRE
		..()
		return 1
	else
		return 0

/datum/game_mode/vampire/post_setup()
	for(var/datum/mind/vampire in vampires)
		grant_vampire_powers(vampire.current)
		forge_vampire_objectives(vampire)
		greet_vampire(vampire)
		update_vampire_icons_added(vampire)
	..()

/datum/game_mode/proc/auto_declare_completion_vampire()
	if(vampires.len)
		var/text = "<FONT size = 2><B>Вампирами были:</B></FONT>"
		for(var/datum/mind/vampire in vampires)
			var/traitorwin = 1

			text += "<br>[vampire.key] [genderize_ru(vampire.current.gender, "был", "была", "было", "были")] [vampire.name] ("
			if(vampire.current)
				if(vampire.current.stat == DEAD)
					text += "[genderize_ru(vampire.current.gender, "умер", "умерла", "умерло", "умерли")]"
				else
					text += "[genderize_ru(vampire.current.gender, "выжил", "выжила", "выжило", "выжили")]"
				if(vampire.current.real_name != vampire.name)
					text += " как [vampire.current.real_name]"
			else
				text += "тело было уничтожено"
			text += ")"

			if(vampire.objectives.len)//If the traitor had no objectives, don't need to process this.
				var/count = 1
				for(var/datum/objective/objective in vampire.objectives)
					text += "<br><B>Задание №[count]</B>: [objective.explanation_text] "
					if(objective.check_completion())
						text += "<font color='green'><B>Успех!</B></font>"
						SSblackbox.record_feedback("nested tally", "traitor_objective", 1, list("[objective.type]", "SUCCESS"))
					else
						text += "<font color='red'>Провал.</font>"
						SSblackbox.record_feedback("nested tally", "traitor_objective", 1, list("[objective.type]", "FAIL"))
						traitorwin = 0
					count++

			var/special_role_text
			if(vampire.special_role)
				special_role_text = lowertext(vampire.special_role)
			else
				special_role_text = "antagonist"

			if(traitorwin)
				text += "<br><font color='green'><B>The [special_role_text] was successful!</B></font>"
				SSblackbox.record_feedback("tally", "traitor_success", 1, "SUCCESS")
			else
				text += "<br><font color='red'><B>The [special_role_text] has failed!</B></font>"
				SSblackbox.record_feedback("tally", "traitor_success", 1, "FAIL")
		to_chat(world, text)
	return 1

/datum/game_mode/proc/auto_declare_completion_enthralled()
	if(vampire_enthralled.len)
		var/text = "<FONT size = 2><B>Рабами вампиров были:</B></FONT>"
		for(var/datum/mind/Mind in vampire_enthralled)
			text += "<br>[Mind.key] [genderize_ru(Mind.current.gender, "был", "была", "было", "были")] [Mind.name] ("
			if(Mind.current)
				if(Mind.current.stat == DEAD)
					text += "[genderize_ru(Mind.current.gender, "умер", "умерла", "умерло", "умерли")]"
				else
					text += "[genderize_ru(Mind.current.gender, "выжил", "выжила", "выжило", "выжили")]"
				if(Mind.current.real_name != Mind.name)
					text += " как [Mind.current.real_name]"
			else
				text += "тело было уничтожено"
			text += ")"
		to_chat(world, text)
	return 1

/datum/game_mode/proc/forge_vampire_objectives(var/datum/mind/vampire)
	//Objectives are traitor objectives plus blood objectives

	var/datum/objective/blood/blood_objective = new
	blood_objective.owner = vampire
	blood_objective.gen_amount_goal(150, 400)
	vampire.objectives += blood_objective

	var/datum/objective/maroon/maroon_objective = new
	maroon_objective.owner = vampire
	maroon_objective.find_target()
	vampire.objectives += maroon_objective

	var/datum/objective/steal/steal_objective = new
	steal_objective.owner = vampire
	steal_objective.find_target()
	vampire.objectives += steal_objective


	switch(rand(1,100))
		if(1 to 80)
			if(!(locate(/datum/objective/escape) in vampire.objectives))
				var/datum/objective/escape/escape_objective = new
				escape_objective.owner = vampire
				vampire.objectives += escape_objective
		else
			if(!(locate(/datum/objective/survive) in vampire.objectives))
				var/datum/objective/survive/survive_objective = new
				survive_objective.owner = vampire
				vampire.objectives += survive_objective
	return

/datum/game_mode/proc/grant_vampire_powers(mob/living/carbon/vampire_mob)
	if(!istype(vampire_mob))
		return
	vampire_mob.make_vampire()

/datum/game_mode/proc/greet_vampire(var/datum/mind/vampire, var/you_are=1)
	var/dat
	if(you_are)
		SEND_SOUND(vampire.current, 'sound/ambience/antag/vampalert.ogg')
		dat = "<span class='danger'>Вы — вампир!</span><br>"
	dat += {"Чтобы укусить кого-то, нацельтесь в голову, выберите намерение вреда (4) и ударьте пустой рукой. Пейте кровь, чтобы получать новые силы.
Вы уязвимы перед святостью и звёздным светом. Не выходите в космос, избегайте священника, церкви и, особенно, святой воды."}
	to_chat(vampire.current, dat)
	to_chat(vampire.current, "<B>Вы должны выполнить следующие задания:</B>")

	if(vampire.current.mind)
		if(vampire.current.mind.assigned_role == "Clown")
			to_chat(vampire.current, "Ваша жажда крови позволяет вам преодолевать собственную неуклюжесть. Вы можете использовать оружие, не опасаясь навредить себе.")
			vampire.current.mutations.Remove(CLUMSY)
			var/datum/action/innate/toggle_clumsy/A = new
			A.Grant(vampire.current)
	var/obj_count = 1
	for(var/datum/objective/objective in vampire.objectives)
		to_chat(vampire.current, "<B>Задание №[obj_count]</B>: [objective.explanation_text]")
		obj_count++
	return

/datum/vampire
	var/bloodtotal = 0 // CHANGE TO ZERO WHEN PLAYTESTING HAPPENS
	var/bloodusable = 0 // CHANGE TO ZERO WHEN PLAYTESTING HAPPENS
	var/mob/living/owner = null
	var/gender = FEMALE
	var/iscloaking = 0 // handles the vampire cloak toggle
	var/list/powers = list() // list of available powers and passives
	var/mob/living/carbon/human/draining // who the vampire is draining of blood
	var/nullified = 0 //Nullrod makes them useless for a short while.
	var/list/upgrade_tiers = list(
		/obj/effect/proc_holder/spell/vampire/self/rejuvenate = 0,
		/obj/effect/proc_holder/spell/vampire/targetted/hypnotise = 0,
		/obj/effect/proc_holder/spell/vampire/mob_aoe/glare = 0,
		/datum/vampire_passive/vision = 100,
		/obj/effect/proc_holder/spell/vampire/self/shapeshift = 100,
		/obj/effect/proc_holder/spell/vampire/self/cloak = 150,
		/obj/effect/proc_holder/spell/vampire/targetted/disease = 150,
		/obj/effect/proc_holder/spell/vampire/bats = 200,
		/obj/effect/proc_holder/spell/vampire/self/screech = 200,
		/datum/vampire_passive/regen = 200,
		/obj/effect/proc_holder/spell/vampire/shadowstep = 250,
		/obj/effect/proc_holder/spell/vampire/self/jaunt = 300,
		/obj/effect/proc_holder/spell/vampire/targetted/enthrall = 300,
		/datum/vampire_passive/full = 500)

/datum/vampire/New(gend = FEMALE)
	gender = gend

/datum/vampire/proc/force_add_ability(path)
	var/spell = new path(owner)
	if(istype(spell, /obj/effect/proc_holder/spell))
		owner.mind.AddSpell(spell)
	powers += spell
	owner.update_sight() // Life updates conditionally, so we need to update sight here in case the vamp gets new vision based on his powers. Maybe one day refactor to be more OOP and on the vampire's ability datum.

/datum/vampire/proc/get_ability(path)
	for(var/P in powers)
		var/datum/power = P
		if(power.type == path)
			return power
	return null

/datum/vampire/proc/add_ability(path)
	if(!get_ability(path))
		force_add_ability(path)

/datum/vampire/proc/remove_ability(ability)
	if(ability && (ability in powers))
		powers -= ability
		owner.mind.spell_list.Remove(ability)
		qdel(ability)
		owner.update_sight() // Life updates conditionally, so we need to update sight here in case the vamp loses his vision based powers. Maybe one day refactor to be more OOP and on the vampire's ability datum.

/datum/vampire/proc/update_owner(var/mob/living/carbon/human/current) //Called when a vampire gets cloned. This updates vampire.owner to the new body.
	if(current.mind && current.mind.vampire && current.mind.vampire.owner && (current.mind.vampire.owner != current))
		current.mind.vampire.owner = current

/mob/proc/make_vampire()
	if(!mind)
		return
	var/datum/vampire/vamp
	if(!mind.vampire)
		vamp = new /datum/vampire(gender)
		vamp.owner = src
		mind.vampire = vamp
	else
		vamp = mind.vampire
		vamp.powers.Cut()

	vamp.check_vampire_upgrade(0)

/datum/vampire/proc/remove_vampire_powers()
	for(var/P in powers)
		remove_ability(P)
	if(owner.hud_used)
		var/datum/hud/hud = owner.hud_used
		if(hud.vampire_blood_display)
			hud.remove_vampire_hud()
	owner.alpha = 255

/datum/vampire/proc/handle_bloodsucking(mob/living/carbon/human/H)
	draining = H
	var/blood = 0
	var/old_bloodtotal = 0 //used to see if we increased our blood total
	var/old_bloodusable = 0 //used to see if we increased our blood usable
	var/blood_volume_warning = 9999 //Blood volume threshold for warnings
	if(owner.is_muzzled())
		to_chat(owner, "<span class='warning'>[owner.wear_mask] мешает вам укусить [H]!</span>")
		draining = null
		return
	add_attack_logs(owner, H, "vampirebit & is draining their blood.", ATKLOG_ALMOSTALL)
	owner.visible_message("<span class='danger'>[owner] грубо хватает шею [H] и вонзает в неё клыки!</span>", "<span class='danger'>Вы вонзаете клыки в шею [H] и начинаете высасывать [genderize_ru(H.gender, "его", "её", "его", "их")] кровь.</span>", "<span class='notice'>Вы слышите тихий звук прокола и влажные хлюпающие звуки.</span>")
	if(!iscarbon(owner))
		H.LAssailant = null
	else
		H.LAssailant = owner
	while(do_mob(owner, H, 50))
		if(!(owner.mind in SSticker.mode.vampires))
			to_chat(owner, "<span class='userdanger'>Ваши клыки исчезают!</span>")
			return
		old_bloodtotal = bloodtotal
		old_bloodusable = bloodusable
		if(H.stat < DEAD)
			if(H.ckey || H.player_ghosted) //Requires ckey regardless if monkey or humanoid, or the body has been ghosted before it died
				blood = min(20, H.blood_volume)	// if they have less than 20 blood, give them the remnant else they get 20 blood
				bloodtotal += blood / 2	//divide by 2 to counted the double suction since removing cloneloss -Melandor0
				bloodusable += blood / 2
		else
			if(H.ckey || H.player_ghosted)
				blood = min(5, H.blood_volume)	// The dead only give 5 blood
				bloodtotal += blood
		if(old_bloodtotal != bloodtotal)
			if(H.ckey || H.player_ghosted) // Requires ckey regardless if monkey or human, and has not ghosted, otherwise no power
				to_chat(owner, "<span class='notice'><b>Вы накопили [bloodtotal] единиц[declension_ru(bloodtotal, "у", "ы", "")] крови[bloodusable != old_bloodusable ? ", и теперь вам доступно [bloodusable] единиц[declension_ru(bloodusable, "а", "ы", "")] крови" : ""].</b></span>")
		check_vampire_upgrade()
		H.blood_volume = max(H.blood_volume - 25, 0)
		//Blood level warnings (Code 'borrowed' from Fulp)
		if(H.blood_volume)
			if(H.blood_volume <= BLOOD_VOLUME_BAD && blood_volume_warning > BLOOD_VOLUME_BAD)
				to_chat(owner, "<span class='danger'>У вашей жертвы остаётся опасно мало крови!</span>")
			else if(H.blood_volume <= BLOOD_VOLUME_OKAY && blood_volume_warning > BLOOD_VOLUME_OKAY)
				to_chat(owner, "<span class='warning'>У вашей жертвы остаётся тревожно мало крови.</span>")
			blood_volume_warning = H.blood_volume //Set to blood volume, so that you only get the message once
		else
			to_chat(owner, "<span class='warning'>Вы выпили свою жертву досуха!</span>")
			break

		if(ishuman(owner))
			var/mob/living/carbon/human/V = owner
			if(!H.ckey && !H.player_ghosted)//Only runs if there is no ckey and the body has not being ghosted while alive
				to_chat(V, "<span class='notice'><b>Питьё крови у [H] насыщает вас, но доступной крови от этого вы не получаете.</b></span>")
				V.set_nutrition(min(NUTRITION_LEVEL_WELL_FED, V.nutrition + 5))
			else
				V.set_nutrition(min(NUTRITION_LEVEL_WELL_FED, V.nutrition + (blood / 2)))


	draining = null
	to_chat(owner, "<span class='notice'>Вы прекращаете пить кровь [H.name].</span>")

/datum/vampire/proc/check_vampire_upgrade(announce = 1)
	var/list/old_powers = powers.Copy()

	for(var/ptype in upgrade_tiers)
		var/level = upgrade_tiers[ptype]
		if(bloodtotal >= level)
			add_ability(ptype)

	if(announce)
		announce_new_power(old_powers)

/datum/vampire/proc/announce_new_power(list/old_powers)
	for(var/p in powers)
		if(!(p in old_powers))
			if(istype(p, /obj/effect/proc_holder/spell/vampire))
				var/obj/effect/proc_holder/spell/vampire/power = p
				to_chat(owner, "<span class='notice'>[power.gain_desc]</span>")
			else if(istype(p, /datum/vampire_passive))
				var/datum/vampire_passive/power = p
				to_chat(owner, "<span class='notice'>[power.gain_desc]</span>")

/datum/game_mode/proc/remove_vampire(datum/mind/vampire_mind)
	if(vampire_mind in vampires)
		SSticker.mode.vampires -= vampire_mind
		vampire_mind.special_role = null
		vampire_mind.current.create_attack_log("<span class='danger'>De-vampired</span>")
		vampire_mind.current.create_log(CONVERSION_LOG, "De-vampired")
		if(vampire_mind.vampire)
			vampire_mind.vampire.remove_vampire_powers()
			QDEL_NULL(vampire_mind.vampire)
		if(issilicon(vampire_mind.current))
			to_chat(vampire_mind.current, "<span class='userdanger'>Вы превратились в робота! Вы чувствуете как вампирские силы исчезают…</span>")
		else
			to_chat(vampire_mind.current, "<span class='userdanger'>Ваш разум очищен! Вы больше не вампир.</span>")
		SSticker.mode.update_vampire_icons_removed(vampire_mind)

//prepare for copypaste
/datum/game_mode/proc/update_vampire_icons_added(datum/mind/vampire_mind)
	var/datum/atom_hud/antag/vamp_hud = GLOB.huds[ANTAG_HUD_VAMPIRE]
	vamp_hud.join_hud(vampire_mind.current)
	set_antag_hud(vampire_mind.current, ((vampire_mind in vampires) ? "hudvampire" : "hudvampirethrall"))

/datum/game_mode/proc/update_vampire_icons_removed(datum/mind/vampire_mind)
	var/datum/atom_hud/antag/vampire_hud = GLOB.huds[ANTAG_HUD_VAMPIRE]
	vampire_hud.leave_hud(vampire_mind.current)
	set_antag_hud(vampire_mind.current, null)

/datum/game_mode/proc/remove_vampire_mind(datum/mind/vampire_mind, datum/mind/head)
	//var/list/removal
	if(!istype(head))
		head = vampire_mind //workaround for removing a thrall's control over the enthralled
	var/ref = "\ref[head]"
	if(ref in vampire_thralls)
		vampire_thralls[ref] -= vampire_mind
	vampire_enthralled -= vampire_mind
	vampire_mind.special_role = null
	var/datum/mindslaves/slaved = vampire_mind.som
	slaved.serv -= vampire_mind
	vampire_mind.som = null
	slaved.leave_serv_hud(vampire_mind)
	update_vampire_icons_removed(vampire_mind)
	vampire_mind.current.visible_message("<span class='userdanger'>Кажется, будто тяжёлый груз упал с плеч [vampire_mind.current]!</span>", "<span class='userdanger'>Тёмная пелена спала с вашего рассудка. Ваш разум прояснился. Вы больше не [usr.gender == MALE ? "раб" : "раба"] вампира и снова отвечаете за свои действия!</span>")
	if(vampire_mind.current.hud_used)
		vampire_mind.current.hud_used.remove_vampire_hud()


/datum/vampire/proc/check_sun()
	var/ax = owner.x
	var/ay = owner.y

	for(var/i = 1 to 20)
		ax += SSsun.dx
		ay += SSsun.dy

		var/turf/T = locate(round(ax, 0.5), round(ay, 0.5), owner.z)

		if(T.x == 1 || T.x == world.maxx || T.y == 1 || T.y == world.maxy)
			break

		if(T.density)
			return
	if(bloodusable >= 10)	//burn through your blood to tank the light for a little while
		to_chat(owner, "<span class='warning'>Свет звёзд жжётся и истощает ваши силы!</span>")
		bloodusable -= 10
		vamp_burn(10)
	else		//You're in trouble, get out of the sun NOW
		to_chat(owner, "<span class='userdanger'>Ваше тело обугливается, превращаясь в пепел! Укройтесь от звёздного света!</span>")
		owner.adjustCloneLoss(10)	//I'm melting!
		vamp_burn(85)

/datum/vampire/proc/handle_vampire()
	if(owner.hud_used)
		var/datum/hud/hud = owner.hud_used
		if(!hud.vampire_blood_display)
			hud.vampire_blood_display = new /obj/screen()
			hud.vampire_blood_display.name = "Доступная кровь"
			hud.vampire_blood_display.icon_state = "blood_display"
			hud.vampire_blood_display.screen_loc = "WEST:6,CENTER-1:15"
			hud.static_inventory += hud.vampire_blood_display
			hud.show_hud(hud.hud_version)
		hud.vampire_blood_display.maptext = "<div align='center' valign='middle' style='position:relative; top:0px; left:6px'><font color='#ce0202'>[bloodusable]</font></div>"
	handle_vampire_cloak()
	if(istype(owner.loc, /turf/space))
		check_sun()
	if(istype(owner.loc.loc, /area/chapel) && !get_ability(/datum/vampire_passive/full))
		vamp_burn(7)
	nullified = max(0, nullified - 1)

/datum/vampire/proc/handle_vampire_cloak()
	if(!ishuman(owner))
		owner.alpha = 255
		return
	var/turf/simulated/T = get_turf(owner)
	var/light_available = T.get_lumcount(0.5) * 10

	if(!istype(T))
		return 0

	if(!iscloaking)
		owner.alpha = 255
		return 0

	if(light_available <= 2)
		owner.alpha = round((255 * 0.15))
		return 1
	else
		owner.alpha = round((255 * 0.80))

/datum/vampire/proc/vamp_burn(burn_chance)
	if(prob(burn_chance) && owner.health >= 50)
		switch(owner.health)
			if(75 to 100)
				to_chat(owner, "<span class='warning'>Ваша кожа дымится…</span>")
			if(50 to 75)
				to_chat(owner, "<span class='warning'>Ваша кожа шипит!</span>")
		owner.adjustFireLoss(3)
	else if(owner.health < 50)
		if(!owner.on_fire)
			to_chat(owner, "<span class='danger'>Ваша кожа загорается!</span>")
			owner.emote("scream")
		else
			to_chat(owner, "<span class='danger'>Вы продолжаете гореть!</span>")
		owner.adjust_fire_stacks(5)
		owner.IgniteMob()
	return

/datum/hud/proc/remove_vampire_hud()
	if(!vampire_blood_display)
		return

	static_inventory -= vampire_blood_display
	QDEL_NULL(vampire_blood_display)
	show_hud(hud_version)
