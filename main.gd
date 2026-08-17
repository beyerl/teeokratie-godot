extends Node2D
# Teeokratie - Office room. Native Godot rebuild of the Unity/Adventure Creator scene
# "TeaistCloisterOffice.unity". This step adds: animated walk cycle for Teesa, a talking
# animation for Don Kamille, real umlauts, and a branching dialogue tree with player-
# selectable options + an objective - mirroring Adventure Creator's ActionDialogOption /
# ActionObjectiveSet. All German text is taken from the original Unity scene.

const WORLD_SCALE := 4.0
const FLOOR_Y := 168.0
const WALK_SPEED := 95.0

var world: Node2D
var teesa: AnimatedSprite2D
var teesa_feet := Vector2(110, FLOOR_Y)
var walk_target := Vector2(110, FLOOR_Y)
var walking := false
var facing_right := true

var don: AnimatedSprite2D
const DON_FEET := Vector2(252, 150)

var pending_conv := ""            # conversation to start once Teesa arrives
var hotspots: Array = []
var hover_name := ""

# --- dialogue engine state ---
var conv: Dictionary = {}
var seg: Array = []               # current segment steps
var seg_ip := 0                   # instruction pointer
var in_dialogue := false
var awaiting_menu := false

# --- UI ---
var sentence_label: Label
var dlg_panel: Panel
var dlg_speaker: Label
var dlg_text: Label
var menu_box: VBoxContainer
var objective_label: Label

func _ready() -> void:
	world = Node2D.new()
	world.scale = Vector2(WORLD_SCALE, WORLD_SCALE)
	add_child(world)

	var bg := Sprite2D.new()
	bg.texture = load("res://assets/office.png")
	bg.centered = false
	world.add_child(bg)

	don = _make_don()
	world.add_child(don)

	teesa = _make_teesa()
	world.add_child(teesa)
	_update_teesa()

	_build_hotspots()
	_build_ui()
	_build_conversation()

# ---------- sprites ----------
func _teesa_frame(idx: int) -> AtlasTexture:
	# sheet 240x400, 40x80 frames, 6 columns. Row 0 (top) = left-facing walk cycle.
	var tex := load("res://assets/teesa_sheet.png")
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2((idx % 6) * 40, 0, 40, 80)
	return at

func _make_teesa() -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 10.0)
	for i in range(6):
		frames.add_frame("walk", _teesa_frame(i))
	frames.add_animation("idle")
	frames.add_frame("idle", _teesa_frame(0))
	var a := AnimatedSprite2D.new()
	a.sprite_frames = frames
	a.centered = true
	a.play("idle")
	return a

func _don_frame(col: int, row: int) -> AtlasTexture:
	# sheet 207x178, 69x89 frames. Image row 0 (y=0): Idle_R_0, Talk_R_0, Talk_R_1
	# Image row 1 (y=89): Talk_R_2, Talk_R_3, Talk_R_4
	var tex := load("res://assets/donkamille_sheet.png")
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(col * 69, row * 89, 69, 89)
	return at

func _make_don() -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.add_frame("idle", _don_frame(0, 0))          # Idle_R_0
	frames.add_animation("talk")
	frames.set_animation_speed("talk", 8.0)
	frames.add_frame("talk", _don_frame(1, 0))          # Talk_R_0
	frames.add_frame("talk", _don_frame(2, 0))          # Talk_R_1
	frames.add_frame("talk", _don_frame(0, 1))          # Talk_R_2
	frames.add_frame("talk", _don_frame(1, 1))          # Talk_R_3
	frames.add_frame("talk", _don_frame(2, 1))          # Talk_R_4
	var a := AnimatedSprite2D.new()
	a.sprite_frames = frames
	a.centered = true
	a.scale = Vector2(0.72, 0.72)
	a.flip_h = true                                     # sprites face right; face him left toward the room
	# centered: place center so feet land on DON_FEET
	a.position = DON_FEET - Vector2(0, 89 * 0.72 / 2.0)
	a.play("idle")
	return a

# ---------- hotspots ----------
func _build_hotspots() -> void:
	hotspots = [
		{"name": "Fenster", "rect": Rect2(4, 25, 48, 125), "lines": [
			["Teesa", "Es regnet Katzen und Hunde."]]},
		{"name": "Bücherregal", "rect": Rect2(150, 55, 75, 85), "lines": [
			["Teesa", "Die interessanten Bücher stehen alle im Vorzimmer."],
			["Teesa", "Ein Haufen pietistischer Plunder. Laaangweilig!"]]},
		{"name": "Durchgangsklappvorrichtung (DK)", "rect": Rect2(274, 66, 28, 74), "lines": [
			["Teesa", "Eine Durchgangsklappvorrichtung."]]},
		{"name": "Prüfungsordnung", "rect": Rect2(66, 110, 52, 20), "lines": [
			["Teesa", "Da steht: „Zum Abschluss seiner Literertour hat der Anwärter…“"],
			["Teesa", "„Zur Zubereitung wird benötigt: 1. Original Teebetanische Yak-Tee(TM)-Blätter“"],
			["Teesa", "„2. Kristallklares, mineralstoffreiches Quellwasser“"],
			["Teesa", "„3. Ein Teekessel oder ein anderes Gefäß“"],
			["Teesa", "„4. Ein angeheizter Ofen“"]]},
		{"name": "Don Kamille", "rect": Rect2(228, 88, 52, 62), "conv": "start"},
	]

