## HEAT – versione digitale per uso personale: menu, partita, interfaccia e gioco online.
extends Node3D

const VERSION := "0.6 (21 ottobre)"
const F_TITLE := preload("res://assets/font/RacingSansOne-Regular.ttf")
const F_BODY := preload("res://assets/font/BarlowCondensed-Medium.ttf")
const F_BOLD := preload("res://assets/font/BarlowCondensed-Bold.ttf")
const CREAM := Color("#F3E9D2")
const RED := Color("#D7262E")
const GOLD := Color("#F0B429")
const ASPHALT := Color(0.085, 0.085, 0.095, 0.95)
const INK := Color("#1B1B1D")
const ANIM_NAMES := ["Lente", "Normali", "Veloci"]
const ANIM_STEP := [0.2, 0.12, 0.06]
const KIND_KEYS := ["human", "cpu", "legend"]
const KIND_NAMES := ["Giocatore", "Computer", "Leggenda"]
const LEVEL_NAMES := ["Normale", "Difficile", "Esperto"]
const PRO_NAMES := ["Normali", "Pro +1", "Pro +2"]
const LX_LEVEL_TXT := ["Livello 1: carte dell'espansione senza stelle, come le Leggende del gioco base ma fino a 12 auto.",
	"Livello 2: mazzo verde, abilità della stella (carte Power Up).", "Livello 3: mazzi verde e giallo.",
	"Livello 4: mazzo giallo.", "Livello 5: mazzi giallo e rosso.", "Livello 6: mazzo rosso, il più difficile."]
const EXPANSION := {"usa": "base", "italia": "base", "france": "base", "gb": "base", "japan": "Heavy Rain", "mexico": "Heavy Rain",
	"spagna": "Tunnel Vision", "nederland": "Tunnel Vision", "sudafrica": "Rocky Roads", "germania": "Rocky Roads"}
const PANEL_W := 410.0
const SEASONS := ["1961", "1962", "1963", "1964", "1965", "1966", "A sorpresa"]
const DASH_H := 250.0
const CARD_W := 104.0
const CARD_RATIO := 1.5436

var board: Board3D
var R: Rules
var track: Track
var ui: CanvasLayer
var root: Control
var setup_box: PanelContainer
var setup_v: VBoxContainer
var cars_box: VBoxContainer
var track_grid: GridContainer
var track_info: Label
var panel: PanelContainer
var dash: PanelContainer
var lx_box: PanelContainer      # carta Leggenda e Power Up del turno
var lx_cards: HBoxContainer
var lx_lbl: Label
var dash_v: VBoxContainer
var status_lbl: Label
var standings_box: VBoxContainer
var log_box: RichTextLabel
var follow_btn: CheckButton
var anim_seg: HBoxContainer
var overlay: Control
var splash_close := Callable()
var cfg := {"n": 4, "kind": [0, 1, 1, 1, 2, 2, 1, 1, 2, 2, 2, 2], "track": "usa", "laps": 0, "weather": false, "cpu": 1, "pro": 0,
	"chev": true, "anim": 1, "garage": 0, "mode": 0, "season": 0, "pool": 0, "names": ["", "", "", "", "", "", "", "", "", "", "", ""],
	"lx": 0, "riv": true, "lxup": true}
var race_id := 0
var racing := false
var net: Net
var online := {}
var online_box: VBoxContainer
var online_lbl: Label
var online_name: LineEdit
var online_code: LineEdit
var where_seg: HBoxContainer
var champ := {}         # campionato in corso
var history: Array = []   # replay: stato delle auto all'inizio della corsa e a fine di ogni turno
var replay := {}
var results_ov: Control
var autoplay := false    # prove automatiche: i giocatori li guida il computer
var AWAY_MS := 60000
const CATCHUP_SPEED := 40.0

signal decided(value)

func _ready() -> void:
	board = Board3D.new()
	add_child(board)
	board.follow_changed.connect(func(on): if follow_btn: follow_btn.set_pressed_no_signal(on))
	ui = CanvasLayer.new()
	add_child(ui)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = F_BODY
	th.default_font_size = 20
	root.theme = th
	ui.add_child(root)
	if OS.get_environment("HEAT_AWAY_MS") != "":
		AWAY_MS = int(OS.get_environment("HEAT_AWAY_MS"))
	_load_prefs()
	_build_setup()
	_build_panel()
	_build_dash()
	_build_lx_box()
	get_viewport().size_changed.connect(_layout)
	_preview_track()
	_layout()
	_show_splash()

# ---------- stile ----------

func _style(bg: Color, radius := 10, margin := 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb

func _label(t: String, size := 20, col := CREAM, font: Font = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font:
		l.add_theme_font_override("font", font)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

## Etichetta su una riga sola (per le tabelle).
func _cell(t: String, size := 20, col := CREAM, font: Font = null) -> Label:
	var l := _label(t, size, col, font)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l

func _title(t: String, size := 30, col := CREAM) -> Label:
	var l := _label(t, size, col, F_TITLE)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l

func _section(t: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var bar := ColorRect.new()
	bar.color = RED
	bar.custom_minimum_size = Vector2(6, 22)
	h.add_child(bar)
	var l := _label(t.to_upper(), 17, GOLD, F_BOLD)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h

func _row(title: String, ctrl: Control, w := 120) -> HBoxContainer:
	var r := HBoxContainer.new()
	var l := _label(title, 19, Color(CREAM, 0.9))
	l.custom_minimum_size.x = w
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.add_child(l)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(ctrl)
	return r

func _btn_styles(b: Button, on: Color, off: Color, radius := 5) -> void:
	var s_on := _style(on, radius, 6)
	var s_off := _style(off, radius, 6)
	var s_hov := _style(off.lightened(0.12) if off.a > 0.5 else Color(1, 1, 1, 0.16), radius, 6)
	var s_dis := _style(Color(off, off.a * 0.4), radius, 6)
	b.add_theme_stylebox_override("pressed", s_on)
	b.add_theme_stylebox_override("hover_pressed", s_on)
	b.add_theme_stylebox_override("normal", s_off)
	b.add_theme_stylebox_override("hover", s_hov)
	b.add_theme_stylebox_override("disabled", s_dis)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

## Gruppo di tasti a scelta singola.
func _seg(options: Array, selected: int, on_change: Callable, size := 18) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var group := ButtonGroup.new()
	for i in options.size():
		var b := Button.new()
		b.text = options[i]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == selected
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", size)
		_btn_styles(b, GOLD, Color(1, 1, 1, 0.08))
		b.add_theme_color_override("font_pressed_color", INK)
		b.add_theme_color_override("font_hover_pressed_color", INK)
		b.pressed.connect(func(): on_change.call(i))
		box.add_child(b)
	return box

func _big_button(t: String, col := RED, fcol := CREAM, size := 24) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", F_TITLE)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", fcol)
	b.add_theme_color_override("font_hover_color", fcol)
	b.add_theme_color_override("font_pressed_color", fcol)
	_btn_styles(b, col.darkened(0.2), col, 8)
	b.custom_minimum_size.y = 46
	return b

func _small_button(t: String, col := Color(1, 1, 1, 0.12), fcol := CREAM) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", F_BOLD)
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", fcol)
	b.add_theme_color_override("font_hover_color", fcol)
	b.add_theme_color_override("font_disabled_color", Color(fcol, 0.35))
	_btn_styles(b, col.darkened(0.25), col, 6)
	b.custom_minimum_size.y = 38
	return b

func _swatch(c: Color, size := 18) -> Panel:
	var p := Panel.new()
	var sb := _style(c, 4, 0)
	sb.border_color = Color(1, 1, 1, 0.5)
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(size, size)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p

## Fascia a scacchi (bandiera a scacchi) come decorazione delle intestazioni.
func _checker(h := 10, _n := 40) -> Control:
	var img := Image.create(h * 2, h, false, Image.FORMAT_RGBA8)
	var half := h / 2
	for y in h:
		for x in h * 2:
			var on := ((x / half) + (y / half)) % 2 == 0
			img.set_pixel(x, y, CREAM if on else INK)
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.stretch_mode = TextureRect.STRETCH_TILE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.custom_minimum_size = Vector2(0, h)
	tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

func _hex(c: Color) -> String:
	return "#" + c.to_html(false)

func _car_name(c: Dictionary) -> String:
	return c["name"]

func _car_tag(c: Dictionary) -> String:
	var col: Color = Rules.COLORS[c["col"]]
	if c["col"] == 5:
		col = Color("#9A9AA2")
	return "[color=%s][b]%s[/b][/color]" % [_hex(col), _car_name(c)]

func log_line(t: String) -> void:
	log_box.append_text(t + "\n")

func _msg(t: String) -> void:
	var d := AcceptDialog.new()
	d.title = "HEAT"
	d.dialog_text = t
	d.ok_button_text = "Va bene"
	root.add_child(d)
	d.popup_centered(Vector2i(520, 160))
	d.confirmed.connect(d.queue_free)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

# ---------- preferenze ----------

const PREFS := "user://heat_prefs.cfg"

func _load_prefs() -> void:
	var c := ConfigFile.new()
	if c.load(PREFS) != OK:
		return
	for k in cfg:
		if c.has_section_key("cfg", k):
			cfg[k] = c.get_value("cfg", k)
	while cfg["kind"].size() < Rules.MAX_CARS:
		cfg["kind"].append(2)
	while cfg["names"].size() < Rules.MAX_CARS:
		cfg["names"].append("")
	if cfg["lx"] == 0 and cfg["n"] > Rules.PLAYER_COLORS:
		cfg["n"] = Rules.PLAYER_COLORS

func _save_prefs() -> void:
	var c := ConfigFile.new()
	for k in cfg:
		c.set_value("cfg", k, cfg[k])
	c.save(PREFS)

# ---------- copertina ----------

func _show_splash() -> void:
	var sp := Control.new()
	sp.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#0E0D0C")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	sp.add_child(bg)
	var cover := TextureRect.new()
	cover.texture = load("res://assets/copertina.webp")
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.offset_top = 30
	cover.offset_bottom = -110
	sp.add_child(cover)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	v.offset_top = -100
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var t := _label("Versione digitale per uso personale · tocca per entrare ai box", 22, CREAM)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var t2 := _label("versione " + VERSION, 15, Color(CREAM, 0.5))
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t2)
	sp.add_child(v)
	root.add_child(sp)
	sp.mouse_filter = Control.MOUSE_FILTER_STOP
	splash_close = func():
		if is_instance_valid(sp):
			sp.queue_free()
		splash_close = Callable()
	sp.gui_input.connect(func(ev):
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			if splash_close.is_valid():
				splash_close.call())

func _input(ev: InputEvent) -> void:
	if splash_close.is_valid() and ev is InputEventKey and ev.pressed:
		splash_close.call()

# ---------- menu di preparazione ----------

func _build_setup() -> void:
	setup_box = PanelContainer.new()
	setup_box.add_theme_stylebox_override("panel", _style(ASPHALT, 12, 16))
	root.add_child(setup_box)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	setup_box.add_child(scroll)
	setup_v = VBoxContainer.new()
	setup_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup_v.add_theme_constant_override("separation", 9)
	scroll.add_child(setup_v)
	_fill_setup()

func _fill_setup() -> void:
	for c in setup_v.get_children():
		c.queue_free()
	var v := setup_v
	var head := HBoxContainer.new()
	var logo := _title("HEAT", 46, RED)
	logo.add_theme_color_override("font_outline_color", CREAM)
	logo.add_theme_constant_override("outline_size", 6)
	head.add_child(logo)
	var sub := _label("Pedal to the Metal\nversione digitale", 18, CREAM, F_BOLD)
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(sub)
	v.add_child(head)
	v.add_child(_checker(12, 44))
	# partita
	v.add_child(_section("Partita"))
	where_seg = _seg(["Su questo dispositivo", "Online"], 1 if online_box and online_box.visible else 0, func(i):
		online_box.visible = i == 1)
	v.add_child(_row("Dove", where_seg))
	_build_online_box(v)
	v.add_child(_row("Tipo", _seg(["Corsa singola", "Campionato"], cfg["mode"], func(i):
		cfg["mode"] = i
		_save_prefs()
		_fill_setup())))
	# auto
	v.add_child(_section("Auto in gara"))
	var ncars: Array = []
	for k in range(2, (Rules.MAX_CARS if cfg["lx"] > 0 else Rules.PLAYER_COLORS) + 1):
		ncars.append(str(k))
	v.add_child(_row("Auto", _seg(ncars, cfg["n"] - 2, func(i):
		cfg["n"] = i + 2
		_fill_cars()
		_save_prefs(), 15 if ncars.size() > 7 else 18)))
	cars_box = VBoxContainer.new()
	cars_box.add_theme_constant_override("separation", 4)
	v.add_child(cars_box)
	_fill_cars()
	v.add_child(_row("Computer", _seg(LEVEL_NAMES, cfg["cpu"], func(i):
		cfg["cpu"] = i
		_save_prefs())))
	v.add_child(_row("Leggende", _seg(["Gioco base", "Espansione Legends"], 1 if cfg["lx"] > 0 else 0, func(i):
		cfg["lx"] = 2 if i == 1 else 0
		if cfg["lx"] == 0:
			cfg["n"] = mini(cfg["n"], Rules.PLAYER_COLORS)
		_save_prefs()
		_fill_setup())))
	if cfg["lx"] == 0:
		v.add_child(_row("Bravura", _seg(PRO_NAMES, cfg["pro"], func(i):
			cfg["pro"] = i
			_save_prefs())))
	else:
		v.add_child(_row("Livello", _seg(["1", "2", "3", "4", "5", "6"], cfg["lx"] - 1, func(i):
			cfg["lx"] = i + 1
			_save_prefs()
			_fill_setup())))
		v.add_child(_label(LX_LEVEL_TXT[cfg["lx"] - 1], 15, Color(CREAM, 0.6)))
		if cfg["lx"] >= 2:
			v.add_child(_row("Rivali", _seg(["No", "Sì"], 1 if cfg["riv"] else 0, func(i):
				cfg["riv"] = i == 1
				_save_prefs())))
		if cfg["mode"] == 1:
			v.add_child(_row("Campionato", _seg(["Livello fisso", "+1 a ogni gara"], 1 if cfg["lxup"] else 0, func(i):
				cfg["lxup"] = i == 1
				_save_prefs(), 16)))
	if cfg["mode"] == 1:
		_fill_champ_setup(v)
		return
	# pista
	v.add_child(_section("Pista"))
	track_grid = GridContainer.new()
	track_grid.columns = 2
	track_grid.add_theme_constant_override("h_separation", 4)
	track_grid.add_theme_constant_override("v_separation", 4)
	v.add_child(track_grid)
	var group := ButtonGroup.new()
	for t in Track.all():
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.text = "%s  ·  %s" % [t.name, EXPANSION.get(t.key, "")]
		b.button_pressed = t.key == cfg["track"]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 17)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_btn_styles(b, GOLD, Color(1, 1, 1, 0.08))
		b.add_theme_color_override("font_pressed_color", INK)
		b.add_theme_color_override("font_hover_pressed_color", INK)
		var key: String = t.key
		b.pressed.connect(func():
			cfg["track"] = key
			_save_prefs()
			_preview_track())
		track_grid.add_child(b)
	track_info = _label("", 17, Color(CREAM, 0.8))
	v.add_child(track_info)
	v.add_child(_row("Giri", _seg(["Da tabellone", "1", "2", "3"], cfg["laps"], func(i):
		cfg["laps"] = i
		_save_prefs()
		_update_track_info())))
	# moduli
	v.add_child(_section("Moduli"))
	v.add_child(_row("Meteo", _seg(["No", "Meteo e condizioni della strada"], 1 if cfg["weather"] else 0, func(i):
		cfg["weather"] = i == 1
		_save_prefs())))
	v.add_child(_row("Garage", _seg(["Carte iniziali", "3 a caso", "Draft", "Draft completo"], cfg["garage"], func(i):
		cfg["garage"] = i
		_save_prefs(), 16)))
	v.add_child(_label("Garage: ogni auto monta 3 potenziamenti al posto delle carte iniziali. «Draft completo» usa anche le carte avanzate e quelle delle espansioni.", 15, Color(CREAM, 0.6)))
	v.add_child(_row("Leggende\naggressive", _seg(["Sì (frecce sui rombi)", "No"], 0 if cfg["chev"] else 1, func(i):
		cfg["chev"] = i == 0
		_save_prefs())))
	v.add_child(_row("Animazioni", _seg(ANIM_NAMES, cfg["anim"], func(i):
		cfg["anim"] = i
		board.step_time = ANIM_STEP[i]
		_save_prefs())))
	board.step_time = ANIM_STEP[cfg["anim"]]
	_setup_footer(v)

