extends SceneTree
func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("/home/claude/scratch/ui_%s.png" % n)
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	await shot("0splash")
	main.splash_close.call()
	main.cfg["track"] = OS.get_environment("TK") if OS.get_environment("TK") != "" else "japan"
	main.cfg["n"] = 6
	main.cfg["kind"] = [0, 1, 1, 1, 2, 2, 1, 1]
	main.cfg["weather"] = true
	main._fill_setup()
	main._preview_track()
	for i in 10: await process_frame
	await shot("1setup")
	main._start_race(main._local_game())
	var k := 0
	while not main.dash.visible and k < 400:
		await process_frame
		k += 1
	for i in 30: await process_frame
	await shot("2plan")
	var car: Dictionary = main.R.cars[0]
	var p := AI.plan(main.R, car)
	main.decided.emit(p)
	k = 0
	while k < 2000:
		await process_frame
		k += 1
		if main.dash.visible and main.R.cars[0].get("s0") != null and not main.R.cars[0]["turn_done"]:
			break
	for i in 20: await process_frame
	await shot("3turn")
	quit()
