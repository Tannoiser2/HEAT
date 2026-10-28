## La plancia in 3D: il tabellone della pista appoggiato sul tavolo, le auto da corsa anni '60,
## la telecamera che si gira, si sposta e segue l'auto di turno.
class_name Board3D
extends Node3D

signal follow_changed(on: bool)
signal spot_clicked(s: int, lane: int)

const BOARD_W := 40.0
const TOP := 0.32            # altezza della superficie della plancia
const CAR_Y := TOP + 0.005

var track: Track
var board_root: Node3D
var cars := {}               # indice auto -> Node3D
var car_state := {}          # indice auto -> {s, lane}
var cam: Camera3D
var target := Vector3.ZERO
var desired := Vector3.ZERO
var yaw := 0.0
var pitch := 1.2
var dist := 40.0
var follow := true
var _drag := 0
var _press := Vector2.ZERO
var screen_shift := Vector2.ZERO
var view_free := Vector2.ZERO     # parte dello schermo libera per la pista (0 = calcolata da screen_shift)
var step_time := 0.12        # secondi per casella
var ring: MeshInstance3D
var ghost_nodes: Array = []
var token_nodes: Array = []
var pick_spots: Array = []   # [[s, lane], ...] cliccabili
var _anim := {}              # auto in movimento
var board_h := 26.0
var _busy := 0
var _hl := -1

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#5E86B5")
	sm.sky_horizon_color = Color("#D9CBB0")
	sm.ground_horizon_color = Color("#6B4E33")
	sm.ground_bottom_color = Color("#3A2A1C")
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.4
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -32, 0)
	sun.light_energy = 0.7
	sun.light_color = Color("#FFF1DC")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)
	# tavolo in legno
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var nt := NoiseTexture2D.new()
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	nt.noise = noise
	var grad := Gradient.new()
	grad.set_color(0, Color("#4A2F1E"))
	grad.set_color(1, Color("#7A5233"))
	nt.color_ramp = grad
	gm.albedo_texture = nt
	gm.uv1_scale = Vector3(18, 60, 1)
	gm.roughness = 0.75
	gm.texture_repeat = true
	ground.material_override = gm
	add_child(ground)
	board_root = Node3D.new()
	add_child(board_root)
	cam = Camera3D.new()
	cam.fov = 45
	cam.far = 600
	add_child(cam)
	ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.62
	tm.outer_radius = 0.72
	tm.rings = 32
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color("#FFD23F")
	rm.emission_enabled = true
	rm.emission = Color("#FFB400")
	rm.emission_energy_multiplier = 1.2
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rm
	ring.visible = false
	add_child(ring)

# ---------- plancia ----------

func show_track(t: Track) -> void:
	track = t
	for c in board_root.get_children():
		c.queue_free()
	clear_cars()
	clear_ghost()
	board_h = BOARD_W / t.aspect
	# il tabellone: un blocco scuro con la pista stampata sopra
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(BOARD_W + 0.3, TOP - 0.02, board_h + 0.3)
	box.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color("#1E1A17")
	bmat.roughness = 0.6
	box.material_override = bmat
	box.position.y = (TOP - 0.02) / 2.0
	board_root.add_child(box)
	var top := MeshInstance3D.new()
	var qm := PlaneMesh.new()
	qm.size = Vector2(BOARD_W, board_h)
	top.mesh = qm
	var tmat := StandardMaterial3D.new()
	tmat.albedo_texture = load(t.image)
	tmat.roughness = 0.9
	tmat.metallic_specular = 0.15
	tmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	top.material_override = tmat
	top.position.y = TOP
	board_root.add_child(top)
	fit_view()

func uv_to_world(uv: Vector2) -> Vector3:
	return Vector3((uv.x - 0.5) * BOARD_W, CAR_Y, (uv.y - 0.5) * board_h)

func spot_pos(s: int, lane: int) -> Vector3:
	return uv_to_world(track.spot_uv(s, lane))

func center_pos(s: int) -> Vector3:
	return uv_to_world(track.center_uv(s))

func heading(s: int) -> float:
	return -track.angle(s)

# ---------- auto ----------

func clear_cars() -> void:
	for k in cars:
		if is_instance_valid(cars[k]):
			cars[k].queue_free()
	cars.clear()
	car_state.clear()
	_anim.clear()

