extends Node2D
# Teeokratie - Office room, native Godot rebuild of "TeaistCloisterOffice.unity".
# Parity pass against the original Unity/Adventure Creator build:
#  - correct composition: fuller room art, Don Kamille seated LEFT behind the desk,
#    the Prüfungsordnung as a document sprite on the right wall
#  - Adventure-Creator-style interaction menu (Ansehen / Reden / Benutzen) on click
#  - subtitle-style speech near the top (outlined), not a bottom text box
#  - the scene auto-starts with Don Kamille's opening line
#  - SPACE highlights all hotspots (AC "show all usable items")
# All German text is taken from the original Unity scene.

const WORLD_SCALE := 4.0
const FLOOR_Y := 168.0
const WALK_SPEED := 95.0

var world: Node2D
var teesa: AnimatedSprite2D
var teesa_feet := Vector2(188, FLOOR_Y)
var walk_target := Vector2(188, FLOOR_Y)
var walking := false
var facing_right := false

var don: AnimatedSprite2D
const DON_FEET := Vector2(82, 150)
const DON_SCALE := 0.85

var hotspots: Array = []
var pending_action := {}          # {verb, hs} to run after walking over
var hover_name := ""

# dialogue engine
var conv: Dictionary = {}
var seg: Array = []
var seg_ip := 0
var in_dialogue := false
var awaiting_menu := false

# UI
var speech: Label
var speaker_name := ""
var menu_box: VBoxContainer          # dialogue-option menu
var verb_box: VBoxContainer          # interaction (verb) menu
var objective_label: Label
var sentence_label: Label
var highlight_layer: Control
var highlights_on := false

func _ready() -> void:
	world = Node2D.new()
	world.scale = Vector2(WORLD_SCALE, WORLD_SCALE)
	add_child(world)

	# mountain view behind the (transparent) window hole in the room art
	var outside := Sprite2D.new()
	outside.texture = load("res://assets/window_outside.png")
	outside.centered = false
	outside.position = Vector2(103, 68)
	world.add_child(outside)

	var bg := Sprite2D.new()
	bg.texture = load("res://assets/office_1.png")
	bg.centered = false
	world.add_child(bg)

	# Prüfungsordnung document on the right wall
	var doc := Sprite2D.new()
	doc.texture = load("res://assets/examregulations.png")
	doc.centered = false
	doc.position = Vector2(250, 66)
	world.add_child(doc)

	don = _make_don()
	world.add_child(don)

	teesa = _make_teesa()
	world.add_child(teesa)
	_update_teesa()

	# desk drawn on top so Don reads as seated behind it
	var desk := Sprite2D.new()
	desk.texture = load("res://assets/desk_fg.png")
	desk.centered = false
	desk.position = Vector2(48, 110)
	world.add_child(desk)

	_build_hotspots()
	_build_ui()
	_build_conversation()

	# auto-start: Don greets on entry (AC OnStart)
	_run_segment_list([
		["say", "Don Kamille", "Da sind Sie ja, Schwester Teegießertochter."],
		["say", "Don Kamille", "52 Sekunden zu spät, wie ich sehe."],
		["end"],
	])

