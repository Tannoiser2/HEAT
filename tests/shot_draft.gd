extends SceneTree
func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("/home/claude/scratch/dr_%s.png" % n)
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main.splash_close.call()
	main.cfg["track"] = "spagna"
	main.cfg["n"] = 5
	main.cfg["kind"] = [0, 1, 1, 2, 2, 1, 1, 1]
	main.cfg["garage"] = 3
	main.cfg["weather"] = false
	main._fill_setup()
	for i in 10: await process_frame
	await shot("0setup")
	main._start_race(main._local_game())
	var k := 0
	while not main.dash.visible and k < 600:
		await process_frame
		k += 1
	for i in 20: await process_frame
	await shot("1draft")
	# scelte automatiche fino alla corsa, poi la prima reazione con un potenziamento in gioco
	while main.R.drafting():
		main.decided.emit(AI.draft_pick(main.R, main.R.cars[0]))
		for i in 30: await process_frame
	var t0 := Time.get_ticks_msec()
	var shots := 0
	while shots < 2 and Time.get_ticks_msec() - t0 < 120000:
		await process_frame
		if main.dash.visible:
			var hdr = main.dash_v.get_child(0) if main.dash_v.get_child_count() > 0 else null
			for i in 15: await process_frame
			var car: Dictionary = main.R.cars[0]
			if car["play"].is_empty():
				await shot("2plan%d" % shots)
				main.decided.emit(AI.plan(main.R, car))
			else:
				await shot("3react%d" % shots)
				shots += 1
				main.decided.emit("next")
				for i in 5: await process_frame
				main.decided.emit(false)
				for i in 5: await process_frame
				main.decided.emit([])
	quit()
