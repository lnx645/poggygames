extends Control
## Kontrol sentuh PoggyClimb: joystick (kiri), tombol lompat & respawn (kanan),
## geser separuh kanan layar = putar kamera.

var pemain: CharacterBody3D
var _joy_sentuh := -1
var _joy_nilai := Vector2.ZERO
var _area_joy: Control

const R_JOY := 78.0

func _gaya_btn(b: Button) -> void:
	b.add_theme_font_size_override("font_size", 15)
	var gaya := StyleBoxFlat.new()
	gaya.bg_color = Color(0, 0, 0, 0.42)
	gaya.set_corner_radius_all(14)
	gaya.set_border_width_all(2)
	gaya.border_color = Color(1, 1, 1, 0.35)
	b.add_theme_stylebox_override("normal", gaya)
	var tekan := gaya.duplicate() as StyleBoxFlat
	tekan.bg_color = Color(1, 0.85, 0.2, 0.55)
	b.add_theme_stylebox_override("pressed", tekan)
	b.add_theme_color_override("font_color", Color.WHITE)

func bangun(target: CharacterBody3D) -> void:
	pemain = target
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area_joy = Control.new()
	_area_joy.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_area_joy.position = Vector2(26, -26 - R_JOY * 2)
	_area_joy.size = Vector2(R_JOY * 2, R_JOY * 2)
	_area_joy.mouse_filter = Control.MOUSE_FILTER_STOP
	_area_joy.draw.connect(_gambar_joy)
	_area_joy.gui_input.connect(_input_joy)
	add_child(_area_joy)
	_area_joy.queue_redraw()
	var kolom := VBoxContainer.new()
	kolom.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	kolom.position = Vector2(-96, -220)
	kolom.add_theme_constant_override("separation", 10)
	add_child(kolom)
	var btn_lompat := Button.new()
	btn_lompat.text = "⬆️\nLompat"
	btn_lompat.custom_minimum_size = Vector2(70, 62)
	_gaya_btn(btn_lompat)
	btn_lompat.button_down.connect(func() -> void: pemain.sentuh_lompat = true)
	btn_lompat.button_up.connect(func() -> void: pemain.sentuh_lompat = false)
	kolom.add_child(btn_lompat)
	var btn_respawn := Button.new()
	btn_respawn.text = "↺\nUlang"
	btn_respawn.custom_minimum_size = Vector2(70, 62)
	_gaya_btn(btn_respawn)
	btn_respawn.pressed.connect(func() -> void: pemain.respawn())
	kolom.add_child(btn_respawn)

func _gambar_joy() -> void:
	var tengah := Vector2(R_JOY, R_JOY)
	_area_joy.draw_circle(tengah, R_JOY, Color(0, 0, 0, 0.3))
	_area_joy.draw_arc(tengah, R_JOY - 2.0, 0, TAU, 48, Color(1, 1, 1, 0.4), 2.5)
	_area_joy.draw_circle(tengah + _joy_nilai * (R_JOY * 0.52), 30, Color(1, 1, 1, 0.45))

func _input_joy(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _joy_sentuh == -1:
			_joy_sentuh = event.index
			_perbarui_joy(event.position)
		elif not event.pressed and event.index == _joy_sentuh:
			_joy_sentuh = -1
			_joy_nilai = Vector2.ZERO
			pemain.sentuh_gerak = Vector2.ZERO
			_area_joy.queue_redraw()
	elif event is InputEventScreenDrag and event.index == _joy_sentuh:
		_perbarui_joy(event.position)

func _perbarui_joy(posisi_global: Vector2) -> void:
	var lokal := _area_joy.get_global_transform().affine_inverse() * posisi_global
	var geser := lokal - Vector2(R_JOY, R_JOY)
	if geser.length() > R_JOY:
		geser = geser.normalized() * R_JOY
	_joy_nilai = geser / R_JOY
	pemain.sentuh_gerak = _joy_nilai if _joy_nilai.length() >= 0.14 else Vector2.ZERO
	_area_joy.queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag and event.index != _joy_sentuh:
		if event.position.x > get_viewport_rect().size.x * 0.35:
			pemain.lihat(event.relative.x, event.relative.y)