# ---------- sprites ----------
func _teesa_frame(idx: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = load("res://assets/teesa_sheet.png")
	at.region = Rect2((idx % 6) * 40, 0, 40, 80)
	return at

func _make_teesa() -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.add_animation("walk"); frames.set_animation_speed("walk", 10.0)
	for i in range(6):
		frames.add_frame("walk", _teesa_frame(i))
	frames.add_animation("idle"); frames.add_frame("idle", _teesa_frame(0))
	var a := AnimatedSprite2D.new()
	a.sprite_frames = frames; a.centered = true; a.play("idle")
	return a

func _don_frame(col: int, row: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = load("res://assets/donkamille_sheet.png")
	at.region = Rect2(col * 69, row * 89, 69, 89)
	return at

func _make_don() -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.add_animation("idle"); frames.add_frame("idle", _don_frame(0, 0))
	frames.add_animation("talk"); frames.set_animation_speed("talk", 8.0)
	frames.add_frame("talk", _don_frame(1, 0)); frames.add_frame("talk", _don_frame(2, 0))
	frames.add_frame("talk", _don_frame(0, 1)); frames.add_frame("talk", _don_frame(1, 1))
	frames.add_frame("talk", _don_frame(2, 1))
	var a := AnimatedSprite2D.new()
	a.sprite_frames = frames; a.centered = true
	a.scale = Vector2(DON_SCALE, DON_SCALE)
	a.flip_h = true                                # face right, toward the room
	a.position = DON_FEET - Vector2(0, 89 * DON_SCALE / 2.0)
	a.play("idle")
	return a

# ---------- hotspots ----------
func _build_hotspots() -> void:
	hotspots = [
		{"name": "Fenster", "rect": Rect2(100, 56, 28, 32), "verbs": {
			"look": [["Teesa", "Es regnet Katzen und Hunde."]]}},
		{"name": "Bücherregal", "rect": Rect2(150, 54, 62, 82), "verbs": {
			"look": [["Teesa", "Die interessanten Bücher stehen alle im Vorzimmer."],
					 ["Teesa", "Ein Haufen pietistischer Plunder. Laaangweilig!"]]}},
		{"name": "Prüfungsordnung", "rect": Rect2(248, 64, 30, 40), "verbs": {
			"look": [["Teesa", "Da steht: „Zum Abschluss seiner Literertour hat der Anwärter…“"],
					 ["Teesa", "„Zur Zubereitung wird benötigt: 1. Original Teebetanische Yak-Tee(TM)-Blätter“"],
					 ["Teesa", "„2. Kristallklares, mineralstoffreiches Quellwasser“"],
					 ["Teesa", "„3. Ein Teekessel oder ein anderes Gefäß“"],
					 ["Teesa", "„4. Ein angeheizter Ofen“"]]}},
		{"name": "Durchgangsklappvorrichtung (DK)", "rect": Rect2(285, 60, 24, 80), "verbs": {
			"look": [["Teesa", "Eine Durchgangsklappvorrichtung."]],
			"use": [["Teesa", "Die führt ins Vorzimmer – aber erst, wenn die Prüfung bestanden ist."]]}},
		{"name": "Don Kamille", "rect": Rect2(52, 74, 60, 40), "verbs": {
			"look": [["Teesa", "Das ist mein Chef, Hohepriester Don Kamille."]],
			"talk": "start"}},
	]

const VERB_LABELS := {"look": "Ansehen", "talk": "Reden", "use": "Benutzen"}
const VERB_ORDER := ["look", "talk", "use"]

# ---------- conversation ----------
func _menu_options() -> Array:
	return [
		["Wie läuft die Abschlussprüfung ab?", "exam"],
		["Sagen Sie mir die Zukunft voraus?", "prophecy"],
		["Auf Wiedersehen, Hochwohlgeboren!", "bye"],
	]

func _build_conversation() -> void:
	conv = {
		"start": [
			["say", "Don Kamille", "Vorschriftsgemäß verlese ich die Teeisten-Prüfungsordnung."],
			["menu", _menu_options()],
		],
		"exam": [
			["say", "Don Kamille", "„Zur Zubereitung wird benötigt: 1. Original Teebetanische Yak-Tee(TM)-Blätter“"],
			["say", "Don Kamille", "„2. Kristallklares, mineralstoffreiches Quellwasser“"],
			["say", "Don Kamille", "„3. Ein Teekessel oder ein anderes Gefäß“"],
			["say", "Don Kamille", "„4. Ein angeheizter Ofen“. Gelobt sei Teeseus in Ewigkeit, Teemen."],
			["say", "Teesa", "Sehr wohl, Hohepriester!"],
			["objective", "Ziel: Bereite den Original Teebetanischen Yak-Tee zu."],
			["menu", _menu_options()],
		],
		"prophecy": [
			["say", "Don Kamille", "Dann sagen Sie mal die Zukunft voraus, bitte."],
			["say", "Teesa", "„Aus dem Teesatz sagt er – oder sie – die Zukunft voraus.“"],
			["say", "Teesa", "…Ich sehe Dich auf einer langen Reise. Du bist der Kapitän eines…"],
			["say", "Don Kamille", "Hmpf."],
			["menu", _menu_options()],
		],
		"bye": [
			["say", "Teesa", "Auf Wiedersehen, Hochwohlgeboren!"],
			["say", "Don Kamille", "Danke für mein Gespräch, verehrte Schwester."],
			["end"],
		],
	}

# ---------- UI ----------
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var help := Label.new()
	help.text = "Klick = gehen   •   Objekt anklicken = Interaktionsmenü (Ansehen / Reden / Benutzen)   •   LEERTASTE = Hotspots zeigen"
	help.position = Vector2(16, 12)
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	layer.add_child(help)

	objective_label = Label.new()
	objective_label.position = Vector2(16, 40)
	objective_label.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
	objective_label.visible = false
	layer.add_child(objective_label)

	# subtitle-style speech near the top, outlined (AC subtitles)
	speech = Label.new()
	speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech.size = Vector2(1000, 120)
	speech.position = Vector2(140, 120)
	speech.add_theme_font_size_override("font_size", 26)
	speech.add_theme_color_override("font_outline_color", Color.BLACK)
	speech.add_theme_constant_override("outline_size", 8)
	speech.visible = false
	layer.add_child(speech)

	# sentence line (hovered hotspot name)
	sentence_label = Label.new()
	sentence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sentence_label.size = Vector2(1280, 30)
	sentence_label.position = Vector2(0, 686)
	sentence_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	sentence_label.add_theme_color_override("font_outline_color", Color.BLACK)
	sentence_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(sentence_label)

	verb_box = VBoxContainer.new()
	verb_box.add_theme_constant_override("separation", 4)
	verb_box.visible = false
	layer.add_child(verb_box)

	menu_box = VBoxContainer.new()
	menu_box.position = Vector2(70, 470)
	menu_box.add_theme_constant_override("separation", 6)
	layer.add_child(menu_box)

	highlight_layer = Control.new()
	highlight_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(highlight_layer)
	for h in hotspots:
		var r: Rect2 = h["rect"]
		var pan := Panel.new()
		pan.position = r.position * WORLD_SCALE
		pan.size = r.size * WORLD_SCALE
		pan.modulate = Color(1, 1, 0.4, 0.35)
		var lbl := Label.new()
		lbl.text = h["name"]
		lbl.position = Vector2(0, -22)
		lbl.add_theme_color_override("font_color", Color(1, 1, 0.5))
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 5)
		pan.add_child(lbl)
		highlight_layer.add_child(pan)
	highlight_layer.visible = false

func _update_teesa() -> void:
	teesa.flip_h = facing_right
	teesa.position = teesa_feet - Vector2(0, 40)

func _process(delta: float) -> void:
	if walking:
		var to := walk_target - teesa_feet
		var step := WALK_SPEED * delta
		facing_right = to.x >= 0
		if to.length() <= step:
			teesa_feet = walk_target
			walking = false
			teesa.play("idle")
			if not pending_action.is_empty():
				var pa := pending_action
				pending_action = {}
				_run_verb(pa["verb"], pa["hs"])
		else:
			teesa_feet += to.normalized() * step
			if teesa.animation != "walk":
				teesa.play("walk")
		teesa_feet.x = clamp(teesa_feet.x, 100, 296)
		_update_teesa()

func _world_mouse() -> Vector2:
	return world.to_local(get_global_mouse_position())

func _hotspot_at(p: Vector2) -> Dictionary:
	for h in hotspots:
		if (h["rect"] as Rect2).has_point(p):
			return h
	return {}

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if in_dialogue or verb_box.visible:
			sentence_label.text = ""
		else:
			sentence_label.text = _hotspot_at(_world_mouse()).get("name", "")
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_click()
	elif event is InputEventKey:
		if event.keycode == KEY_SPACE:
			if in_dialogue and not awaiting_menu:
				_step()
			else:
				highlights_on = event.pressed
				highlight_layer.visible = highlights_on

func _on_click() -> void:
	if in_dialogue:
		if not awaiting_menu:
			_step()
		return
	if verb_box.visible:
		_close_verbs()
		return
	var p := _world_mouse()
	var h := _hotspot_at(p)
	if h.is_empty():
		walk_target = Vector2(clamp(p.x, 100, 296), FLOOR_Y)
		walking = true
		pending_action = {}
	else:
		_open_verbs(h)

# ---------- interaction (verb) menu ----------
func _open_verbs(h: Dictionary) -> void:
	_close_verbs()
	var r: Rect2 = h["rect"]
	var anchor := r.get_center() * WORLD_SCALE
	verb_box.position = Vector2(clamp(anchor.x - 60, 8, 1100), clamp(anchor.y - 40, 8, 560))
	for v in VERB_ORDER:
		if h["verbs"].has(v):
			var b := Button.new()
			b.text = VERB_LABELS[v]
			var verb: String = v
			b.pressed.connect(func(): _pick_verb(verb, h))
			verb_box.add_child(b)
	verb_box.visible = true

func _close_verbs() -> void:
	for c in verb_box.get_children():
		c.queue_free()
	verb_box.visible = false

func _pick_verb(verb: String, h: Dictionary) -> void:
	_close_verbs()
	# walk in front of the hotspot, then perform the verb
	var cx: float = (h["rect"] as Rect2).get_center().x
	walk_target = Vector2(clamp(cx, 110, 286), FLOOR_Y)
	walking = true
	pending_action = {"verb": verb, "hs": h}

func _run_verb(verb: String, h: Dictionary) -> void:
	var content = h["verbs"][verb]
	if verb == "talk":
		_start_conv(str(content))
	else:
		var steps: Array = []
		for line in content:
			steps.append(["say", line[0], line[1]])
		steps.append(["end"])
		_run_segment_list(steps)

# ---------- dialogue engine ----------
func _run_segment_list(steps: Array) -> void:
	conv["_tmp"] = steps
	_start_conv("_tmp")

func _start_conv(key: String) -> void:
	in_dialogue = true
	speech.visible = true
	sentence_label.text = ""
	_goto(key)

func _goto(key: String) -> void:
	seg = conv[key].duplicate(true)
	seg_ip = 0
	_step()

func _step() -> void:
	_clear_menu()
	don.play("idle")
	if seg_ip >= seg.size():
		_end_dialogue(); return
	var ins: Array = seg[seg_ip]
	seg_ip += 1
	match ins[0]:
		"say":
			speaker_name = str(ins[1])
			speech.text = str(ins[2])
			speech.add_theme_color_override("font_color",
				Color(1, 0.85, 0.4) if speaker_name == "Don Kamille" else Color(0.75, 0.85, 1))
			if speaker_name == "Don Kamille":
				don.play("talk")
		"objective":
			objective_label.text = str(ins[1])
			objective_label.visible = true
			_step()
		"menu":
			_show_menu(ins[1])
		"goto":
			_goto(str(ins[1]))
		"end":
			_end_dialogue()

func _show_menu(options: Array) -> void:
	awaiting_menu = true
	speech.text = ""
	for opt in options:
		var b := Button.new()
		b.text = "•  " + str(opt[0])
		var target := str(opt[1])
		b.pressed.connect(func(): _choose(target))
		menu_box.add_child(b)

func _choose(target: String) -> void:
	awaiting_menu = false
	_clear_menu()
	_goto(target)

func _clear_menu() -> void:
	for c in menu_box.get_children():
		c.queue_free()

func _end_dialogue() -> void:
	in_dialogue = false
	awaiting_menu = false
	speech.visible = false
	speech.text = ""
	don.play("idle")
	_clear_menu()