# ---------- conversation tree (Adventure Creator dialog options) ----------
func _menu_options() -> Array:
	return [
		["Wie läuft die Abschlussprüfung ab?", "exam"],
		["Sagen Sie mir die Zukunft voraus?", "prophecy"],
		["Auf Wiedersehen, Hochwohlgeboren!", "bye"],
	]

func _build_conversation() -> void:
	conv = {
		"start": [
			["say", "Don Kamille", "Da sind Sie ja, Schwester Teegießertochter."],
			["menu", _menu_options()],
		],
		"exam": [
			["say", "Don Kamille", "Vorschriftsgemäß verlese ich die Teeisten-Prüfungsordnung:"],
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
			["say", "Don Kamille", "Hmpf. 52 Sekunden zu spät, wie ich sehe."],
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

	var title := Label.new()
	title.text = "TEEOKRATIE  –  Office  (Godot-Portierung)"
	title.position = Vector2(16, 10)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	layer.add_child(title)

	var help := Label.new()
	help.text = "Klick = gehen / ansehen   •   Don Kamille anklicken = reden   •   im Gespräch: Option wählen oder klicken für weiter"
	help.position = Vector2(16, 34)
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	layer.add_child(help)

	objective_label = Label.new()
	objective_label.position = Vector2(16, 62)
	objective_label.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
	objective_label.visible = false
	layer.add_child(objective_label)

	sentence_label = Label.new()
	sentence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sentence_label.size = Vector2(1280, 30)
	sentence_label.position = Vector2(0, 452)
	sentence_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	layer.add_child(sentence_label)

	menu_box = VBoxContainer.new()
	menu_box.position = Vector2(60, 470)
	menu_box.add_theme_constant_override("separation", 6)
	layer.add_child(menu_box)

	dlg_panel = Panel.new()
	dlg_panel.size = Vector2(1180, 120)
	dlg_panel.position = Vector2(50, 576)
	dlg_panel.visible = false
	layer.add_child(dlg_panel)

	dlg_speaker = Label.new()
	dlg_speaker.position = Vector2(24, 12)
	dlg_speaker.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	dlg_panel.add_child(dlg_speaker)

	dlg_text = Label.new()
	dlg_text.position = Vector2(24, 44)
	dlg_text.size = Vector2(1130, 70)
	dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg_panel.add_child(dlg_text)

func _update_teesa() -> void:
	teesa.flip_h = facing_right   # base frames face left; flip to face right
	teesa.position = teesa_feet - Vector2(0, 40)   # centered: feet at bottom of 80px frame

func _process(delta: float) -> void:
	if walking:
		var to := walk_target - teesa_feet
		var step := WALK_SPEED * delta
		facing_right = to.x >= 0
		if to.length() <= step:
			teesa_feet = walk_target
			walking = false
			teesa.play("idle")
			if pending_conv != "":
				_start_conv(pending_conv)
				pending_conv = ""
		else:
			teesa_feet += to.normalized() * step
			if teesa.animation != "walk":
				teesa.play("walk")
		teesa_feet.x = clamp(teesa_feet.x, 24, 296)
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
		if in_dialogue:
			sentence_label.text = ""
		else:
			hover_name = _hotspot_at(_world_mouse()).get("name", "")
			sentence_label.text = hover_name
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_click()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE and in_dialogue and not awaiting_menu:
		_step()

func _on_click() -> void:
	if in_dialogue:
		if not awaiting_menu:
			_step()   # advance line; menu clicks handled by buttons
		return
	var p := _world_mouse()
	var h := _hotspot_at(p)
	if h.is_empty():
		walk_target = Vector2(clamp(p.x, 24, 296), FLOOR_Y)
		walking = true
		pending_conv = ""
	elif h.has("conv"):
		walk_target = Vector2(clamp((h["rect"] as Rect2).get_center().x - 40, 40, 260), FLOOR_Y)
		walking = true
		pending_conv = h["conv"]
	else:
		walk_target = Vector2(clamp((h["rect"] as Rect2).get_center().x, 40, 280), FLOOR_Y)
		walking = true
		pending_conv = ""
		_queue_lines(h["lines"])

# simple (non-branching) look responses reuse the dialogue engine via a temp segment
var _pending_lines: Array = []
func _queue_lines(lines: Array) -> void:
	_pending_lines = lines.duplicate(true)
	# defer until arrival handled in _process? Looks are immediate on arrival:
	# convert to a one-off conversation
	conv["_look"] = []
	for l in lines:
		conv["_look"].append(["say", l[0], l[1]])
	conv["_look"].append(["end"])
	pending_conv = "_look"

# ---------- dialogue engine ----------
func _start_conv(name: String) -> void:
	in_dialogue = true
	dlg_panel.visible = true
	sentence_label.text = ""
	_goto(name)

func _goto(name: String) -> void:
	seg = conv[name].duplicate(true)
	seg_ip = 0
	_step()

func _step() -> void:
	_clear_menu()
	don.play("idle")
	if seg_ip >= seg.size():
		_end_dialogue()
		return
	var ins: Array = seg[seg_ip]
	seg_ip += 1
	match ins[0]:
		"say":
			dlg_speaker.text = str(ins[1]) + ":"
			dlg_text.text = str(ins[2])
			if ins[1] == "Don Kamille":
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
	dlg_speaker.text = "Teesa:"
	dlg_text.text = "(Wähle eine Antwort)"
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
	dlg_panel.visible = false
	don.play("idle")
	_clear_menu()
