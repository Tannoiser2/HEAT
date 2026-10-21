extends SceneTree
## Stampa le mosse delle Leggende dell'espansione per controllo: LX=livello
func _init() -> void:
	var R := Rules.new()
	var cfg: Array = []
	for i in 2:
		cfg.append({"kind": "cpu", "col": i, "level": 1})
	for i in 4:
		cfg.append({"kind": "legend", "col": 8 + i})
	R.setup(Track.by_key("italia"), cfg, {"seed": 7, "lx": int(OS.get_environment("LX")), "rivals": true})
	print("rivali ", R.rivals)
	while not R.all_finished() and R.round < 12:
		R.begin_round()
		for c in R.racing():
			if c["kind"] == "cpu":
				R.apply_plan(c, AI.plan(R, c))
		for c in R.start_moves():
			if c["kind"] == "legend":
				var s0: int = c["s"]
				R.legend_move(c)
				var evs := R.events.filter(func(e): return e.get("car", -1) == c["i"] or e["e"] == "legend_card")
				print("T", R.round, " ", c["name"], " ", s0, "->", c["s"], "/", c["lane"], " ", evs.map(func(e): return e["e"] + ":" + str(e.get("abs", e.get("a", e.get("n", e.get("why", ""))))) + ("" if e["e"] != "move" else str(e["why"]))))
				R.events.clear()
				R.end_turn(c)
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
			R.discard(c, AI.discards(R, c))
			R.end_turn(c)
			R.events.clear()
		R.end_round()
	quit()