func _setup_footer(v: VBoxContainer) -> void:
	var go := _big_button("Semaforo verde!", RED, CREAM, 28)
	go.pressed.connect(_on_start_pressed)
	v.add_child(go)
	var ver := _label("Versione %s · regole del gioco base, Leggende, meteo e strada, Garage e Campionato, espansioni Heavy Rain, Tunnel Vision, Rocky Roads e Legends." % VERSION, 14, Color(CREAM, 0.45))
	v.add_child(ver)

func _fill_champ_setup(v: VBoxContainer) -> void:
	v.add_child(_section("Campionato"))
	v.add_child(_row("Stagione", _seg(SEASONS, cfg["season"], func(i):
		cfg["season"] = i
		_save_prefs()
		_fill_setup(), 15)))
	var races := _season_events(cfg["season"], 0)
	var lines: Array = []
	for e in races:
		lines.append("%d. %s – %s" % [e["r"], Track.by_key(e["t"]).name, e["name"]] if cfg["season"] < 6 else "%d. pista ed evento a sorpresa" % e["r"])
	v.add_child(_label("\n".join(lines), 17, Color(CREAM, 0.8)))
	v.add_child(_label("Prima di ogni gara ognuno monta un potenziamento nuovo (e tiene quelli vecchi); si corre sempre con meteo e condizioni della strada, sponsor e curve della stampa. Punti: 9, 6, 4, 3, 2, 1.", 15, Color(CREAM, 0.6)))
	v.add_child(_row("Potenziamenti", _seg(["Normali", "Avanzati", "Tutti"], cfg["pool"], func(i):
		cfg["pool"] = i
		_save_prefs(), 16)))
	v.add_child(_row("Leggende\naggressive", _seg(["Sì", "No"], 0 if cfg["chev"] else 1, func(i):
		cfg["chev"] = i == 0
		_save_prefs())))
	v.add_child(_row("Animazioni", _seg(ANIM_NAMES, cfg["anim"], func(i):
		cfg["anim"] = i
		board.step_time = ANIM_STEP[i]
		_save_prefs())))
	if not races.is_empty():
		var k: String = races[0]["t"]
		if track == null or track.key != k:
			cfg["track"] = k
			_preview_track()
	_setup_footer(v)

## Carte Evento di una stagione (6 = a sorpresa: 4 piste diverse con eventi a caso).
func _season_events(season: int, seed_v: int) -> Array:
	if season < 6:
		var y := 1961 + season
		var out: Array = []
		for e in Rules.EVENTS:
			if int(e["y"]) == y:
				out.append(e.duplicate())
		out.sort_custom(func(a, b): return a["r"] < b["r"])
		return out
	var g := RandomNumberGenerator.new()
	g.seed = seed_v
	var keys: Array = Track.all().map(func(t): return t.key)
	Rules._shuffle(keys, g)
	var evs: Array = Rules.EVENTS.duplicate()
	Rules._shuffle(evs, g)
	var res: Array = []
	for k in 4:
		var e: Dictionary = evs[k].duplicate()
		e["t"] = keys[k]
		e["r"] = k + 1
		res.append(e)
	return res

func _fill_cars() -> void:
	for c in cars_box.get_children():
		c.queue_free()
	for i in cfg["n"]:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		r.add_child(_swatch(Rules.COLORS[i], 20))
		var nm := LineEdit.new()
		nm.placeholder_text = Rules.COLOR_NAMES[i]
		nm.text = cfg["names"][i]
		nm.custom_minimum_size.x = 104
		nm.max_length = 16
		nm.add_theme_font_size_override("font_size", 17)
		var idx: int = i
		nm.text_changed.connect(func(t):
			cfg["names"][idx] = t
			_save_prefs())
		r.add_child(nm)
		var opts: Array = KIND_NAMES
		if i >= Rules.PLAYER_COLORS:
			opts = ["Leggenda"]
		elif i >= 6 and cfg["lx"] == 0:
			opts = KIND_NAMES.slice(0, 2)
		var k: int = cfg["kind"][i]
		if i >= Rules.PLAYER_COLORS:
			k = 0
		elif k >= opts.size():
			k = 1
			cfg["kind"][i] = 1
		var seg := _seg(opts, k, func(j):
			cfg["kind"][idx] = j if idx < Rules.PLAYER_COLORS else 2
			_save_prefs(), 16)
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(seg)
		cars_box.add_child(r)

func _update_track_info() -> void:
	var t := Track.by_key(cfg["track"])
	var laps: int = t.laps if cfg["laps"] == 0 else cfg["laps"]
	var feats: Array = []
	for sp in t.spaces:
		if sp.has("flood") and not feats.has("tratti allagati"):
			feats.append("tratti allagati")
		if sp.has("tunnel") and not feats.has("gallerie"):
			feats.append("gallerie")
		if sp.has("gravel") and not feats.has("ghiaia"):
			feats.append("ghiaia")
	var chic := 0
	for g in t.groups:
		if g.size() > 1:
			chic += 1
	if chic > 0:
		feats.append("%d chicane" % chic)
	track_info.text = "%d caselle, %d curve, %d giri. Motore: %d Calore, mazzo con %d Stress.%s" % [t.n, t.corners.size(), laps, t.heat, t.stress,
		(" Particolarità: " + ", ".join(feats) + ".") if not feats.is_empty() else ""]

func _preview_track() -> void:
	if racing:
		return
	track = Track.by_key(cfg["track"])
	board.show_track(track)
	board.clear_tokens()
	_update_track_info()
	_layout()
	board.fit_view()

# ---------- pannello di gara ----------

func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(ASPHALT, 0, 12))
	panel.visible = false
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	var logo := _title("HEAT", 30, RED)
	top.add_child(logo)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	follow_btn = CheckButton.new()
	follow_btn.text = "Segui"
	follow_btn.button_pressed = true
	follow_btn.focus_mode = Control.FOCUS_NONE
	follow_btn.toggled.connect(func(on): board.follow = on)
	top.add_child(follow_btn)
	var all_btn := _small_button("Tutta")
	all_btn.pressed.connect(func():
		board.follow = false
		follow_btn.set_pressed_no_signal(false)
		board.fit_view())
	top.add_child(all_btn)
	var menu := _small_button("Menu", Color(RED, 0.8))
	menu.pressed.connect(_ask_menu)
	top.add_child(menu)
	v.add_child(top)
	anim_seg = _seg(ANIM_NAMES, cfg["anim"], func(i):
		cfg["anim"] = i
		board.step_time = ANIM_STEP[i], 15)
	v.add_child(_row("Animazioni", anim_seg, 90))
	v.add_child(_checker(10, 44))
	status_lbl = _label("", 21, GOLD, F_BOLD)
	v.add_child(status_lbl)
	standings_box = VBoxContainer.new()
	standings_box.add_theme_constant_override("separation", 2)
	v.add_child(standings_box)
	var lt := _label("CRONACA", 15, Color(CREAM, 0.6), F_BOLD)
	v.add_child(lt)
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.add_theme_font_size_override("normal_font_size", 17)
	log_box.add_theme_font_size_override("bold_font_size", 17)
	log_box.add_theme_font_override("normal_font", F_BODY)
	log_box.add_theme_font_override("bold_font", F_BOLD)
	log_box.add_theme_color_override("default_color", CREAM)
	v.add_child(log_box)

func _build_dash() -> void:
	dash = PanelContainer.new()
	var sb := _style(Color(0.06, 0.06, 0.07, 0.93), 12, 10)
	sb.border_color = Color(GOLD, 0.6)
	sb.border_width_top = 3
	dash.add_theme_stylebox_override("panel", sb)
	dash.visible = false
	root.add_child(dash)
	dash_v = VBoxContainer.new()
	dash_v.add_theme_constant_override("separation", 6)
	dash.add_child(dash_v)

