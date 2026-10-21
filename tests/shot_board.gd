extends SceneTree
func _init() -> void:
	var b := Board3D.new()
	root.add_child(b)
	await process_frame
	var key := OS.get_environment("TK") if OS.get_environment("TK") != "" else "japan"
	var t := Track.by_key(key)
	b.show_track(t)
	var R := Rules.new()
	var cfg: Array = []
	for i in 8:
		cfg.append({"kind": "cpu", "col": i})
	R.setup(t, cfg, {"seed": 5})
	b.make_cars(R.cars)
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("/home/claude/scratch/b1.png")
	b.focus(b.car_world(0), 9.0)
	b.target = b.desired
	b.yaw = 0.8
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("/home/claude/scratch/b2.png")
	b.dist = 3.5
	b.pitch = 0.45
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("/home/claude/scratch/b3.png")
	quit()
