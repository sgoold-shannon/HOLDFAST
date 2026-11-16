extends RefCounted
## Read-only display data; no controller or gameplay callbacks.
static func render(canvas: Object, font: Font, projection: RefCounted, view: Dictionary) -> void:
	var selection = "Select a soldier  |  Green 1 = move  |  Blue 2 = dash"
	if view["active_soldier"] >= 0:
		var soldier: Dictionary = view["soldiers"][view["active_soldier"]]
		selection = "%s / %s | HP %d/8 | AP %d | Ammo %d | Attack %s | (%d,%d)" % [soldier["name"], view["roles"][view["active_soldier"]], soldier["hp"], soldier["ap"], soldier["ammo"], "used" if soldier["attacked"] else "ready", soldier["cell"].x, soldier["cell"].y]
	elif view["selected_cell"] != view["NONE"]:
		selection = "Selected ground (%d, %d)" % [view["selected_cell"].x, view["selected_cell"].y]
	canvas.draw_string(font, Vector2(40, 711), selection, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("f7cd6c"))
	var preview = "Green 1: up to 4 squares / 1 AP. Blue 2: 5–8 squares / 2 AP."
	if view["path"].size() > 0:
		preview = "Destination (%d, %d): %d orthogonal steps / %d AP" % [view["hovered_cell"].x, view["hovered_cell"].y, view["path"].size() - 1, view["cost"]]
	if view["sight_mode"]:
		preview = "SIGHT PREVIEW: select a soldier, then hover a target cell."
		if view["active_soldier"] >= 0 and view["valid_target"]:

			preview = "%s (%d, %d) | Distance %d | %s" % ["Pinned" if view["pinned_target"] != view["NONE"] else "Target", view["target"].x, view["target"].y, view["info"]["distance"], "Sight clear" if view["info"]["clear"] else "WALL BLOCKS SHOT"]
			var detail = "Aim 75 | Range %+d | Cover %+d | " % [view["info"]["range_modifier"], view["info"]["cover_modifier"]]
			detail += "%d%% preview" % view["info"]["chance"] if view["info"]["can_fire"] else "Cannot fire"
			canvas.draw_string(font, Vector2(40, 790), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f7cd6c"))
			var explanation = "No cover edge at target."
			if view["info"]["edge"] != "none":
				explanation = "%s edge: %s" % [view["info"]["edge"].capitalize(), "protected (-25)" if view["info"]["protected"] else "flanked (0)"]
			if not view["info"]["blockers"].is_empty():
				explanation += " Wall touched: %s." % str(view["info"]["blockers"][0])
			elif view["info"]["distance"] > 12:
				explanation += " Beyond rifle range (12)."
			elif view["info"]["distance"] == 0:
				explanation += " Choose a different cell."
			canvas.draw_string(font, Vector2(40, 820), explanation, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d6ded9"))
	canvas.draw_string(font, Vector2(40, 730), preview, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d6ded9"))
	canvas.draw_string(font, Vector2(40, 758), view["status_text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d6ded9"))
	for index in range(view["soldiers"].size()):
		var soldier: Dictionary = view["soldiers"][index]
		var origin = Vector2(40+index*196,837)
		canvas.draw_rect(Rect2(origin,Vector2(190,38)),Color("22312a"))
		canvas.draw_rect(Rect2(origin,Vector2(4,38)),view["colors"][index])
		var health = "OUT" if soldier["extracted"] else "%d HP" % soldier["hp"]
		if soldier.get("condition") == "critical": health = "CRIT %d" % soldier["bleed"]
		elif soldier.get("condition") == "stable": health = "STABLE"
		elif soldier.get("condition") == "dead": health = "DEAD"
		if soldier.get("actor_id", "original") == "": health = "UNFILLED"
		canvas.draw_string(font,origin+Vector2(10,16),"%s · %s" % [soldier["name"],health],HORIZONTAL_ALIGNMENT_LEFT,180,14,view["colors"][index])
		canvas.draw_string(font,origin+Vector2(10,32),view["roles"][index]+" · %d AP" % soldier["ap"],HORIZONTAL_ALIGNMENT_LEFT,180,12,Color.WHITE)
	canvas.draw_rect(view["NEXT_PHASE_RECT"], Color("315b50"))
	canvas.draw_string(font, view["NEXT_PHASE_RECT"].position + Vector2(0, 26), "End round %d [N]" % view["phase"], HORIZONTAL_ALIGNMENT_CENTER, view["NEXT_PHASE_RECT"].size.x, 16, Color.WHITE)

	canvas.draw_rect(view["MODE_RECT"], Color("304965") if view["sight_mode"] else Color("315b50"))
	canvas.draw_string(font, view["MODE_RECT"].position + Vector2(0, 26), "Aim / sight [T]" if view["sight_mode"] else "Movement [T]", HORIZONTAL_ALIGNMENT_CENTER, view["MODE_RECT"].size.x, 16, Color.WHITE)
	canvas.draw_string(font, Vector2(40, 979), view["intent"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("7ed4ee"))

	var reason = view["fire_reason"]
	canvas.draw_rect(view["FIRE_RECT"], Color("713f36") if reason == "" else Color("343b38"))
	canvas.draw_string(font, view["FIRE_RECT"].position + Vector2(0, 26), "Fire [F] · 1 AP", HORIZONTAL_ALIGNMENT_CENTER, view["FIRE_RECT"].size.x, 16, Color.WHITE)
	canvas.draw_rect(view["RELOAD_RECT"], Color("315b50"))
	canvas.draw_string(font, view["RELOAD_RECT"].position + Vector2(0, 26), "Reload [R] · 1 AP", HORIZONTAL_ALIGNMENT_CENTER, view["RELOAD_RECT"].size.x, 16, Color.WHITE)
	canvas.draw_string(font, Vector2(40, 947), reason if reason != "" else "Ready: fire costs 1 AP + 1 round. Hit deals 4 damage.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f7cd6c"))
	canvas.draw_string(font, Vector2(40, 1005), view["enemy_message"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("aebbb6"))

	canvas.draw_rect(view["EXTRACT_RECT"], Color("315b50"))
	canvas.draw_string(font, view["EXTRACT_RECT"].position + Vector2(0, 26), "Extract [E] · 1 AP", HORIZONTAL_ALIGNMENT_CENTER, view["EXTRACT_RECT"].size.x, 16, Color.WHITE)
	canvas.draw_rect(view["SAVE_RECT"], Color("304965"))
	canvas.draw_string(font, view["SAVE_RECT"].position + Vector2(0, 26), "Save [K]", HORIZONTAL_ALIGNMENT_CENTER, view["SAVE_RECT"].size.x, 16, Color.WHITE)
	canvas.draw_rect(view["LOAD_RECT"], Color("304965"))
	canvas.draw_string(font, view["LOAD_RECT"].position + Vector2(0, 26), "Load [L]", HORIZONTAL_ALIGNMENT_CENTER, view["LOAD_RECT"].size.x, 16, Color.WHITE)
	canvas.draw_string(font, Vector2(635, 1046), "One save slot", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("aebbb6"))
	canvas.draw_string(font, Vector2(40, 1090), view["save_feedback"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("aebbb6"))