func _build_lx_box() -> void:
	lx_box = PanelContainer.new()
	var sb := _style(Color(0.06, 0.06, 0.07, 0.82), 10, 8)
	sb.border_color = Color("#C9B6FF", 0.7)
	sb.set_border_width_all(2)
	lx_box.add_theme_stylebox_override("panel", sb)
	lx_box.visible = false
	lx_box.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(lx_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lx_box.add_child(v)
	var t := _label("Leggende", 17, Color("#C9B6FF"), F_BOLD)
	v.add_child(t)
	lx_cards = HBoxContainer.new()
	lx_cards.add_theme_constant_override("separation", 6)
	lx_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(lx_cards)
	lx_lbl = _label("", 14, Color(CREAM, 0.85))
	lx_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lx_lbl.custom_minimum_size.x = 150
	v.add_child(lx_lbl)

## Mostra la carta Leggenda (e il Power Up) girata in questo turno, oppure solo il retro.
func _update_lx_box() -> void:
	var legends := R != null and racing and R.cars.any(func(c): return c["kind"] == "legend")
	lx_box.visible = legends
	if not legends:
		return
	for c in lx_cards.get_children():
		lx_cards.remove_child(c)
		c.queue_free()
	var vs := get_viewport().get_visible_rect().size
	var w := 74.0 if vs.x < 900 else 116.0
	var texs: Array = []
	if R.legend_card >= 0:
		texs.append(load("res://assets/carte/lx_%d.webp" % R.legend_card) if R.lx_level > 0 else load("res://assets/carte/leggenda_%d.webp" % (R.legend_card + 1)))
	else:
		texs.append(load("res://assets/carte/lx_retro.webp") if R.lx_level > 0 else load("res://assets/carte/lx_retro.webp"))
	if R.lx_level >= 2:
		texs.append(load("res://assets/carte/pu_%d.webp" % R.pu_card) if R.pu_card >= 0 else load("res://assets/carte/pu_retro.webp"))
	for tx in texs:
		var tr := TextureRect.new()
		tr.texture = tx
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		tr.custom_minimum_size = Vector2(w, w * CARD_RATIO)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lx_cards.add_child(tr)
	var lines: Array = []
	if R.lx_level >= 2 and R.pu_card >= 0:
		var pu: Dictionary = Rules.POWER_UPS[R.pu_card]
		lines.append("★ Stella: %s" % Rules.ABILITY_NAMES[pu["s"]])
		if not R.rivals.is_empty():
			lines.append("Abilità dei Rivali: %s" % Rules.ABILITY_NAMES[pu["r"]])
	if not R.rivals.is_empty():
		lines.append("Rivali: " + ", ".join(R.rivals.map(func(i): return R.cars[i]["name"].replace("Leggenda ", "").capitalize())))
	lx_lbl.text = "\n".join(lines)
	var tips: Array = []
	if R.lx_level >= 2 and R.pu_card >= 0:
		var pu2: Dictionary = Rules.POWER_UPS[R.pu_card]
		tips.append("Stella – %s: %s." % [Rules.ABILITY_NAMES[pu2["s"]], Rules.ABILITY_TXT[pu2["s"]]])
		if not R.rivals.is_empty():
			tips.append("Rivali – %s: %s." % [Rules.ABILITY_NAMES[pu2["r"]], Rules.ABILITY_TXT[pu2["r"]]])
		tips.append("Se l'abilità non si può usare, la Leggenda fa 1 casella in più.")
	lx_box.tooltip_text = "\n".join(tips)
	lx_lbl.custom_minimum_size.x = w * texs.size() + 6 * (texs.size() - 1)
	lx_box.size = Vector2.ZERO
	lx_box.reset_size()
	_layout()
	(func(): if is_instance_valid(lx_box): lx_box.reset_size()).call_deferred()

func _clear_dash() -> void:
	for c in dash_v.get_children():
		c.queue_free()

func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var narrow := vs.x < 900
	if setup_box.visible:
		var w := minf(560.0, vs.x - 24.0) if not narrow else vs.x - 24.0
		setup_box.position = Vector2(12, 12)
		setup_box.size = Vector2(w, vs.y - 24 if not narrow else vs.y * 0.62)
		if narrow:
			setup_box.position = Vector2(12, vs.y * 0.38 - 12)
			board.screen_shift = Vector2(0, -0.31)
		else:
			board.screen_shift = Vector2(-(w + 12) / vs.x, 0)
		lx_box.visible = false
	else:
		lx_box.position = Vector2(10, 10)
		var pw := PANEL_W if not narrow else vs.x
		var ph := vs.y if not narrow else vs.y * 0.34
		var dh := DASH_H if dash.visible else 0.0
		if dash.visible and narrow:
			# su schermo stretto il cruscotto cresce quanto serve e la classifica si stringe
			ph = vs.y * 0.24
			dh = clampf(dash_v.get_combined_minimum_size().y + 26.0, DASH_H, vs.y * 0.66)
		panel.position = Vector2(vs.x - pw, 0) if not narrow else Vector2(0, vs.y - ph)
		panel.size = Vector2(pw, ph)
		var dw := vs.x - (pw if not narrow else 0.0)
		dash.position = Vector2(0, vs.y - dh - (0.0 if not narrow else ph))
		dash.size = Vector2(dw, dh)
		if narrow:
			board.screen_shift = Vector2(0, (ph + dh) / vs.y * 0.5)
		else:
			board.screen_shift = Vector2(pw / vs.x * 0.5, dh / vs.y * 0.5)

func _show_dash(on: bool) -> void:
	dash.visible = on
	_layout()

# ---------- avvio della corsa ----------

func _on_start_pressed() -> void:
	if cfg["mode"] == 1 and not online_box.visible:
		_start_champ(_local_game())
		return
	if online_box.visible:
		if online.get("role", "") == "host":
			_online_start()
		elif online.is_empty():
			_online_create()
		else:
			_msg("Aspetta che chi ha creato la stanza dia il via.")
		return
	_start_race(_local_game())

## Descrizione completa della corsa (la stessa che si manda agli altri dispositivi online).
func _local_game() -> Dictionary:
	var g := RandomNumberGenerator.new()
	g.randomize()
	var cars: Array = []
	for i in cfg["n"]:
		var nm: String = cfg["names"][i].strip_edges()
		var kind: String = KIND_KEYS[cfg["kind"][i]] if i < Rules.PLAYER_COLORS else "legend"
		if kind == "legend" and cfg["lx"] == 0 and i >= 6:
			kind = "cpu"
		if nm == "":
			nm = Rules.COLOR_NAMES[i] if kind != "legend" else "Leggenda " + Rules.COLOR_NAMES[i].to_lower()
		cars.append({"kind": kind, "col": i, "name": nm, "level": cfg["cpu"]})
	return {"seed": g.randi() % 2000000000 + 1, "track": cfg["track"], "laps": cfg["laps"], "cars": cars,
		"weather": cfg["weather"], "pro": cfg["pro"], "chev": cfg["chev"], "garage": cfg["garage"], "version": VERSION,
		"lx": cfg["lx"], "riv": cfg["riv"], "lxup": cfg["lxup"]}

## Nuovo campionato: la descrizione della partita è la stessa di una corsa, più la stagione.
func _start_champ(game: Dictionary) -> void:
	if not game.has("champ"):
		game["champ"] = {"season": cfg["season"], "pool": cfg["pool"]}
	champ = {"game": game, "events": _season_events(int(game["champ"]["season"]), int(game["seed"])), "idx": 0, "points": {}, "carry": {}, "last": {}, "results": []}
	for i in game["cars"].size():
		champ["points"][i] = 0
	_start_race(_champ_race_game())

## Corsa del campionato in corso: pista, giri, griglia secondo la classifica, potenziamenti e sponsor.
func _champ_race_game() -> Dictionary:
	var base: Dictionary = champ["game"]
	var e: Dictionary = champ["events"][champ["idx"]]
	var g := base.duplicate(true)
	g["seed"] = int(base["seed"]) + 7919 * (champ["idx"] + 1)
	g["track"] = e["t"]
	var t := Track.by_key(e["t"])
	var laps := t.laps
	if e["id"] == "61-3":
		laps -= 1
	if e["id"] in ["62-2", "65-4"]:
		laps += 1
	g["laps"] = maxi(1, laps)
	g["weather"] = true
	g["garage"] = 4
	g["pool"] = int(base.get("champ", {}).get("pool", 0))
	g["event"] = e
	g["carry"] = champ["carry"]
	g["race_idx"] = champ["idx"]
	# espansione Legends: livello che sale e Rivali (dalla seconda gara, le due Leggende prime in classifica)
	if int(base.get("lx", 0)) > 0:
		if base.get("lxup", false):
			g["lx"] = mini(6, int(base["lx"]) + champ["idx"])
		g["rival_cars"] = []
		if champ["idx"] > 0:
			var ls: Array = range(base["cars"].size()).filter(func(i): return base["cars"][i]["kind"] == "legend")
			ls.sort_custom(func(a, b):
				if champ["points"][a] != champ["points"][b]:
					return champ["points"][a] > champ["points"][b]
				return int(champ["last"].get(a, 99)) < int(champ["last"].get(b, 99)))
			g["rival_cars"] = ls.slice(0, 2)
	if champ["idx"] > 0:
		var order: Array = range(base["cars"].size())
		order.sort_custom(func(a, b):
			if champ["points"][a] != champ["points"][b]:
				return champ["points"][a] > champ["points"][b]
			return int(champ["last"].get(a, 99)) < int(champ["last"].get(b, 99)))
		g["grid"] = order
	return g

func _start_race(game: Dictionary) -> void:
	race_id += 1
	replay["token"] = int(replay.get("token", 0)) + 1
	racing = true
	if splash_close.is_valid():
		splash_close.call()
	var t := Track.by_key(game["track"]).clone()
	if int(game.get("laps", 0)) > 0:
		t.laps = int(game["laps"])
	track = t
	R = Rules.new()
	R.setup(t, game["cars"], {"seed": int(game["seed"]), "weather": bool(game.get("weather", false)),
		"legend_pro": int(game.get("pro", 0)), "chevrons": bool(game.get("chev", true)), "garage": int(game.get("garage", 0)),
		"pool": int(game.get("pool", 0)), "event": game.get("event", {}), "carry": _int_keys(game.get("carry", {})), "grid": game.get("grid", []),
		"lx": int(game.get("lx", 0)), "rivals": bool(game.get("riv", false)) and (not game.has("event") or int(game.get("race_idx", 0)) > 0),
		"rival_cars": game.get("rival_cars", [])})
	if not online.is_empty():
		online["race_idx"] = int(game.get("race_idx", 0))
	setup_box.visible = false
	panel.visible = true
	log_box.clear()
	board.show_track(t)
	board.make_cars(R.cars)
	history = [{"round": 0, "s": _cars_state(), "spun": []}]
	_show_tokens()
	_layout()
	board.fit_view()
	board.follow = true
	follow_btn.set_pressed_no_signal(true)
	log_line("[b]%s[/b] · %d giri, %d caselle a giro. Motore con %d Calore, %d carte Stress nel mazzo." % [t.name, t.laps, t.n, t.heat, t.stress])
	if not R.event.is_empty():
		log_line("[color=#F0B429][b]Campionato %s, gara %d di %d – %s[/b][/color]" % [SEASONS[int(champ["game"]["champ"]["season"])], champ["idx"] + 1, champ["events"].size(), R.event["name"]])
		log_line("[color=#F0B429]%s[/color]" % R.event["txt"])
		if not R.press.is_empty():
			log_line("Curve della stampa: %s (sponsor a chi le passa in scia o supera il limite di 2 o più)." % ", ".join(R.press.map(func(k): return "curva %d" % (k + 1))))
		if int(R.event.get("sp", 0)) > 0:
			log_line("Ogni pilota parte con %d sponsor in mano." % int(R.event["sp"]))
	if R.weather >= 0:
		var w: Dictionary = Rules.WEATHER[R.weather]
		log_line("[color=#8FD3FF]Meteo: [b]%s[/b] – %s.[/color]" % [w["name"], w["txt"]])
		for gi in R.road:
			var tok: Dictionary = Rules.ROAD[R.road[gi]]
			var k: int = t.groups[gi][0]
			log_line("  · curva %d: %s (%s)" % [k + 1, tok["name"], tok["txt"]])
	var grid_txt: Array = []
	var by_grid := R.cars.duplicate()
	by_grid.sort_custom(func(a, b): return a["grid"] < b["grid"])
	for c in by_grid:
		grid_txt.append("%d. %s" % [c["grid"], _car_tag(c)])
	log_line("Griglia: " + ", ".join(grid_txt))
	_update_standings()
	_race_start(race_id)

func _race_start(my: int) -> void:
	if R.drafting():
		await _draft_phase(my)
		if my != race_id:
			return
	elif R.garage == 1:
		for c in R.cars:
			if c["kind"] != "legend":
				log_line("%s monta: %s." % [_car_tag(c), ", ".join(R.upgrades[c["i"]].map(func(id): return "%s (%d)" % [Rules.UPG[id]["n"], id]))])
	_race_loop(my)

## Draft dei potenziamenti: tre giri, ogni auto sceglie una carta dal mercato.
func _draft_phase(my: int) -> void:
	log_line("[color=#F0B429]— Garage: draft dei potenziamenti —[/color]")
	while my == race_id and R.drafting():
		var rnd := R.draft_round
		for car in R.draft_order():
			if my != race_id:
				return
			if not R.needs_pick(car):
				continue
			_update_status("Garage, giro %d: sceglie %s" % [rnd, car["name"]])
			var id := -1
			if online.is_empty():
				if _is_local_human(car):
					var humans := R.cars.filter(func(c): return c["kind"] == "human")
					if humans.size() > 1:
						await _pass_device(car, "scegliere un potenziamento")
					id = await _ask_draft(car)
				else:
					id = AI.draft_pick(R, car)
			else:
				id = await _online_draft(my, car)
			if my != race_id:
				return
			if not R.draft_pick(car, id):
				R.draft_pick(car, AI.draft_pick(R, car))
			await _play_events(my)
		R.draft_advance()
	_show_dash(false)

func _ask_draft(car: Dictionary) -> int:
	var my := race_id
	_show_dash(true)
	_clear_dash()
	dash_v.add_child(_dash_header(car, "Garage, giro %d di 3: scegli un potenziamento" % R.draft_round))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var w := clampf(_card_w(140) * 7.0 / maxf(7.0, R.draft_market.size()), 60.0, 112.0)
	for id in R.draft_market:
		var c := Rules.make_upg(int(id))
		var cv := _card_view(car, c, w)
		cv.mouse_filter = Control.MOUSE_FILTER_STOP
		cv.tooltip_text = _upg_text(int(id))
		cv.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				decided.emit(int(id)))
		row.add_child(cv)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 230
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var have: Array = R.upgrades[car["i"]]
	side.add_child(_rich("Già montati: %s" % (", ".join(have.map(func(x): return Rules.UPG[x]["n"])) if not have.is_empty() else "nessuno")))
	var hint := _small_button("Consiglio")
	hint.pressed.connect(func(): decided.emit(AI.draft_pick(R, car)))
	side.add_child(hint)
	row.add_child(side)
	dash_v.add_child(row)
	var id = await decided
	if my == race_id:
		_show_dash(false)
	return int(id) if id != null else -1

