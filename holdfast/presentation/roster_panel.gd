extends RefCounted
## Draws detached display data; gameplay and modal input remain in the controller.
static func render(canvas: Object, font: Font, projection: RefCounted, view: Dictionary) -> void:
	canvas.draw_rect(Rect2(0,0,1144,1224),Color("0e1412"))
	line(canvas,font,65,"HOLDFAST / C2 · PERSISTENT ROSTER",Color("8be6de"),22)
	line(canvas,font,115,"Deployment %d / 2 · %d mission records" % [view["campaign"]["deployment"],view["campaign"]["missions"].size()],Color("f7cd6c"),25)
	line(canvas,font,155,"Confirmed deaths remain in service records. Replacements have separate identities.",Color("aebbb6"),17)
	for index in range(view["campaign"]["members"].size()):
		var member: Dictionary = view["campaign"]["members"][index]
		var rect = Rect2(60,210+index*67,300,58)
		canvas.draw_rect(rect,Color("476b59") if index == view["roster_index"] else Color("263b32"))
		canvas.draw_string(font,rect.position+Vector2(14,24),member["name"]+(" · new" if member["replacement"] else ""),HORIZONTAL_ALIGNMENT_LEFT,270,20,Color.WHITE)
		canvas.draw_string(font,rect.position+Vector2(14,47),member["status"].replace("_"," ").to_upper(),HORIZONTAL_ALIGNMENT_LEFT,270,15,Color("f7cd6c"))
	var actor: Dictionary = view["campaign"]["members"][view["roster_index"]]
	canvas.draw_string(font,Vector2(400,238),"%s · %s · HP %d/8" % [actor["name"],["MSG","Medic","Engineer","Recon"][actor["role"]],actor["hp"]],HORIZONTAL_ALIGNMENT_LEFT,660,25,Color.WHITE)
	var lines = view["details"]
	var page_count = maxi(1,ceili(lines.size()/9.0))
	canvas.draw_multiline_string(font,Vector2(400,290),"\n".join(lines.slice(view["history_page"]*9,view["history_page"]*9+9)),HORIZONTAL_ALIGNMENT_LEFT,660,21,-1,Color("d6ded9"))
	canvas.draw_string(font,Vector2(400,765),"Record %d/%d · ← / → pages · ↑ / ↓ soldier" % [view["history_page"]+1,page_count],HORIZONTAL_ALIGNMENT_LEFT,660,17,Color("8be6de"))
	line(canvas,font,840,"Next deployment: available survivors keep their remaining HP.",Color.WHITE,19)
	line(canvas,font,875,"Casualty-care patients rest. Living people left behind remain unavailable.",Color("aebbb6"),18)
	line(canvas,font,910,"Ammunition, AP and deployed medic charges are replenished at staging.",Color("aebbb6"),18)
	line(canvas,font,955,"Deployment 2 is a roster test on the same map, with new civilian identities.",Color("8be6de"),18)
	canvas.draw_rect(view["CARE_RECT"],Color("304965") if view["care"] else Color("28332d"))
	canvas.draw_string(font,view["CARE_RECT"].position+Vector2(15,32),"Staging care [T] · treatment and rest; patients return at 1 HP" if view["care"] else "No patients awaiting staging care",HORIZONTAL_ALIGNMENT_LEFT,994,19,Color.WHITE)
	var action = "Deploy roster [Enter]"
	if view["campaign"]["deployment"] == 2: action = "Two-deployment fixture complete" if view["campaign"]["committed"] else "Finish this deployment first"
	elif not view["campaign"]["committed"]: action = "Retry required before continuation"
	elif not view["deploy"]: action = "MSG needs staging care [T]"
	for item in [[view["DEPLOY_RECT"],action],[view["BACK_RECT"],"Back to results [Esc]"]]:
		canvas.draw_rect(item[0],Color("304965"))
		canvas.draw_string(font,item[0].position+Vector2(15,35),item[1],HORIZONTAL_ALIGNMENT_LEFT,450,20,Color.WHITE)
	line(canvas,font,1180,view["result_feedback"],Color("aebbb6"),15)

static func line(canvas: Object, font: Font, y: float, text: String, color: Color = Color("d6ded9"), size: int = 19) -> void:
	canvas.draw_string(font,Vector2(60,y),text,HORIZONTAL_ALIGNMENT_LEFT,1024,size,color)
