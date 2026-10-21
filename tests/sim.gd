extends SceneTree
## Corse automatiche senza grafica: uso godot --headless --path . -s res://tests/sim.gd -- pista corse leggende meteo
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var key := args[0] if args.size() > 0 else "usa"
	var n := int(args[1]) if args.size() > 1 else 5
	var nleg := int(args[2]) if args.size() > 2 else 2
	var met := args.size() > 3 and args[3] == "1"
	var wins := {}
	var t0 := Time.get_ticks_msec()
	for k in n:
		var R := Rules.new()
		var cfg: Array = []
		for i in 4:
			cfg.append({"kind": "cpu", "col": i, "level": int(OS.get_environment("LEVEL")) if OS.get_environment("LEVEL") != "" else 1})
		for i in nleg:
			cfg.append({"kind": "legend", "col": 4 + i})
		var gar := int(OS.get_environment("GARAGE")) if OS.get_environment("GARAGE") != "" else 0
		var lx := int(OS.get_environment("LX")) if OS.get_environment("LX") != "" else 0
		R.setup(Track.by_key(key), cfg, {"seed": 1000 + k, "weather": met, "garage": gar, "lx": lx, "rivals": lx >= 2 and OS.get_environment("RIV") != "0"})
		while R.drafting():
			for c in R.draft_order():
				if R.needs_pick(c):
					R.draft_pick(c, AI.draft_pick(R, c))
			R.draft_advance()
		while not R.all_finished() and R.round < 200:
			R.begin_round()
			if OS.get_environment("DBG") != "": print("round ", R.round, " ", R.cars.map(func(c): return c["s"]))
			for c in R.racing():
				if c["kind"] == "cpu":
					if not R.apply_plan(c, AI.plan(R, c)):
						push_error("piano non valido")
			for c in R.start_moves():
				if c["kind"] == "legend":
					R.legend_move(c)

					if c["s"] >= R.track.finish_s() and c["fin_round"] < 0:
						c["fin_round"] = R.round
					continue
				R.reveal_flip(c)
				R.reveal_move(c, AI.choices(R, c))
				for a in AI.react(R, c):
					R.do_action(c, a)
				for a in AI.react_late(R, c):
					R.do_action(c, a)
				while AI.slip(R, c):
					R.slipstream(c)
				R.check_corners(c)
				var d := AI.discards(R, c)
				R.discard(c, d)
				R.end_turn(c)
			R.end_round()
			R.events.clear()
		var first: Dictionary = R.finished[0]
		wins[first["kind"]] = wins.get(first["kind"], 0) + 1
		var line := "corsa %d: %d turni |" % [k, R.round]
		for c in R.finished:
			line += " %s%s(c%d,sp%d,h%d)" % [c["kind"].substr(0, 1), c["col"], c["place"], c["stats"]["spin"], c["stats"]["heat"]]
		print(line)
	print("vittorie: ", wins, "  tempo ", Time.get_ticks_msec() - t0, " ms")
	quit()