## Descrizione in italiano degli effetti di una carta potenziamento.
func _upg_text(id: int) -> String:
	var i: Dictionary = Rules.UPG[id]
	var p: Array = []
	if i.get("hc", false):
		return "Carta Calore in più nel mazzo."
	if i.has("ch"):
		p.append("valore a scelta " + "/".join(i["ch"].map(func(x): return str(x))))
	elif i.has("v"):
		p.append("valore %d" % i["v"])
	if i.has("plus"):
		p.append("%d carta/e dal mazzo" % i["plus"])
	for k in [["heat", "paga %d Calore"], ["scrap", "scarta %d dal mazzo"], ["lim", "limite curve %+d"], ["cool", "raffredda %d"], ["slip", "scia +%d"],
			["rs", "togli %d Stress"], ["salv", "recupera %d dagli scarti"], ["sc", "riporta %d Calore dagli scarti al motore"], ["dr", "scatto fino a %d"], ["xs", "%d scia extra"]]:
		if i.has(k[0]):
			p.append(k[1] % i[k[0]])
	if i.get("ref", false):
		p.append("torna in cima al mazzo")
	if i.get("dp", false):
		p.append("giocabile durante la reazione")
	if i.get("acc", false):
		p.append("accelerazione")
	return "%s (n. %d): %s." % [i["n"], id, ", ".join(p)]

