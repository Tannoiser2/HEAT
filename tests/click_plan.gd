extends SceneTree
## Verifica dei clic sul cruscotto: marcia (una sola accesa), carte selezionate, «Via così» attivo.
var main
func _all(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c.is_queued_for_deletion():
			continue
		out.append(c)
		_all(c, out)
func _nodes() -> Array:
	var a: Array = []
	_all(main.dash_v, a)
	return a
func _click(c: Control) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	c.gui_input.emit(ev)
func _settle() -> void:
	for f in 3:
		await process_frame
func _init() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5: await process_frame
	main.splash_close.call()
	main.cfg["n"] = 3
	main.cfg["kind"] = [0, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2]
	main._start_race(main._local_game())
	main.board.step_time = 0.002
	while not main.dash.visible:
		await process_frame
	await _settle()
	var ok := true
	for want in [3, 2, 1, 2]:
		var gb: Array = _nodes().filter(func(n): return n is Button and n.text.begins_with("%dª" % want))
		gb[0].pressed.emit()
		await _settle()
		var pressed: Array = _nodes().filter(func(n): return n is Button and n.toggle_mode and n.button_pressed)
		print("marcia ", want, " -> accese: ", pressed.map(func(b): return b.text.split("\n")[0]))
		if pressed.size() != 1:
			ok = false
	# carte: clicco le prime 2 giocabili
	for k in 2:
		var hand = _nodes().filter(func(n): return n.has_meta("mano"))[0]
		var cards: Array = hand.get_children().filter(func(c): return c.mouse_filter == Control.MOUSE_FILTER_STOP)
		var free_cards := cards.filter(func(c): return c.get_child_count() == 1)   # non ancora selezionate (senza cornice)
		_click(free_cards[0])
		await _settle()
	var vc: Array = _nodes().filter(func(n): return n is Button and n.text == "Via così")
	print("Via così attivo: ", not vc[0].disabled)
	if vc[0].disabled:
		ok = false
	var car: Dictionary = main.R.cars[0]
	vc[0].pressed.emit()
	await _settle()
	print("piano accettato: marcia ", car["gear"], ", carte giocate ", car["play"].size())
	if not (car["gear"] == 2 and car["play"].size() == 2):
		ok = false
	# resto del turno: reazioni e scia si saltano, negli scarti clicco una carta
	var scarti := "non arrivati"
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 60000 and main.R.round == 1 and not scarti.begins_with("clic"):
		main.board.step_time = 0.002
		await _settle()
		if not main.dash.visible:
			continue
		var bs: Array = _nodes().filter(func(n): return n is Button and not n.disabled)
		var fine: Array = bs.filter(func(b): return b.text == "Fine turno")
		if not fine.is_empty():
			var cards: Array = _nodes().filter(func(n): return n is Control and n.mouse_filter == Control.MOUSE_FILTER_STOP and n.get_child_count() >= 1 and n.get_child(0) is TextureRect)
			if cards.is_empty():
				scarti = "nessuna carta scartabile"
				fine[0].pressed.emit()
				continue
			_click(cards[0])
			await _settle()
			var sc: Array = _nodes().filter(func(n): return n is Button and n.text.begins_with("Scarta 1"))
			scarti = "clic sulla carta → «%s»" % (sc[0].text if not sc.is_empty() else "NIENTE")
			if sc.is_empty():
				print("tasti dopo il clic: ", _nodes().filter(func(n): return n is Button).map(func(b): return b.text), " max_scarti=", main.R.max_discard(), " carte cliccabili=", cards.size())
				ok = false
				break
			sc[0].pressed.emit()
			await _settle()
			continue
		for pref in ["Avanti", "No"]:
			var b: Array = bs.filter(func(x): return x.text == pref)
			if not b.is_empty():
				b[0].pressed.emit()
				break
	await _settle()
	var done: bool = car.get("turn_done", false) or main.R.round > 1
	print("scarti: ", scarti, " · turno concluso: ", done, " · mano ", car["hand"].size(), " carte")
	print("ESITO: ", "OK" if ok and done else "PROBLEMA")
	quit()
