extends SceneTree
## Corsa intera con l'interfaccia, guidata tutta dal computer (per trovare errori). TK=pista
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5: await process_frame
	main.splash_close.call()
	main.autoplay = true
	main.cfg["track"] = OS.get_environment("TK") if OS.get_environment("TK") != "" else "usa"
	main.cfg["n"] = int(OS.get_environment("NC")) if OS.get_environment("NC") != "" else 6
	main.cfg["kind"] = [0, 0, 1, 1, 2, 2, 1, 1, 2, 2, 2, 2]
	main.cfg["lx"] = int(OS.get_environment("LX")) if OS.get_environment("LX") != "" else 0
	main.cfg["riv"] = true
	main.cfg["weather"] = OS.get_environment("MET") == "1"
	main.cfg["garage"] = int(OS.get_environment("GAR")) if OS.get_environment("GAR") != "" else 0
	main.board.step_time = 0.002
	main._start_race(main._local_game())
	main.board.step_time = 0.002
	var t0 := Time.get_ticks_msec()
	while main.racing and Time.get_ticks_msec() - t0 < 240000:
		await create_timer(0.5).timeout
	print("fine: racing=", main.racing, " turni=", main.R.round, " arrivati=", main.R.finished.size(), " ms=", Time.get_ticks_msec() - t0)
	for c in main.R.finished:
		print(c["place"], " ", c["name"], " ", c["kind"])
	quit()