static func _int_keys(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[int(k)] = d[k]
	return out

func _show_tokens() -> void:
	board.clear_tokens()
	if R.weather >= 0:
		var gi := 0
		for g in track.groups:
			var tok: int = R.road.get(gi, 0)
			var k: int = g[0]
			var c: int = track.corners[k]["c"]
			var img := "res://assets/carte/strada_%d.webp" % (tok + 1)
			if Rules.ROAD[tok]["corner"]:
				board.add_token(c, img, 1.3, 1.0)
			else:
				var last: int = track.corners[g[-1]]["c"]
				board.add_token(last + 3, img, 1.3, 1.0)
			gi += 1
	for k in R.press:
		board.add_token(int(track.corners[k]["c"]), "res://assets/carte/stampa.webp", 1.4, -1.0)

func _update_status(t := "") -> void:
	if t != "":
		status_lbl.text = t

## Classifica a destra: posizione, auto, marcia, Calore nel motore, giro.
func _update_standings() -> void:
	for c in standings_box.get_children():
		c.queue_free()
	var pos := 0
	for car in R.standings():
		pos += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var p := _label("%d" % pos, 18, GOLD, F_BOLD)
		p.custom_minimum_size.x = 18
		row.add_child(p)
		row.add_child(_swatch(Rules.COLORS[car["col"]], 16))
		var nm := _label(car["name"], 18, CREAM, F_BOLD)
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		nm.clip_text = true
		nm.custom_minimum_size.x = 60
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		var info := ""
		if car["fin"]:
			info = "arrivo: %d°" % car["place"]
		elif car["kind"] == "legend":
			info = "Leggenda · %s" % R.lap_text(car)
		else:
			info = "%dª · motore %d · %s" % [car["gear"], car["engine"], R.lap_text(car)]
		var il := _label(info, 16, Color(CREAM, 0.75))
		il.autowrap_mode = TextServer.AUTOWRAP_OFF
		il.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(il)
		standings_box.add_child(row)

# ---------- ciclo di gara ----------

func _local_humans() -> Array:
	if online.is_empty():
		return R.cars.filter(func(c): return c["kind"] == "human")
	return R.cars.filter(func(c): return c["kind"] == "human" and c["i"] == online.get("seat", -1))

func _is_local_human(car: Dictionary) -> bool:
	if car["kind"] != "human" or autoplay:
		return false
	return online.is_empty() or car["i"] == online.get("seat", -1)

func _race_loop(my: int) -> void:
	while my == race_id and not R.all_finished():
		R.begin_round()
		_update_lx_box()
		_update_status("Giro di tavolo %d" % R.round)
		log_line("[color=#F0B429]— Turno %d —[/color]" % R.round)
		# 1-2: marce e carte (tutti insieme)
		var plans := await _collect_plans(my)
		if my != race_id:
			return
		for car in R.racing():
			if car["kind"] == "legend":
				continue
			var pl: Dictionary = plans.get(car["i"], {})
			if not R.apply_plan(car, pl):
				# piano non valido (non dovrebbe succedere): il computer sceglie al suo posto
				R.apply_plan(car, AI.plan(R, car))
		await _play_events(my)
		# 3-9: un'auto alla volta, dalla prima
		var order := R.start_moves()
		for car in order:
			if my != race_id:
				return
			await _car_turn(my, car)
			_update_standings()
		var arrived := R.end_round()
		for c in arrived:
			log_line("[color=#7CFF9A]%s taglia il traguardo: %d° posto![/color]" % [_car_tag(c), c["place"]])
			board.hide_car(c["i"])
		history.append({"round": R.round, "s": _cars_state(), "spun": R.cars.filter(func(c): return c.get("spun", false)).map(func(c): return c["i"])})
		_update_standings()
		if not online.is_empty():
			online["done_round"] = R.round
			if OS.get_environment("HEAT_TRACE") != "":
				printerr("TRACE ", online.get("role", ""), " r", R.round, " h", R.state_hash(), " ", R.cars.map(func(c): return [c["s"], c["lane"], c["gear"], c["engine"], c["hand"].size()]))
	if my != race_id:
		return
	_show_results()

func _collect_plans(my: int) -> Dictionary:
	var plans := {}
	if not online.is_empty():
		return await _online_plans(my)
	var humans := R.racing().filter(func(c): return _is_local_human(c))
	for car in R.racing():
		if car["kind"] == "cpu" or (car["kind"] == "human" and autoplay):
			plans[car["i"]] = AI.plan(R, car)
	for car in humans:
		if humans.size() > 1:
			await _pass_device(car, "scegliere marcia e carte")
			if my != race_id:
				return {}
		plans[car["i"]] = await _ask_plan(car)
		if my != race_id:
			return {}
	return plans

func _car_turn(my: int, car: Dictionary) -> void:
	board.highlight(car["i"])
	if board.follow:
		board.focus(board.car_world(car["i"]), 15.0)
	if car["kind"] == "legend":
		_update_status("Turno %d · %s (Leggenda)" % [R.round, car["name"]])
		R.legend_move(car)
		await _play_events(my)
		R.end_turn(car)
		await _play_events(my)
		return
	_update_status("Turno %d · %s" % [R.round, car["name"]])
	R.reveal_flip(car)
	if car["clutter"]:
		R.reveal_move(car)
		await _play_events(my)
		R.end_turn(car)
		await _play_events(my)
		return
	var turn := {}
	if not online.is_empty():
		turn = await _online_turn(my, car)
	elif _is_local_human(car):
		var humans := R.cars.filter(func(c): return c["kind"] == "human" and not c["fin"])
		if humans.size() > 1:
			await _pass_device(car, "reagire, scegliere la scia e scartare")
		turn = await _ask_turn(my, car)
	else:
		turn = await _cpu_turn(my, car)
	board.highlight(-1)

## Il computer guida: applica le scelte una alla volta (con le animazioni) e restituisce il turno.
func _cpu_turn(my: int, car: Dictionary) -> Dictionary:
	var turn := {"bv": AI.choices(R, car), "r": [], "sl": 0, "d": []}
	R.reveal_move(car, turn["bv"])
	await _play_events(my)
	for a in AI.react(R, car):
		turn["r"].append(a)
		R.do_action(car, a)
		await _play_events(my)
	for a in AI.react_late(R, car):
		turn["r"].append(a)
		R.do_action(car, a)
		await _play_events(my)
	while AI.slip(R, car) and my == race_id:
		turn["sl"] += 1
		R.slipstream(car)
		await _play_events(my)
	R.check_corners(car)
	await _play_events(my)
	var d := AI.discards(R, car)
	turn["d"] = d
	R.discard(car, d)
	R.end_turn(car)
	await _play_events(my)
	return turn

# ---------- eventi: animazioni e cronaca ----------

func _play_events(my: int) -> void:
	var evs: Array = R.events.duplicate()
	R.events.clear()
	for e in evs:
		if my != race_id:
			return
		var car: Dictionary = R.cars[e["car"]] if e.has("car") else {}
		match e["e"]:
			"move":
				if e["to"] != e["from"] or e["lane"] != e["lane0"]:
					await board.move_car(car["i"], e["from"], e["lane0"], e["to"], e["lane"])
				if e["to"] < e["want"] and e["why"] != "leggenda":
					log_line("   %s è bloccata: si ferma %d caselle prima." % [_car_tag(car), e["want"] - e["to"]])
			"reveal":
				log_line("%s: [b]%d[/b] in %dª marcia." % [_car_tag(car), e["speed"], car["gear"]])
				board.popup(car["i"], str(e["speed"]), CREAM)
			"stress":
				log_line("   Stress: esce un %d." % e["v"])
			"cool":
				log_line("   Raffredda %d Calore." % e["n"])
				board.popup(car["i"], "-%d calore" % e["n"], Color("#7CC8FF"))
			"boost":
				log_line("   Spinta: +%d." % e["v"])
				board.popup(car["i"], "+%d" % e["v"], GOLD)
			"adrenaline":
				log_line("   Adrenalina: +1.")
			"slip":
				log_line("   In scia: +%d caselle." % e["n"])
				board.popup(car["i"], "scia +%d" % e["n"], Color("#9CF0B0"))
			"corner_heat":
				log_line("   [color=#FF8A50]%s a %d: paga %d Calore.[/color]" % [track.corner_name(e["k"]).capitalize(), e["v"], e["n"]])
				board.popup(car["i"], "+%d calore" % e["n"], Color("#FF7A3D"))
			"spin":
				await board.move_car(car["i"], e["from"], e["lane0"], e["to"], e["lane"], true)
				log_line("   [color=#FF5050][b]TESTACODA[/b] alla %s! %d Stress in mano e si riparte in 1ª.[/color]" % [track.corner_name(e["k"]), e["stress"]])
				board.popup(car["i"], "TESTACODA!", Color("#FF4040"))
			"gravel":
				log_line("   Ghiaia: 1 Calore.")
			"discard":
				log_line("   Scarta %d carte." % e["n"])
			"shift_heat":
				log_line("%s cambia di due marce: %d Calore." % [_car_tag(car), e["n"]])
			"clutter":
				log_line("[color=#FF8A50]%s ha la mano intasata di Calore: resta ferma e torna in 1ª.[/color]" % _car_tag(car))
			"legend_card":
				if e.get("lx", false):
					var deck: String = Rules.LX_CARDS[e["card"]]["d"]
					var t := "   [color=#C9B6FF]Carta Leggenda (mazzo %s)" % deck
					if int(e.get("pu", -1)) >= 0:
						var pu: Dictionary = Rules.POWER_UPS[e["pu"]]
						t += " · Power Up: stella [b]%s[/b], Rivali [b]%s[/b]" % [Rules.ABILITY_NAMES[pu["s"]], Rules.ABILITY_NAMES[pu["r"]]]
					log_line(t + ".[/color]")
				else:
					log_line("   [color=#C9B6FF]Carta Leggenda n. %d.[/color]" % (e["card"] + 1))
				_update_lx_box()
			"legend":
				var tags: Array = []
				if e.get("star", false):
					tags.append("★")
				if e.get("rival", false):
					tags.append("Rivale")
				var tg := (" [color=#C9B6FF]%s[/color]" % " ".join(tags)) if not tags.is_empty() else ""
				if e["past"]:
					log_line("%s (Leggenda)%s affronta la curva." % [_car_tag(car), tg])
				else:
					log_line("%s (Leggenda)%s corre fino a %d caselle." % [_car_tag(car), tg, e["top"]])
			"lx_ab":
				var nm: String = Rules.ABILITY_NAMES[e["a"]]
				if e["a"] == "plus":
					log_line("   [color=#C9B6FF]Abilità non applicabile: +%d.[/color]" % e["n"])
				elif e["a"] == "draft":
					log_line("   [color=#C9B6FF]Scatto: +%d.[/color]" % e["n"])
				else:
					log_line("   [color=#C9B6FF]%s.[/color]" % nm)
				board.popup(car["i"], nm if e["a"] != "draft" else "scatto +%d" % e["n"], Color("#C9B6FF"))
			"cross":
				pass
			"upg_heat":
				log_line("   %s: paga %d Calore." % [Rules.UPG[e["id"]]["n"], e["n"]])
			"upg_void":
				log_line("   [color=#FF8A50]%s: non c'è Calore per usarla, si gira una carta dal mazzo.[/color]" % Rules.UPG[e["id"]]["n"])
			"scrap":
				log_line("   Scarta %d carte dal mazzo." % e["n"])
			"rstress":
				log_line("   Si libera di %d Stress." % e["n"])
			"salvage":
				log_line("   Recupera %d carte dagli scarti." % e["n"])
			"direct":
				log_line("   Gioca subito %s." % Rules.UPG[e["id"]]["n"])
			"accel":
				log_line("   Accelerazione: +%d." % e["n"])
				board.popup(car["i"], "+%d" % e["n"], GOLD)
			"draft_move":
				log_line("   Scatto: +%d caselle." % e["n"])
			"refresh":
				log_line("   Rimette %d carta/e in cima al mazzo." % e["n"])
			"sponsor":
				log_line("   [color=#E8C170]Nuovo sponsor: %s.[/color]" % Rules.UPG[e["id"]]["n"])
				board.popup(car["i"], "sponsor!", Color("#E8C170"))
			"sponsor_used":
				log_line("   Sponsor %s usato (esce dal gioco)." % Rules.UPG[e["id"]]["n"])
			"press":
				log_line("   [color=#E8C170]La stampa è alla curva %d![/color]" % (e["k"] + 1))
			"out":
				log_line("[color=#FF5050]%s è eliminata dalla corsa.[/color]" % _car_tag(car))
				board.hide_car(car["i"])
			"heat_removed":
				log_line("   Un Calore esce dal gioco.")
			"draft":
				log_line("%s monta [b]%s[/b] (n. %d)." % [_car_tag(car), Rules.UPG[e["id"]]["n"], e["id"]])
	_update_standings()

# ---------- scelte del giocatore: marcia e carte ----------

func _narrow() -> bool:
	return get_viewport().get_visible_rect().size.x < 900

## Larghezza delle carte quando la mano occupa tutta la riga (schermo stretto).
func _card_w_full() -> float:
	return clampf((get_viewport().get_visible_rect().size.x - 40.0) / 7.4, 34.0, 90.0)

func _card_w(extra := 520.0) -> float:
	var vs := get_viewport().get_visible_rect().size
	var dw := vs.x - (PANEL_W if vs.x >= 900 else 0.0)
	return clampf((dw - extra) / 7.4, 56.0, 110.0)

func _card_tex(car: Dictionary, c: Dictionary) -> Texture2D:
	var key: String = Rules.COLOR_KEYS[car["col"]]
	match c["t"]:
		"s", "u":
			return load("res://assets/carte/%s_%d.webp" % [key, int(c["v"])])
		"g":
			return load("res://assets/carte/upg_%d.webp" % int(c["id"]))
		"h":
			if c.has("id"):
				return load("res://assets/carte/upg_%d.webp" % int(c["id"]))
			return load("res://assets/carte/%s_calore_extra.webp" % key) if c.get("u", false) else load("res://assets/carte/calore.webp")
		"x":
			return load("res://assets/carte/stress.webp")
	return load("res://assets/carte/retro.webp")

func _card_view(car: Dictionary, c: Dictionary, w: float, selected := false, dim := false) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(w, w * CARD_RATIO + 12)
	var tr := TextureRect.new()
	tr.texture = _card_tex(car, c)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = Vector2(w, w * CARD_RATIO)
	tr.position = Vector2(0, 0 if selected else 12)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dim:
		tr.modulate = Color(1, 1, 1, 0.45)
	box.add_child(tr)
	if selected:
		var fr := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = GOLD
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(6)
		fr.add_theme_stylebox_override("panel", sb)
		fr.size = tr.size
		fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(fr)
	return box

func _dash_header(car: Dictionary, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(_swatch(Rules.COLORS[car["col"]], 24))
	var t := _title(car["name"], 26, CREAM)
	h.add_child(t)
	var narrow := _narrow()
	var l := _label(text, 17 if narrow else 20, GOLD, F_BOLD)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if narrow:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.clip_text = true
		t.add_theme_font_size_override("font_size", 22)
	h.add_child(l)
	var info := _label(("%d Calore · mazzo %d · scarti %d" if narrow else "Motore: %d Calore · mazzo %d · scarti %d") % [car["engine"], car["deck"].size(), car["discard"].size()], 14 if narrow else 18, Color(CREAM, 0.75))
	info.autowrap_mode = TextServer.AUTOWRAP_OFF
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(info)
	return h

## Descrizione dell'esito di una velocità: arrivo, curve, Calore.
func _outcome_text(car: Dictionary, s0: int, v: int, avail: int, at := -999999, lim := 0) -> Dictionary:
	var pos := s0 + v if at == -999999 else at
	var cost := R.corner_cost(car, s0, pos, v, lim)
	var lines := track.crossed(s0, pos).filter(func(x): return x["b"] <= track.finish_s())
	var t := ""
	var warn := 0
	if lines.is_empty():
		t = "nessuna curva"
	else:
		var names: Array = []
		for x in lines:
			names.append("limite %d" % (R.car_limit(car, x["k"]) + lim))
		t = "curve: " + ", ".join(names)
		if cost > avail:
			t += " → [color=#FF5050][b]TESTACODA[/b] (servono %d Calore, ne hai %d)[/color]" % [cost, avail]
			warn = 2
		elif cost > 0:
			t += " → [color=#FFB050]%d Calore[/color]" % cost
			warn = 1
		else:
			t += " → [color=#7CFF9A]nessun Calore[/color]"
	return {"t": t, "warn": warn, "pos": pos}

func _ask_plan(car: Dictionary) -> Dictionary:
	var my := race_id
	_show_dash(true)
	var st := {"g": int(car["gear"]), "sel": [], "done": false}
	var rf := {}   # contenitore: le funzioni anonime catturano le variabili locali per valore
	rf["f"] = func():
		if st["done"] or my != race_id:
			return
		st["sel"] = st["sel"].filter(func(x): return x < car["hand"].size())
		_clear_dash()
		var narrow := _narrow()
		dash_v.add_child(_dash_header(car, "Turno %d · scegli marcia e carte" % R.round))
		# schermo stretto: marce, mano e tasti uno sotto l'altro
		var row: BoxContainer = VBoxContainer.new() if narrow else HBoxContainer.new()
		row.add_theme_constant_override("separation", 8 if narrow else 14)
		# leva del cambio
		var gears := VBoxContainer.new()
		gears.add_theme_constant_override("separation", 4)
		var gl := _label("MARCIA", 15, Color(CREAM, 0.6), F_BOLD)
		if not narrow:
			gears.add_child(gl)
		var gg := GridContainer.new()
		gg.columns = 4 if narrow else 2
		gg.add_theme_constant_override("h_separation", 4)
		gg.add_theme_constant_override("v_separation", 4)
		for g in [1, 2, 3, 4]:
			var cost := R.shift_cost(car, g)
			var b := Button.new()
			b.toggle_mode = true
			b.focus_mode = Control.FOCUS_NONE
			b.text = "%dª" % g + ((("  %d Calore" if narrow else "\n%d Calore") % cost) if cost > 0 and cost < 99 else "")
			b.custom_minimum_size = Vector2(96, 40) if narrow else Vector2(70, 62)
			b.add_theme_font_override("font", F_TITLE)
			b.add_theme_font_size_override("font_size", 22 if cost == 0 else 18)
			b.button_pressed = g == st["g"]
			b.disabled = cost == 99 or cost > car["engine"]
			_btn_styles(b, GOLD, Color(1, 1, 1, 0.1), 8)
			b.add_theme_color_override("font_pressed_color", INK)
			b.add_theme_color_override("font_hover_pressed_color", INK)
			b.pressed.connect(func():
				st["g"] = g
				while st["sel"].size() > g:
					st["sel"].pop_back()
				rf["f"].call())
			gg.add_child(b)
		gears.add_child(gg)
		row.add_child(gears)
		# mano
		var hand := HBoxContainer.new()
		hand.add_theme_constant_override("separation", 6)
		hand.set_meta("mano", true)
		for i in car["hand"].size():
			var c: Dictionary = car["hand"][i]
			var ok := Rules.playable(c)
			var cv := _card_view(car, c, _card_w_full() if narrow else _card_w(560), st["sel"].has(i), not ok)
			if ok:
				cv.mouse_filter = Control.MOUSE_FILTER_STOP
				cv.gui_input.connect(func(ev):
					if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
						if st["sel"].has(i):
							st["sel"].erase(i)
						elif st["sel"].size() < st["g"]:
							st["sel"].append(i)
						else:
							st["sel"].pop_front()
							st["sel"].append(i)
						rf["f"].call())
			hand.add_child(cv)
		row.add_child(hand)
		# riepilogo e tasti
		var side := VBoxContainer.new()
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		side.add_theme_constant_override("separation", 6)
		var fixed := 0
		var ns := 0
		var lim := 0
		var hcost := 0
		var spread := 0
		for i in st["sel"]:
			var c: Dictionary = car["hand"][i]
			if c["t"] == "x":
				ns += 1
			elif c["t"] == "g":
				var gi := Rules.ginfo(c)
				ns += int(gi.get("plus", 0))
				lim += int(gi.get("lim", 0))
				hcost += int(gi.get("heat", 0))
				if gi.has("ch"):
					fixed += int(gi["ch"].min())
					spread += int(gi["ch"].max()) - int(gi["ch"].min())
				else:
					fixed += int(gi.get("v", 0))
			else:
				fixed += Rules.card_value(c)
		var avail: int = car["engine"] - hcost - (R.shift_cost(car, st["g"]) if R.shift_cost(car, st["g"]) < 99 else 0)
		var info := RichTextLabel.new()
		info.bbcode_enabled = true
		info.fit_content = true
		info.add_theme_font_size_override("normal_font_size", 18)
		info.add_theme_font_override("normal_font", F_BODY)
		info.add_theme_font_override("bold_font", F_BOLD)
		info.add_theme_color_override("default_color", CREAM)
		var txt := ""
		var need := mini(st["g"], R.playable_count(car))
		if st["sel"].size() < need:
			txt = "Scegli ancora %d carta/e (in %dª si giocano %d carte)." % [need - st["sel"].size(), st["g"], st["g"]]
			board.clear_ghost()
		else:
			var lo_v := fixed + ns
			var hi_v := fixed + 4 * ns + spread
			if lo_v == hi_v:
				var o := _outcome_text(car, car["s"], lo_v, avail, -999999, lim)
				txt = "Velocità [b]%d[/b]: %s" % [lo_v, o["t"]]
				board.show_ghost(o["pos"], 0, o["warn"])
			else:
				var lo := _outcome_text(car, car["s"], lo_v, avail, -999999, lim)
				var hi := _outcome_text(car, car["s"], hi_v, avail, -999999, lim)
				txt = "Velocità da [b]%d[/b] a [b]%d[/b]%s.\nCon %d: %s\nCon %d: %s" % [lo_v, hi_v, " (carte dal mazzo)" if ns > 0 else " (valore a scelta)", lo_v, lo["t"], hi_v, hi["t"]]
				board.show_ghost(hi["pos"], 0, hi["warn"])
			if hcost > 0:
				txt += "\nI potenziamenti scelti costano %d Calore." % hcost
			if lim != 0:
				txt += "\nLimiti delle curve %+d per te in questo turno." % lim
		var cool := 3 if st["g"] == 1 else (1 if st["g"] == 2 else 0)
		if cool > 0 and R.heat_in_hand(car) > 0:
			txt += "\nIn %dª raffreddi fino a %d Calore." % [st["g"], cool]
		if R.flooded(car):
			txt += "\n[color=#8FD3FF]Sei su un tratto allagato: scalare costa 1 Calore in più.[/color]"
		info.text = txt
		side.add_child(info)
		var br := HBoxContainer.new()
		br.add_theme_constant_override("separation", 6)
		var hint := _small_button("Consiglio")
		hint.pressed.connect(func():
			var p := AI.plan(R, car)
			st["g"] = p["g"]
			st["sel"] = p["c"].duplicate()
			rf["f"].call())
		br.add_child(hint)
		var ok_b := _big_button("Via così", RED, CREAM, 22)
		ok_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ok_b.disabled = st["sel"].size() < need
		ok_b.pressed.connect(func():
			var chk := R.check_plan(car, st["g"], st["sel"])
			if not chk["ok"]:
				_msg(chk["msg"])
				return
			st["done"] = true
			decided.emit({"g": st["g"], "c": st["sel"].duplicate()}))
		br.add_child(ok_b)
		side.add_child(br)
		row.add_child(side)
		dash_v.add_child(row)
		_layout.call_deferred()
	rf["f"].call()
	if board.follow:
		board.focus(board.car_world(car["i"]), 15.0)
	board.highlight(car["i"])
	var plan = await decided
	board.clear_ghost()
	board.highlight(-1)
	if my == race_id:
		_show_dash(false)
	return plan

## Schermata per passare il dispositivo al giocatore successivo (le mani restano nascoste).
func _pass_device(car: Dictionary, what: String) -> void:
	var ov := PanelContainer.new()
	ov.add_theme_stylebox_override("panel", _style(Color(0.04, 0.04, 0.05, 0.97), 0, 30))
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	ov.add_child(v)
	var sw := _swatch(Rules.COLORS[car["col"]], 60)
	sw.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(sw)
	var t := _title("Tocca a %s" % car["name"], 44, CREAM)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := _label("Passa il dispositivo: è il momento di %s." % what, 22, Color(CREAM, 0.8))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var b := _big_button("Sono pronto", RED)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size.x = 260
	v.add_child(b)
	root.add_child(ov)
	await b.pressed
	ov.queue_free()

# ---------- scelte del giocatore: reazioni, scia, scarti ----------

func _ask_turn(my: int, car: Dictionary) -> Dictionary:
	var turn := {"bv": [], "r": [], "sl": 0, "d": []}
	_show_dash(true)
	# freni: si sceglie il valore dopo aver visto le carte girate
	var pend := R.pending_choices(car)
	if not pend.is_empty():
		var vals: Array = []
		for k in pend.size():
			var c: Dictionary = pend[k]
			_clear_dash()
			dash_v.add_child(_dash_header(car, "Freni: scegli il valore"))
			var hb: BoxContainer = VBoxContainer.new() if _narrow() else HBoxContainer.new()
			hb.add_theme_constant_override("separation", 14)
			hb.add_child(_played_row(car))
			var rv := VBoxContainer.new()
			rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var base := R.speed(car) - Rules.card_value(c)
			for x in vals:
				base += int(x)
			var t := "Le carte girate valgono [b]%d[/b]%s. Scegli il valore di %s:" % [base, (" (con " + str(car["flips"]) + " dal mazzo)") if not car.get("flips", []).is_empty() else "", Rules.UPG[c["id"]]["n"]]
			rv.add_child(_rich(t))
			var br := HBoxContainer.new()
			br.add_theme_constant_override("separation", 8)
			for v in Rules.ginfo(c)["ch"]:
				var o := _outcome_text(car, car["s"], base + int(v), car["engine"])
				var bv := _small_button("%d → velocità %d" % [v, base + int(v)], Color("#3A5A8C") if o["warn"] == 0 else (Color("#B5651D") if o["warn"] == 1 else Color("#8C2A2A")))
				bv.tooltip_text = o["t"]
				bv.pressed.connect(func(): decided.emit(int(v)))
				br.add_child(bv)
			rv.add_child(br)
			hb.add_child(rv)
			dash_v.add_child(hb)
			var chosen = await decided
			if my != race_id:
				return turn
			vals.append(int(chosen))
		turn["bv"] = vals
	R.reveal_move(car, turn["bv"])
	await _play_events(my)
	if my != race_id:
		return turn
	# reazione: adrenalina, spinta, gioco diretto, accelerazione, scatto
	while my == race_id:
		var can_a := R.can_adrenaline(car)
		var can_b := R.can_boost(car)
		var dps := R.direct_cards(car)
		var can_c := R.can_accelerate(car)
		var dr := R.draft_amount(car)
		if not can_a and not can_b and dps.is_empty() and not can_c and dr <= 0:
			break
		_clear_dash()
		dash_v.add_child(_dash_header(car, "Reazione"))
		var v := R.speed(car)
		var o := _outcome_text(car, car["s0"], v, car["engine"], car["s"])
		var txt := "Velocità [b]%d[/b], %s." % [v, o["t"]]
		if can_b:
			txt += "\nSpinta: paghi 1 Calore e giri carte fino a un valore da 1 a 4."
		if can_a:
			txt += "\nSei tra gli ultimi: [b]adrenalina[/b], +1 casella e +1 velocità (il raffreddamento in più è già applicato)."
		if can_c:
			txt += "\nAccelerazione: +%d (uno per simbolo usato), conta per le curve." % int(car["sym"])
		if dr > 0:
			txt += "\nScatto: %d caselle libere fino a dietro l'auto davanti (non è velocità)." % dr
		var hb: BoxContainer = VBoxContainer.new() if _narrow() else HBoxContainer.new()
		hb.add_theme_constant_override("separation", 14)
		hb.add_child(_played_row(car))
		var rv := VBoxContainer.new()
		rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rv.add_child(_rich(txt))
		hb.add_child(rv)
		dash_v.add_child(hb)
		var br := HBoxContainer.new()
		br.add_theme_constant_override("separation", 8)
		if can_a:
			var ba := _small_button("Adrenalina +1", Color("#2E7D4F"))
			ba.pressed.connect(func(): decided.emit("a"))
			br.add_child(ba)
		if can_b:
			var free := R.sector_fx(car).has("free")
			var bb := _small_button("Spinta (%s)" % ("gratis" if free else "1 Calore"), Color("#B5651D"))
			bb.pressed.connect(func(): decided.emit("b"))
			br.add_child(bb)
		for k in dps:
			var c: Dictionary = car["hand"][k]
			var bd := _small_button("Gioca %s (%d)" % [Rules.UPG[c["id"]]["n"], int(c["v"])], Color("#6A3F8C"))
			bd.pressed.connect(func(): decided.emit("p%d" % k))
			br.add_child(bd)
		if can_c:
			var bc := _small_button("Accelera +%d" % int(car["sym"]), Color("#8C6A1F"))
			bc.pressed.connect(func(): decided.emit("c"))
			br.add_child(bc)
		if dr > 0:
			var bf := _small_button("Scatto +%d" % dr, Color("#1F6A8C"))
			bf.pressed.connect(func(): decided.emit("f"))
			br.add_child(bf)
		var bn := _big_button("Avanti", RED, CREAM, 20)
		bn.custom_minimum_size.x = 160
		bn.pressed.connect(func(): decided.emit("next"))
		br.add_child(bn)
		rv.add_child(br)
		var a = await decided
		if a == null or a == "next":
			break
		turn["r"].append(a)
		R.do_action(car, a)
		await _play_events(my)
	if my != race_id:
		return turn
	# scia (anche più di una con le carte "scia extra")
	while my == race_id:
		var amt := R.slip_amount(car)
		if amt <= 0:
			break
		_clear_dash()
		dash_v.add_child(_dash_header(car, "Scia"))
		var v := R.speed(car)
		var now := R.corner_cost(car, car["s0"], car["s"], v)
		var after := R.corner_cost(car, car["s0"], car["s"] + amt, v)
		var t := "Sei vicina a un'altra auto: puoi andare in scia di [b]%d[/b] caselle (non conta come velocità)." % amt
		if after > now:
			t += "\n[color=#FFB050]Attenzione: entreresti in una curva a velocità %d, costo %d Calore (ne hai %d).[/color]" % [v, after, car["engine"]]
		dash_v.add_child(_rich(t))
		board.show_ghost(car["s"] + amt, 0, 0 if after <= now else (1 if after <= car["engine"] else 2))
		var br2 := HBoxContainer.new()
		br2.add_theme_constant_override("separation", 8)
		var by := _big_button("In scia!", Color("#2E7D4F"), CREAM, 20)
		by.pressed.connect(func(): decided.emit(true))
		br2.add_child(by)
		var bno := _small_button("No")
		bno.custom_minimum_size.x = 120
		bno.pressed.connect(func(): decided.emit(false))
		br2.add_child(bno)
		dash_v.add_child(br2)
		var yes = await decided
		board.clear_ghost()
		if not yes:
			break
		turn["sl"] += 1
		R.slipstream(car)
		await _play_events(my)
	if my != race_id:
		return turn
	R.check_corners(car)
	await _play_events(my)
	# scarti
	var can_d: bool = R.can_discard(car) and car["hand"].any(func(c): return R.can_throw(c))
	if can_d:
		var sel: Array = []
		var rf := {}   # contenitore: le funzioni anonime catturano le variabili locali per valore
		rf["f"] = func():
			_clear_dash()
			dash_v.add_child(_dash_header(car, "Scarti"))
			dash_v.add_child(_rich("Puoi scartare le carte che non vuoi tenere%s. Poi peschi fino a %d." % [" (al massimo una)" if R.max_discard() == 1 else "", R.hand_n]))
			var hand := HBoxContainer.new()
			hand.add_theme_constant_override("separation", 6)
			for i in car["hand"].size():
				var c: Dictionary = car["hand"][i]
				var ok := R.can_throw(c)
				var cv := _card_view(car, c, _card_w_full() if _narrow() else _card_w(300), sel.has(i), not ok)
				if ok:
					cv.mouse_filter = Control.MOUSE_FILTER_STOP
					cv.gui_input.connect(func(ev):
						if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
							if sel.has(i):
								sel.erase(i)
							else:
								sel.append(i)
								while sel.size() > R.max_discard():
									sel.pop_front()
							rf["f"].call())
				hand.add_child(cv)
			var bf := _big_button("Fine turno" if sel.is_empty() else "Scarta %d e fine turno" % sel.size(), RED, CREAM, 20)
			bf.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bf.pressed.connect(func(): decided.emit(sel.duplicate()))
			if _narrow():
				dash_v.add_child(hand)
				dash_v.add_child(bf)
			else:
				hand.add_child(bf)
				dash_v.add_child(hand)
			_layout.call_deferred()
		rf["f"].call()
		var d = await decided
		turn["d"] = d
		R.discard(car, d)
	elif R.in_tunnel(car):
		log_line("   In galleria: niente scarti.")
	R.end_turn(car)
	await _play_events(my)
	if my == race_id:
		_show_dash(false)
	return turn

func _rich(t: String) -> RichTextLabel:
	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.add_theme_font_size_override("normal_font_size", 19)
	info.add_theme_font_size_override("bold_font_size", 19)
	info.add_theme_font_override("normal_font", F_BODY)
	info.add_theme_font_override("bold_font", F_BOLD)
	info.add_theme_color_override("default_color", CREAM)
	info.text = t
	return info

func _played_row(car: Dictionary) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	for c in car["play"]:
		h.add_child(_card_view(car, c, 84))
	return h

# ---------- fine corsa ----------

func _cars_state() -> Array:
	return R.cars.map(func(c): return [c["s"], c["lane"], c["fin"]])

func _show_results() -> void:
	racing = false
	board.highlight(-1)
	_show_dash(false)
	var ov := PanelContainer.new()
	ov.add_theme_stylebox_override("panel", _style(Color(0.05, 0.05, 0.06, 0.95), 14, 24))
	var vs := get_viewport().get_visible_rect().size
	ov.size = Vector2(minf(720, vs.x - 30), minf(640, vs.y - 30))
	ov.position = (vs - ov.size) / 2.0
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	ov.add_child(v)
	v.add_child(_checker(14, 52))
	var t := _title("Hall of Fame · %s" % track.name, 36, GOLD)
	v.add_child(t)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 16)
	for h in ["", "Auto", "Pilota", "Calore", "Testacoda", "Spinte"]:
		grid.add_child(_cell(h, 16, Color(CREAM, 0.6), F_BOLD))
	for c in R.finished:
		grid.add_child(_title("%d°" % c["place"], 26, GOLD if c["place"] == 1 else CREAM))
		var sw := HBoxContainer.new()
		sw.add_child(_swatch(Rules.COLORS[c["col"]], 20))
		sw.add_child(_cell(c["name"], 20, CREAM, F_BOLD))
		grid.add_child(sw)
		grid.add_child(_cell({"human": "giocatore", "cpu": "computer", "legend": "Leggenda"}[c["kind"]], 18))
		grid.add_child(_cell(str(c["stats"]["heat"]) if c["kind"] != "legend" else "–", 18))
		grid.add_child(_cell(str(c["stats"]["spin"]) if c["kind"] != "legend" else "–", 18))
		grid.add_child(_cell(str(c["stats"]["boost"]) if c["kind"] != "legend" else "–", 18))
	v.add_child(grid)
	var br := HBoxContainer.new()
	br.add_theme_constant_override("separation", 10)
	if not champ.is_empty():
		ov.size = Vector2(minf(900, vs.x - 30), minf(860, vs.y - 30))
		ov.position = (vs - ov.size) / 2.0
	if not champ.is_empty():
		v.add_child(_champ_after_race())
		if champ["idx"] + 1 < champ["events"].size():
			var nx := _big_button("Prossima gara", RED)
			nx.pressed.connect(func():
				ov.queue_free()
				champ["idx"] += 1
				_start_race(_champ_race_game()))
			br.add_child(nx)
	elif online.is_empty():
		var again := _big_button("Rivincita", RED)
		again.pressed.connect(func():
			ov.queue_free()
			_start_race(_local_game()))
		br.add_child(again)
	var rp := _big_button("Rivedi la corsa", Color(1, 1, 1, 0.15))
	rp.pressed.connect(_start_replay)
	br.add_child(rp)
	var menu := _big_button("Torna ai box", Color(1, 1, 1, 0.15))
	menu.pressed.connect(func():
		ov.queue_free()
		_back_to_menu())
	br.add_child(menu)
	v.add_child(br)
	root.add_child(ov)
	results_ov = ov
	log_line("[color=#F0B429][b]Corsa finita![/b][/color] Vince %s." % _car_tag(R.finished[0]))

# ---------- replay della corsa ----------

const REPLAY_SPEEDS := [0.5, 1.0, 2.0, 4.0]

func _start_replay() -> void:
	if history.size() < 2:
		return
	if is_instance_valid(results_ov):
		results_ov.visible = false
	replay = {"k": 1, "playing": true, "speed": float(replay.get("speed", 1.0)), "token": int(replay.get("token", 0)) + 1}
	board.highlight(-1)
	board.follow = true
	follow_btn.set_pressed_no_signal(true)
	board.set_state(history[0]["s"])
	_clear_dash()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.add_child(_title("Replay", 28, GOLD))
	var info := _label("", 20, CREAM, F_BOLD)
	info.name = "ReplayInfo"
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(info)
	dash_v.add_child(h)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var play := _small_button("Pausa", Color("#6A3F8C"))
	play.pressed.connect(func():
		replay["playing"] = not replay["playing"]
		play.text = "Pausa" if replay["playing"] else "Riprendi")
	row.add_child(play)
	row.add_child(_seg(["×0,5", "×1", "×2", "×4"], REPLAY_SPEEDS.find(replay["speed"]), func(k):
		replay["speed"] = REPLAY_SPEEDS[k], 17))
	var again := _small_button("Ricomincia", Color(1, 1, 1, 0.15))
	again.pressed.connect(_start_replay)
	row.add_child(again)
	var back := _small_button("Torna alla classifica", RED)
	back.pressed.connect(_end_replay)
	row.add_child(back)
	dash_v.add_child(row)
	var bar := HSlider.new()
	bar.name = "ReplayBar"
	bar.min_value = 0
	bar.max_value = history.size() - 1
	bar.step = 1
	bar.custom_minimum_size.x = 400
	bar.drag_ended.connect(func(_c):
		replay["k"] = maxi(1, int(bar.value))
		board.set_state(history[replay["k"] - 1]["s"]))
	dash_v.add_child(bar)
	_show_dash(true)
	_run_replay(replay["token"])

func _end_replay() -> void:
	replay["token"] = int(replay.get("token", 0)) + 1
	board.set_state(history[-1]["s"])
	_show_dash(false)
	if is_instance_valid(results_ov):
		results_ov.visible = true

func _run_replay(token: int) -> void:
	var total: int = history[-1]["round"]
	while replay["token"] == token:
		var info := dash_v.find_child("ReplayInfo", true, false) as Label
		var bar := dash_v.find_child("ReplayBar", true, false) as HSlider
		if replay["k"] >= history.size():
			if info:
				info.text = "Replay concluso · %d turni" % total
			await get_tree().process_frame
			continue
		if not replay["playing"]:
			await get_tree().process_frame
			continue
		var a: Dictionary = history[replay["k"] - 1]
		var b: Dictionary = history[replay["k"]]
		if info:
			info.text = "Turno %d di %d" % [b["round"], total]
		if bar:
			bar.set_value_no_signal(replay["k"])
		_update_status("Replay · turno %d" % b["round"])
		await board.animate_state(a["s"], b["s"], 1.6 / float(replay["speed"]), b["spun"])
		if replay["token"] != token:
			return
		replay["k"] += 1

## Punti della corsa, classifica del campionato e cosa si porta alla gara successiva.
func _champ_after_race() -> Control:
	if int(champ.get("scored", -1)) != champ["idx"]:
		champ["scored"] = champ["idx"]
		var pts := {}
		for c in R.finished:
			var p: int = Rules.POINTS[c["place"] - 1] if c["place"] <= Rules.POINTS.size() else 0
			if R.ev("61-3") and c["place"] == 1:
				p += 2
			if R.ev("62-3") and c["place"] <= 3:
				p += 1
			pts[c["i"]] = p
			champ["points"][c["i"]] += p
			champ["last"][c["i"]] = c["place"]
		for c in R.out:
			champ["last"][c["i"]] = 99
		champ["carry"] = R.carry_out()
		champ["results"].append(pts)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var last: bool = champ["idx"] + 1 >= champ["events"].size()
	box.add_child(_title("Campionato %s · %s" % [SEASONS[int(champ["game"]["champ"]["season"])], "classifica finale" if last else "dopo %d gare su %d" % [champ["idx"] + 1, champ["events"].size()]], 26, CREAM))
	var order: Array = range(R.cars.size())
	order.sort_custom(func(a, b):
		if champ["points"][a] != champ["points"][b]:
			return champ["points"][a] > champ["points"][b]
		return int(champ["last"].get(a, 99)) < int(champ["last"].get(b, 99)))
	var g := GridContainer.new()
	g.columns = 3 + champ["events"].size()
	g.add_theme_constant_override("h_separation", 14)
	g.add_child(_cell("", 15))
	g.add_child(_cell("Pilota", 15, Color(CREAM, 0.6), F_BOLD))
	for k in champ["events"].size():
		g.add_child(_cell(Track.by_key(champ["events"][k]["t"]).name.left(10), 15, Color(CREAM, 0.6), F_BOLD))
	g.add_child(_cell("Totale", 15, GOLD, F_BOLD))
	var pos := 0
	for i in order:
		pos += 1
		var c: Dictionary = R.cars[i]
		g.add_child(_title("%d°" % pos, 22, GOLD if pos == 1 else CREAM))
		var sw := HBoxContainer.new()
		sw.add_child(_swatch(Rules.COLORS[c["col"]], 18))
		sw.add_child(_cell(c["name"], 18, CREAM, F_BOLD))
		g.add_child(sw)
		for k in champ["events"].size():
			var txt := "·"
			if k < champ["results"].size():
				txt = str(champ["results"][k].get(i, 0))
			g.add_child(_cell(txt, 18))
		g.add_child(_cell(str(champ["points"][i]), 20, GOLD, F_BOLD))
	box.add_child(g)
	if last:
		box.add_child(_title("Campione del mondo: %s!" % R.cars[order[0]]["name"], 30, GOLD))
	else:
		var e: Dictionary = champ["events"][champ["idx"] + 1]
		box.add_child(_label("Prossima gara: %s – %s. %s" % [Track.by_key(e["t"]).name, e["name"], e["txt"]], 17, Color(CREAM, 0.8)))
	return box

func _ask_menu() -> void:
	var d := ConfirmationDialog.new()
	d.title = "Menu"
	d.dialog_text = "Abbandonare la corsa e tornare ai box?"
	d.ok_button_text = "Sì, ai box"
	d.cancel_button_text = "Continua a correre"
	root.add_child(d)
	d.popup_centered(Vector2i(460, 150))
	d.confirmed.connect(func():
		d.queue_free()
		_back_to_menu())
	d.canceled.connect(d.queue_free)

func _back_to_menu() -> void:
	race_id += 1
	replay["token"] = int(replay.get("token", 0)) + 1
	racing = false
	Engine.time_scale = 1.0
	if not online.is_empty() and net:
		net.remember_room("")
	online = {}
	champ = {}
	decided.emit(null)
	panel.visible = false
	dash.visible = false
	setup_box.visible = true
	board.clear_cars()
	board.clear_ghost()
	board.highlight(-1)
	_fill_setup()
	_preview_track()
	_layout()

# ---------- gioco online ----------

func _build_online_box(v: VBoxContainer) -> void:
	var was_visible := online_box != null and online_box.visible
	online_box = VBoxContainer.new()
	online_box.add_theme_constant_override("separation", 6)
	online_box.visible = was_visible
	v.add_child(online_box)
	online_name = LineEdit.new()
	online_name.placeholder_text = "Il tuo nome"
	online_name.max_length = 16
	online_box.add_child(_row("Nome", online_name))
	online_code = LineEdit.new()
	online_code.placeholder_text = "Codice di 4 lettere"
	online_code.max_length = 4
	var jr := HBoxContainer.new()
	jr.add_theme_constant_override("separation", 6)
	online_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jr.add_child(online_code)
	var bj := _small_button("Entra", Color("#2E7D4F"))
	bj.pressed.connect(_online_join)
	jr.add_child(bj)
	var bc := _small_button("Crea una stanza", Color("#B5651D"))
	bc.pressed.connect(_online_create)
	jr.add_child(bc)
	online_box.add_child(_row("Stanza", jr))
	online_lbl = _label("Chi crea la stanza sceglie auto e pista: le auto su «Giocatore» diventano i posti per gli amici (la prima è la sua).", 17, Color(CREAM, 0.8))
	online_box.add_child(online_lbl)
	var saved := _net().load_session()
	online_name.text = str(saved.get("name", ""))
	if str(saved.get("room", "")) != "":
		online_code.text = str(saved["room"])

func _net() -> Net:
	if net == null:
		net = Net.new()
		add_child(net)
	return net

func _player_name() -> String:
	var n := online_name.text.strip_edges()
	return n if n != "" else "Pilota"

func _seat_names(room: Dictionary) -> Dictionary:
	var out := {}
	var seats := Net._as_dict(room.get("seats", {}))
	for k in seats:
		out[int(k)] = str(seats[k].get("name", "?"))
	return out

func _online_seats_text(room: Dictionary) -> String:
	var names := _seat_names(room)
	var parts: Array = []
	for idx in room.get("open", []):
		var i := int(idx)
		parts.append("%s: %s" % [Rules.COLOR_NAMES[i], names.get(i, "posto libero")])
	return ", ".join(parts)

func _net_hint() -> String:
	var e := net.last_error
	if e == "":
		return "Motivo sconosciuto."
	var tip := ""
	if "ADMIN_ONLY_OPERATION" in e or "OPERATION_NOT_ALLOWED" in e:
		tip = "In Firebase: Authentication > Metodo di accesso > attiva «Anonimo»."
	elif "Permission denied" in e:
		tip = "In Firebase: Realtime Database > Regole: aggiungi la sezione «heat» di firebase/database.rules.json e pubblica."
	else:
		tip = "Controlla la connessione."
	return "Dettaglio: %s\n%s" % [e, tip]

func _online_create() -> void:
	var seats: Array = []
	for i in cfg["n"]:
		if cfg["kind"][i] == 0:
			seats.append(i)
	if seats.size() < 2:
		_msg("Per giocare online servono almeno due auto su «Giocatore»: una è la tua, le altre sono i posti per gli amici.")
		return
	online_lbl.text = "Creo la stanza…"
	var code := await _net().create_room(_player_name(), seats)
	if code == "":
		online_lbl.text = "Non riesco a creare la stanza.\n%s" % _net_hint()
		return
	online = {"role": "host", "code": code, "seat": seats[0], "open": seats}
	net.remember_room(code, seats[0])
	net._save({"name": _player_name()})
	_online_lobby_poll(code)

func _online_lobby_poll(code: String) -> void:
	while online.get("code", "") == code and setup_box.visible:
		var room := await net.room(code)
		if online.get("code", "") != code:
			return
		if room.is_empty():
			online_lbl.text = "La stanza %s non esiste più." % code
			online = {}
			return
		if online["role"] == "host":
			online_lbl.text = "Stanza [ %s ]: dai il codice agli amici.\nPosti: %s.\nQuando ci siete tutti premi «Semaforo verde!» (i posti liberi li guida il computer)." % [code, _online_seats_text(room)]
		else:
			if room.get("status", "") == "playing" and room.has("game"):
				_online_begin(room["game"], _seat_names(room))
				return
			online_lbl.text = "Sei nella stanza [ %s ] con l'auto %s.\nPosti: %s.\nAspetta il via di chi l'ha creata." % [code, Rules.COLOR_NAMES[online["seat"]], _online_seats_text(room)]
		await get_tree().create_timer(1.5).timeout

func _online_join() -> void:
	var code := online_code.text.strip_edges().to_upper()
	if code.length() != 4:
		_msg("Il codice della stanza ha 4 lettere.")
		return
	online_lbl.text = "Entro nella stanza %s…" % code
	var seat := await _net().join_room(code, _player_name())
	if seat == -2:
		online_lbl.text = "Stanza %s non trovata, oppure la corsa è già partita.\n%s" % [code, _net_hint() if net.last_error != "" else ""]
		return
	if seat == -1:
		online_lbl.text = "Nella stanza %s non ci sono posti liberi." % code
		return
	var room: Dictionary = net.last_room
	online = {"role": "host" if room.get("host", "") == net.uid else "guest", "code": code, "seat": seat}
	net.remember_room(code, seat)
	net._save({"name": _player_name()})
	if room.get("status", "") == "playing" and room.has("game"):
		online["catchup"] = true
		net.set_away(code, seat, false)
		Engine.time_scale = CATCHUP_SPEED
		_online_begin(room["game"], _seat_names(room))
		return
	_online_lobby_poll(code)

func _online_start() -> void:
	var code: String = online["code"]
	var room := await net.room(code)
	var names := _seat_names(room)
	var game := _local_game()
	if cfg["mode"] == 1:
		game["champ"] = {"season": cfg["season"], "pool": cfg["pool"]}
	var humans := 0
	for i in game["cars"].size():
		var c: Dictionary = game["cars"][i]
		if c["kind"] == "human":
			if names.has(i):
				c["name"] = names[i]
				humans += 1
			else:
				c["kind"] = "cpu"     # posto rimasto libero: lo guida il computer
	if humans < 2:
		_msg("Non è ancora entrato nessuno: aspetta gli amici, oppure gioca su questo dispositivo.")
		return
	if not await net.start_room(code, game):
		_msg("Non riesco ad avviare la stanza (%s)." % net.last_error)
		return
	_online_begin(game, names)

func _online_begin(game: Dictionary, names: Dictionary) -> void:
	online["game"] = game
	online["names"] = names
	if str(game.get("version", VERSION)) != VERSION:
		_msg("Attenzione: la stanza è stata creata con la versione %s, tu hai la %s. Ricarica la pagina per allinearti." % [game.get("version", "?"), VERSION])
	if game.has("champ"):
		_start_champ(game)
	else:
		_start_race(game)

## Numero del turno sul database: diverso per ogni corsa del campionato.
func _rk() -> int:
	return int(online.get("race_idx", 0)) * 1000 + R.round

func _seat_label(car: Dictionary) -> String:
	if car["i"] == online.get("seat", -1):
		return "tu"
	return car["name"]

## Marce e carte online: ognuno pubblica le sue, l'host anche quelle del computer; poi si applicano tutte.
func _online_plans(my: int) -> Dictionary:
	var code: String = online["code"]
	var h0 := R.state_hash()
	var needed := R.racing().filter(func(c): return c["kind"] != "legend")
	var got := await net.choices(code, "plans", _rk())
	if my != race_id:
		return {}
	if got.size() >= needed.size():
		Engine.time_scale = CATCHUP_SPEED if online.get("catchup", false) else 1.0
	else:
		if online.get("catchup", false):
			online["catchup"] = false
			Engine.time_scale = 1.0
	# la mia auto
	for car in needed:
		if car["i"] == online.get("seat", -1) and not got.has(str(car["i"])) and car["kind"] == "human":
			var p: Dictionary = AI.plan(R, car) if autoplay else await _ask_plan(car)
			if my != race_id:
				return {}
			p["h"] = h0
			await _post_retry(my, "plans", car["i"], p)
	# il computer (lo guida l'host)
	if online["role"] == "host":
		for car in needed:
			if car["kind"] == "cpu" and not got.has(str(car["i"])):
				var p := AI.plan(R, car)
				p["h"] = h0
				await _post_retry(my, "plans", car["i"], p)
	var since := Time.get_ticks_msec()
	while my == race_id:
		got = await net.choices(code, "plans", _rk())
		if my != race_id:
			return {}
		var missing := needed.filter(func(c): return not got.has(str(c["i"])))
		if missing.is_empty():
			var out := {}
			for car in needed:
				var p: Dictionary = got[str(car["i"])]
				if int(p.get("h", h0)) != h0:
					log_line("[color=#FF9F40]Attenzione: la corsa di %s non coincide più con la tua (versioni diverse?).[/color]" % car["name"])
				var cc: Array = []
				for x in p.get("c", []):
					cc.append(int(x))
				out[car["i"]] = {"g": int(p.get("g", car["gear"])), "c": cc}
			return out
		_update_status("Turno %d: aspetto %s" % [R.round, ", ".join(missing.map(func(c): return c["name"]))])
		if online["role"] == "host" and Time.get_ticks_msec() - since > AWAY_MS:
			for car in missing:
				log_line("[color=#FF9F40]%s non risponde: per questo turno guida il computer.[/color]" % car["name"])
				var p := AI.plan(R, car)
				p["h"] = h0
				p["cpu"] = true
				await net.post(code, "plans", _rk(), car["i"], p)
			since = Time.get_ticks_msec()
		await get_tree().create_timer(1.0).timeout
	return {}

func _online_draft(my: int, car: Dictionary) -> int:
	var code: String = online["code"]
	var rr := 100000 + int(online.get("race_idx", 0)) * 100 + R.draft_round * 10
	var got := await net.choice(code, "plans", rr, car["i"])
	if got.is_empty():
		var mine: bool = car["i"] == online.get("seat", -1) and car["kind"] == "human"
		if mine or (online["role"] == "host" and car["kind"] == "cpu"):
			var id: int = AI.draft_pick(R, car) if (not mine or autoplay) else await _ask_draft(car)
			if my != race_id:
				return -1
			await _post_retry(my, "plans", car["i"], {"id": id}, rr)
	while my == race_id:
		got = await net.choice(code, "plans", rr, car["i"])
		if not got.is_empty():
			return int(got.get("id", -1))
		await get_tree().create_timer(0.8).timeout
	return -1

func _post_retry(my: int, kind: String, idx: int, data: Dictionary, rnd := -1) -> bool:
	var code: String = online["code"]
	if rnd < 0:
		rnd = _rk()
	while my == race_id:
		if await net.post(code, kind, rnd, idx, data):
			return true
		var again := await net.choice(code, kind, rnd, idx)
		if not again.is_empty():
			return false     # c'era già (l'ha scritta qualcun altro): vale quella
		_update_status("Connessione persa, riprovo…")
		await get_tree().create_timer(2.0).timeout
	return false

## Reazioni, scia e scarti di un'auto online: chi la guida gioca e pubblica, gli altri applicano.
func _online_turn(my: int, car: Dictionary) -> Dictionary:
	var code: String = online["code"]
	var existing := await net.choice(code, "turns", _rk(), car["i"])
	if my != race_id:
		return {}
	if not existing.is_empty():
		R.apply_turn(car, _norm_turn(existing))
		await _play_events(my)
		return existing
	var mine: bool = car["i"] == online.get("seat", -1) and car["kind"] == "human"
	var mine_cpu: bool = online["role"] == "host" and car["kind"] == "cpu"
	if mine or mine_cpu:
		var snap := R.snapshot()
		var turn: Dictionary = {}
		if mine and not autoplay:
			turn = await _ask_turn(my, car)
		else:
			turn = await _cpu_turn(my, car)
		if my != race_id:
			return {}
		if not await _post_retry(my, "turns", car["i"], turn):
			# nel frattempo l'host ha guidato al nostro posto: vale la sua scelta
			var other := await net.choice(code, "turns", _rk(), car["i"])
			R.restore(snap)
			board.place_now(car["i"], car["s"], car["lane"])
			R.apply_turn(car, _norm_turn(other))
			await _play_events(my)
			log_line("[color=#FF9F40]Eri assente: per questo turno ha guidato il computer.[/color]")
		return turn
	var since := Time.get_ticks_msec()
	while my == race_id:
		var t := await net.choice(code, "turns", _rk(), car["i"])
		if my != race_id:
			return {}
		if not t.is_empty():
			R.apply_turn(car, _norm_turn(t))
			await _play_events(my)
			return t
		_update_status("Turno %d: tocca a %s…" % [R.round, car["name"]])
		if online["role"] == "host" and car["kind"] == "human" and Time.get_ticks_msec() - since > AWAY_MS:
			log_line("[color=#FF9F40]%s non risponde: per questo turno guida il computer.[/color]" % car["name"])
			var snap := R.snapshot()
			var turn := await _cpu_turn(my, car)
			if not await net.post(code, "turns", _rk(), car["i"], turn):
				var other := await net.choice(code, "turns", _rk(), car["i"])
				R.restore(snap)
				board.place_now(car["i"], car["s"], car["lane"])
				R.apply_turn(car, _norm_turn(other))
				await _play_events(my)
			return turn
		await get_tree().create_timer(0.8).timeout
	return {}

func _norm_turn(t: Dictionary) -> Dictionary:
	var d: Array = []
	for x in t.get("d", []):
		d.append(int(x))
	var r: Array = []
	for x in t.get("r", []):
		r.append(str(x))
	return {"r": r, "sl": bool(t.get("sl", false)), "d": d}