const CAR_MODEL := "res://assets/auto/monoposto.glb"
const CAR_LEN := 1.17            # lunghezza dell'auto sulla plancia
static var _car_scene: PackedScene
static var _car_mats := {}       # colore -> ShaderMaterial

## Ricolora la carrozzeria rossa del modello Meshy nel colore della scuderia, lasciando gomme,
## cromature e pilota come sono.
const PAINT_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D mr_tex : hint_default_white, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform bool has_mr = false;
uniform bool has_normal = false;
uniform vec4 team : source_color = vec4(1.0, 0.0, 0.0, 1.0);
vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}
void fragment() {
	vec4 a = texture(albedo_tex, UV);
	vec3 hsv = rgb2hsv(a.rgb);
	float hue_d = min(hsv.x, 1.0 - hsv.x);
	float m = smoothstep(0.09, 0.04, hue_d) * smoothstep(0.35, 0.55, hsv.z) * smoothstep(0.35, 0.6, hsv.y);
	float shade = clamp(hsv.z / 0.82, 0.0, 1.25);
	vec3 painted = team.rgb * shade;
	ALBEDO = mix(a.rgb, painted, m);
	float metal = 0.0;
	float rough = 0.6;
	if (has_mr) {
		vec4 mr = texture(mr_tex, UV);
		metal = mr.b;
		rough = mr.g;
	}
	METALLIC = mix(metal, 0.25, m);
	ROUGHNESS = mix(rough, 0.3, m);
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
}
"""

## Monoposto anni '60 (modello Meshy) nel colore dato; se il modello manca, quella a forme semplici.
static func make_car(col: Color, number: int) -> Node3D:
	if _car_scene == null and ResourceLoader.exists(CAR_MODEL):
		_car_scene = load(CAR_MODEL)
	if _car_scene != null:
		return _make_model_car(col)
	return _make_simple_car(col, number)

static func _make_model_car(col: Color) -> Node3D:
	var root := Node3D.new()
	var inst: Node3D = _car_scene.instantiate()
	root.add_child(inst)
	var key := col.to_html()
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if not _car_mats.has(key):
			var src := m.get_active_material(0) as StandardMaterial3D
			var sm := ShaderMaterial.new()
			var sh := Shader.new()
			sh.code = PAINT_SHADER
			sm.shader = sh
			if src != null:
				sm.set_shader_parameter("albedo_tex", src.albedo_texture)
				if src.metallic_texture != null:
					sm.set_shader_parameter("mr_tex", src.metallic_texture)
					sm.set_shader_parameter("has_mr", true)
				if src.normal_texture != null:
					sm.set_shader_parameter("normal_tex", src.normal_texture)
					sm.set_shader_parameter("has_normal", true)
			sm.set_shader_parameter("team", col)
			_car_mats[key] = sm
		m.material_override = _car_mats[key]
	# il modello è lungo 1,9 lungo X, centrato: lo porto a CAR_LEN, ruote sulla plancia
	var k := CAR_LEN / 1.9
	inst.scale = Vector3.ONE * k
	inst.position.y = 0.283 * k
	inst.rotation_degrees.y = CAR_YAW
	return root

const CAR_YAW := 180.0     # nel modello il muso guarda verso -X

## Auto da corsa anni '60 costruita con forme semplici: muso a siluro, ruote scoperte, pilota col casco.
static func _make_simple_car(col: Color, number: int) -> Node3D:
	var root := Node3D.new()
	var paint := StandardMaterial3D.new()
	paint.albedo_color = col
	paint.metallic = 0.35
	paint.roughness = 0.32
	paint.clearcoat_enabled = true
	paint.clearcoat = 0.6
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("#141414")
	dark.roughness = 0.8
	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color("#D8D8D8")
	chrome.metallic = 0.9
	chrome.roughness = 0.2
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("#F4F1E8")
	white.roughness = 0.5
	# corpo: profilo ruotato attorno all'asse X (lunghezza 1.3)
	var prof := [[0.66, 0.0], [0.64, 0.07], [0.58, 0.11], [0.45, 0.14], [0.25, 0.165], [0.0, 0.175], [-0.25, 0.17], [-0.45, 0.14], [-0.6, 0.09], [-0.66, 0.0]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 18
	for i in prof.size() - 1:
		for j in seg:
			var a0 := TAU * j / seg
			var a1 := TAU * (j + 1) / seg
			var p := [Vector3(prof[i][0], cos(a0) * prof[i][1] * 0.82, sin(a0) * prof[i][1]),
				Vector3(prof[i + 1][0], cos(a0) * prof[i + 1][1] * 0.82, sin(a0) * prof[i + 1][1]),
				Vector3(prof[i + 1][0], cos(a1) * prof[i + 1][1] * 0.82, sin(a1) * prof[i + 1][1]),
				Vector3(prof[i][0], cos(a1) * prof[i][1] * 0.82, sin(a1) * prof[i][1])]
			st.add_vertex(p[0])
			st.add_vertex(p[1])
			st.add_vertex(p[2])
			st.add_vertex(p[0])
			st.add_vertex(p[2])
			st.add_vertex(p[3])
	st.generate_normals()
	var body := MeshInstance3D.new()
	body.mesh = st.commit()
	body.material_override = paint
	body.position.y = 0.2
	root.add_child(body)
	# presa d'aria sul muso
	var grille := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 0.075
	gm.bottom_radius = 0.075
	gm.height = 0.02
	grille.mesh = gm
	grille.material_override = dark
	grille.rotation_degrees = Vector3(0, 0, 90)
	grille.position = Vector3(0.665, 0.2, 0)
	root.add_child(grille)
	# striscia bianca sul cofano
	var stripe := MeshInstance3D.new()
	var sbm := BoxMesh.new()
	sbm.size = Vector3(0.5, 0.01, 0.07)
	stripe.mesh = sbm
	stripe.material_override = white
	stripe.position = Vector3(0.33, 0.335, 0)
	stripe.rotation_degrees = Vector3(0, 0, -9)
	root.add_child(stripe)
	# abitacolo e pilota
	var cockpit := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.13
	cm.height = 0.12
	cockpit.mesh = cm
	cockpit.material_override = dark
	cockpit.scale = Vector3(1.4, 1, 0.85)
	cockpit.position = Vector3(-0.08, 0.34, 0)
	root.add_child(cockpit)
	var helmet := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.075
	hm.height = 0.15
	helmet.mesh = hm
	helmet.material_override = white
	helmet.position = Vector3(-0.1, 0.42, 0)
	root.add_child(helmet)
	var visor := MeshInstance3D.new()
	var vm := BoxMesh.new()
	vm.size = Vector3(0.03, 0.035, 0.1)
	visor.mesh = vm
	visor.material_override = dark
	visor.position = Vector3(-0.035, 0.43, 0)
	root.add_child(visor)
	var screen := MeshInstance3D.new()
	var scm := BoxMesh.new()
	scm.size = Vector3(0.015, 0.07, 0.18)
	screen.mesh = scm
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.75, 0.85, 0.95, 0.45)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	screen.material_override = glass
	screen.position = Vector3(0.06, 0.39, 0)
	screen.rotation_degrees = Vector3(0, 0, -25)
	root.add_child(screen)
	# roll bar
	var bar := MeshInstance3D.new()
	var barm := TorusMesh.new()
	barm.inner_radius = 0.07
	barm.outer_radius = 0.09
	bar.mesh = barm
	bar.material_override = chrome
	bar.rotation_degrees = Vector3(90, 90, 0)
	bar.scale = Vector3(1, 1, 1.2)
	bar.position = Vector3(-0.22, 0.38, 0)
	root.add_child(bar)
	# ruote scoperte
	for wx in [0.4, -0.38]:
		for wz in [-1, 1]:
			var w := MeshInstance3D.new()
			var wm := CylinderMesh.new()
			var r := 0.13 if wx > 0 else 0.15
			wm.top_radius = r
			wm.bottom_radius = r
			wm.height = 0.12 if wx > 0 else 0.15
			w.mesh = wm
			w.material_override = dark
			w.rotation_degrees = Vector3(90, 0, 0)
			w.position = Vector3(wx, r, wz * 0.25)
			root.add_child(w)
			var hub := MeshInstance3D.new()
			var hbm := CylinderMesh.new()
			hbm.top_radius = r * 0.55
			hbm.bottom_radius = r * 0.55
			hbm.height = wm.height + 0.01
			hub.mesh = hbm
			hub.material_override = chrome
			hub.rotation_degrees = Vector3(90, 0, 0)
			hub.position = w.position
			root.add_child(hub)
	# scarichi
	for z in [-0.06, 0.06]:
		var ex := MeshInstance3D.new()
		var em := CylinderMesh.new()
		em.top_radius = 0.022
		em.bottom_radius = 0.022
		em.height = 0.32
		ex.mesh = em
		ex.material_override = chrome
		ex.rotation_degrees = Vector3(0, 0, 80)
		ex.position = Vector3(-0.62, 0.2, z)
		root.add_child(ex)
	# numero di gara nel tondo bianco sui fianchi e sul muso
	for side in [-1, 1]:
		var disc := MeshInstance3D.new()
		var dm := CylinderMesh.new()
		dm.top_radius = 0.085
		dm.bottom_radius = 0.085
		dm.height = 0.01
		disc.mesh = dm
		disc.material_override = white
		disc.rotation_degrees = Vector3(90, 0, 0)
		disc.position = Vector3(0.12, 0.22, side * 0.15)
		root.add_child(disc)
		var lab := Label3D.new()
		lab.text = str(number)
		lab.font_size = 64
		lab.pixel_size = 0.0022
		lab.modulate = Color("#111111")
		lab.outline_size = 0
		lab.position = Vector3(0.12, 0.22, side * 0.157)
		lab.rotation_degrees = Vector3(0, 0 if side > 0 else 180, 0)
		root.add_child(lab)
	var topd := MeshInstance3D.new()
	var tdm := CylinderMesh.new()
	tdm.top_radius = 0.075
	tdm.bottom_radius = 0.075
	tdm.height = 0.01
	topd.mesh = tdm
	topd.material_override = white
	topd.position = Vector3(0.42, 0.325, 0)
	topd.rotation_degrees = Vector3(0, 0, -10)
	root.add_child(topd)
	var tl := Label3D.new()
	tl.text = str(number)
	tl.font_size = 64
	tl.pixel_size = 0.0019
	tl.modulate = Color("#111111")
	tl.outline_size = 0
	tl.rotation_degrees = Vector3(-90, 90, 0)
	tl.position = Vector3(0.42, 0.333, 0)
	root.add_child(tl)
	root.scale = Vector3.ONE * 0.9
	return root

func make_cars(list: Array) -> void:
	clear_cars()
	for c in list:
		var node := make_car(Rules.COLORS[c["col"]], Rules.NUMBERS[c["col"]])
		add_child(node)
		cars[c["i"]] = node
		car_state[c["i"]] = {"s": c["s"], "lane": c["lane"]}
		place_now(c["i"], c["s"], c["lane"])

func place_now(i: int, s: int, lane: int) -> void:
	var n: Node3D = cars.get(i)
	if n == null:
		return
	n.visible = true
	n.position = spot_pos(s, lane)
	n.rotation = Vector3(0, heading(s), 0)
	car_state[i] = {"s": s, "lane": lane}

# ---------- replay ----------

## Porta subito le auto in uno stato salvato: st[i] = [casella, corsia, nascosta].
func set_state(st: Array) -> void:
	for i in cars:
		var n: Node3D = cars[i]
		n.scale = Vector3.ONE
		n.visible = not st[i][2]
		if n.visible:
			n.position = spot_pos(st[i][0], st[i][1])
			n.rotation = Vector3(0, heading(st[i][0]), 0)
		car_state[i] = {"s": st[i][0], "lane": st[i][1]}

## Tutte le auto si muovono insieme da uno stato al successivo nello stesso tempo t:
## chi ha fatto più strada va più veloce. Testacoda: l'auto gira su se stessa; chi arriva sparisce.
func animate_state(a: Array, b: Array, t: float, spun: Array = []) -> void:
	var lead := -1
	for i in cars:
		var n: Node3D = cars[i]
		if a[i][2]:
			n.visible = false
			continue
		var s0: int = a[i][0]
		var s1: int = b[i][0]
		var pts: Array = []
		var angs: Array = []
		for s in range(s0 + 1, s1):
			pts.append(center_pos(s).lerp(spot_pos(s, b[i][1]), 0.35))
			angs.append(heading(s))
		if s1 != s0 or a[i][1] != b[i][1] or not b[i][2]:
			pts.append(spot_pos(s1, b[i][1]))
			angs.append(heading(s1))
		var dt := t / maxf(1.0, pts.size())
		var tw := create_tween()
		var cur := n.rotation.y
		for k in pts.size():
			var ang: float = angs[k]
			while ang - cur > PI:
				ang -= TAU
			while ang - cur < -PI:
				ang += TAU
			cur = ang
			tw.tween_property(n, "position", pts[k], dt)
			tw.parallel().tween_property(n, "rotation:y", ang, dt)
		if spun.has(i):
			tw.tween_property(n, "rotation:y", cur + TAU * 2, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if b[i][2]:
			tw.tween_property(n, "scale", Vector3.ONE * 0.01, 0.3)
			tw.tween_callback(func():
				n.visible = false
				n.scale = Vector3.ONE)
		car_state[i] = {"s": s1, "lane": b[i][1]}
		if lead < 0 or s1 > b[lead][0]:
			lead = i
	if follow and lead >= 0:
		desired = spot_pos(b[lead][0], b[lead][1])
	await get_tree().create_timer(t + (0.5 if not spun.is_empty() else 0.0)).timeout

func hide_car(i: int) -> void:
	if cars.has(i):
		cars[i].visible = false

func is_busy() -> bool:
	return _busy > 0

## Movimento animato da s0 a s1 passando per le caselle intermedie; spin = testacoda (giro su se stessa).
func move_car(i: int, s0: int, lane0: int, s1: int, lane1: int, spin := false) -> void:
	var n: Node3D = cars.get(i)
	if n == null:
		return
	_busy += 1
	var pts: Array = []
	var angs: Array = []
	if s1 > s0:
		for s in range(s0 + 1, s1):
			pts.append(center_pos(s).lerp(spot_pos(s, lane1), 0.35))
			angs.append(heading(s))
	pts.append(spot_pos(s1, lane1))
	angs.append(heading(s1))
	var steps := maxi(1, pts.size())
	var dt := step_time if not spin else 0.5 / steps
	var tw := create_tween()
	var cur_ang := n.rotation.y
	for k in pts.size():
		var a: float = angs[k]
		# rotazione più breve
		while a - cur_ang > PI:
			a -= TAU
		while a - cur_ang < -PI:
			a += TAU
		cur_ang = a
		tw.tween_property(n, "position", pts[k], dt)
		if not spin:
			tw.parallel().tween_property(n, "rotation:y", a, dt)
	if spin:
		var fin := heading(s1)
		while fin < cur_ang:
			fin += TAU
		tw.parallel().tween_property(n, "rotation:y", fin + TAU * 2, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	n.rotation.y = heading(s1)
	car_state[i] = {"s": s1, "lane": lane1}
	_busy -= 1

func car_world(i: int) -> Vector3:
	return cars[i].position if cars.has(i) else Vector3.ZERO

## Anello luminoso sotto l'auto di turno.
func highlight(i: int) -> void:
	_hl = i
	if i < 0 or not cars.has(i):
		ring.visible = false
		return
	ring.visible = true
	ring.position = cars[i].position + Vector3(0, 0.02, 0)

## Scritta che sale e svanisce sopra un'auto (calore pagato, testacoda...).
func popup(i: int, text: String, col: Color) -> void:
	if not cars.has(i):
		return
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = col
	l.outline_size = 18
	l.outline_modulate = Color(0, 0, 0, 0.85)
	var f = load("res://assets/font/RacingSansOne-Regular.ttf")
	if f:
		l.font = f
	add_child(l)
	l.position = cars[i].position + Vector3(0, 1.1, 0)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y + 1.4, 1.6)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.6).set_delay(0.6)
	tw.tween_callback(l.queue_free)

# ---------- anteprima della destinazione ----------

func clear_ghost() -> void:
	for g in ghost_nodes:
		if is_instance_valid(g):
			g.queue_free()
	ghost_nodes.clear()

## Segna la casella d'arrivo prevista (verde) e le linee di curva che si attraverserebbero (rosse se costano Calore).
func show_ghost(s: int, lane: int, warn := 0) -> void:
	clear_ghost()
	if track == null:
		return
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.42
	cm.bottom_radius = 0.42
	cm.height = 0.03
	m.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 1, 0.45, 0.55) if warn == 0 else (Color(1, 0.65, 0.1, 0.6) if warn == 1 else Color(1, 0.15, 0.1, 0.65))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.position = spot_pos(s, lane) + Vector3(0, 0.02, 0)
	add_child(m)
	ghost_nodes.append(m)

# ---------- gettoni meteo e condizioni della strada ----------

func clear_tokens() -> void:
	for t in token_nodes:
		if is_instance_valid(t):
			t.queue_free()
	token_nodes.clear()

## Gettone appoggiato accanto a una casella (lato esterno), con la sua immagine.
func add_token(s: int, img: String, size := 1.0, side := 1.0) -> void:
	var sp := Sprite3D.new()
	sp.texture = load(img)
	sp.pixel_size = size / maxf(1.0, float(sp.texture.get_width()))
	sp.rotation_degrees = Vector3(-90, 0, 0)
	var a := track.angle(s)
	var right := Vector3(-sin(a), 0, cos(a))
	sp.position = center_pos(s) + right * side * 1.9 + Vector3(0, 0.03, 0)
	sp.shaded = false
	add_child(sp)
	token_nodes.append(sp)

func add_card_standee(img: String, uv: Vector2, h := 3.0) -> void:
	var sp := Sprite3D.new()
	sp.texture = load(img)
	sp.pixel_size = h / maxf(1.0, float(sp.texture.get_height()))
	sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sp.position = uv_to_world(uv) + Vector3(0, h * 0.5, 0)
	add_child(sp)
	token_nodes.append(sp)

# ---------- telecamera ----------

func fit_view() -> void:
	if track == null:
		return
	desired = Vector3(0, 0, 0)
	target = desired
	yaw = 0.0
	pitch = 1.22
	var vs := get_viewport().get_visible_rect().size
	var aspect: float = vs.x / maxf(1.0, vs.y)
	var t := tan(deg_to_rad(cam.fov * 0.5))
	var free_x: float = maxf(0.3, 1.0 - absf(screen_shift.x))
	var free_y: float = maxf(0.3, 1.0 - absf(screen_shift.y))
	if view_free != Vector2.ZERO:
		free_x = maxf(0.1, view_free.x)
		free_y = maxf(0.1, view_free.y)
	var need_w := BOARD_W / (2.0 * t * aspect * free_x)
	var need_h := board_h / (2.0 * t * free_y * sin(pitch))
	dist = clampf(maxf(need_w, need_h) * 1.04, 6.0, 160.0)

func focus(p: Vector3, d := 13.0) -> void:
	desired = p
	dist = d
	pitch = clampf(pitch, 0.75, 1.05)

func _process(delta: float) -> void:
	target = target.lerp(desired, clampf(delta * 3.0, 0, 1))
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.position = target + off
	cam.look_at(target, Vector3.UP)
	var half := dist * tan(deg_to_rad(cam.fov * 0.5))
	var vs := get_viewport().get_visible_rect().size
	var aspect: float = vs.x / maxf(1.0, vs.y)
	cam.h_offset = half * aspect * screen_shift.x
	cam.v_offset = -half * screen_shift.y
	if ring.visible:
		ring.rotation.y += delta * 1.5
		if cars.has(_hl):
			ring.position = cars[_hl].position + Vector3(0, 0.02, 0)
			if follow:
				desired = desired.lerp(cars[_hl].position, clampf(delta * 2.0, 0, 1))

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			dist = clampf(dist * 0.9, 3.0, 140.0)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			dist = clampf(dist * 1.1, 3.0, 140.0)
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			_drag = (2 if ev.shift_pressed else 1) if ev.pressed else 0
			if ev.pressed:
				_press = ev.position
			elif not pick_spots.is_empty() and ev.position.distance_to(_press) < 8:
				_pick(ev.position)
		elif ev.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_drag = 2 if ev.pressed else 0
	elif ev is InputEventMouseMotion and _drag != 0:
		if _drag == 1:
			yaw -= ev.relative.x * 0.006
			pitch = clampf(pitch + ev.relative.y * 0.005, 0.3, 1.5)
		else:
			_pan(ev.relative)
	elif ev is InputEventMagnifyGesture:
		dist = clampf(dist / ev.factor, 3.0, 140.0)
	elif ev is InputEventPanGesture:
		_pan(-ev.delta * 8.0)

func _pan(rel: Vector2) -> void:
	if follow:
		follow = false
		follow_changed.emit(false)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var k := dist * 0.0016
	desired += (-right * rel.x + fwd * rel.y) * k
	target = desired

func _pick(screen: Vector2) -> void:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if absf(d.y) < 1e-4:
		return
	var t := (CAR_Y - o.y) / d.y
	var hit := o + d * t
	var best: Array = []
	var bd := 1e9
	for sl in pick_spots:
		var p := spot_pos(sl[0], sl[1])
		var dd := Vector2(hit.x, hit.z).distance_to(Vector2(p.x, p.z))
		if dd < bd:
			bd = dd
			best = sl
	if not best.is_empty() and bd < 1.2:
		spot_clicked.emit(best[0], best[1])
