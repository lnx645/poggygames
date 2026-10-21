extends Control
## Kontrol sentuh PoggyCraft: joystick jalan (kiri), geser layar untuk melihat,
## tombol lompat/hancur/pasang/terbang (kanan). Dibangun dari main.gd.

var pemain: CharacterBody3D

var _joy_pusat := Vector2.ZERO
var _joy_sentuh := -1
var _joy_nilai := Vector2.ZERO
var _area_joy: Control
var _kenop: Control
var _btn_turun: Button
var _tahan_hancur := false
var _tahan_pasang := false
var _akumulasi := 0.0

const R_JOY := 78.0

func _siapkan_gaya_btn(b: Button) -> void:
	b.add_theme_font_size_override("font_size", 15)
	var gaya := StyleBoxFlat.new()
	gaya.bg_color = Color(0, 0, 0, 0.42)
	gaya.set_corner_radius_all(14)
	gaya.set_border_width_all(2)
	gaya.border_color = Color(1, 1, 1, 0.35)
	b.add_theme_stylebox_override("normal", gaya)
	var gaya_tekan := gaya.duplicate() as StyleBoxFlat
	gaya_tekan.bg_color = Color(1, 0.85, 0.2, 0.55)
	b.add_theme_stylebox_override("pressed", gaya_tekan)
	b.add_theme_color_override("font_color", Color.WHITE)

func bangun(target: CharacterBody3D) -> void:
	pemain = target
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# --- Joystick kiri bawah ---
	_area_joy = Control.new()
	_area_joy.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_area_joy.position = Vector2(26, -26 - R_JOY * 2)
	_area_joy.size = Vector2(R_JOY * 2, R_JOY * 2)
	_area_joy.mouse_filter = Control.MOUSE_FILTER_STOP
	_area_joy.draw.connect(_gambar_joy)
	_area_joy.gui_input.connect(_input_joy)
	add_child(_area_joy)
	_area_joy.queue_redraw()
	# --- Tombol kanan bawah ---
	var kolom := VBoxContainer.new()
	kolom.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	kolom.position = Vector2(-96, -330)
	kolom.add_theme_constant_override("separation", 10)
	add_child(kolom)
	var btn_hancur := Button.new()
	btn_hancur.text = "⛏️\nHancur"
	btn_hancur.custom_minimum_size = Vector2(70, 62)
	_siapkan_gaya_btn(btn_hancur)
	btn_hancur.button_down.connect(func() -> void: _tahan_hancur = true; pemain.aksi_hancur())
	btn_hancur.button_up.connect(func() -> void: _tahan_hancur = false)
	kolom.add_child(btn_hancur)
	var btn_pasang := Button.new()
	btn_pasang.text = "🧱\nPasang"
	btn_pasang.custom_minimum_size = Vector2(70, 62)
	_siapkan_gaya_btn(btn_pasang)
	btn_pasang.button_down.connect(func() -> void: _tahan_pasang = true; pemain.aksi_pasang())
	btn_pasang.button_up.connect(func() -> void: _tahan_pasang = false)
	kolom.add_child(btn_pasang)
	var btn_lompat := Button.new()
	btn_lompat.text = "⬆️\nLompat"
	btn_lompat.custom_minimum_size = Vector2(70, 62)
	_siapkan_gaya_btn(btn_lompat)
	btn_lompat.button_down.connect(func() -> void: pemain.sentuh_lompat = true)
	btn_lompat.button_up.connect(func() -> void: pemain.sentuh_lompat = false)
	kolom.add_child(btn_lompat)
	var btn_terbang := Button.new()
	btn_terbang.text = "🕊️\nTerbang"
	btn_terbang.custom_minimum_size = Vector2(70, 62)
	_siapkan_gaya_btn(btn_terbang)
	btn_terbang.pressed.connect(func() -> void: pemain.toggle_terbang())
	kolom.add_child(btn_terbang)
	_btn_turun = Button.new()
	_btn_turun.text = "⬇️\nTurun"
	_btn_turun.custom_minimum_size = Vector2(70, 62)
	_siapkan_gaya_btn(_btn_turun)
	_btn_turun.button_down.connect(func() -> void: pemain.sentuh_turun = true)
	_btn_turun.button_up.connect(func() -> void: pemain.sentuh_turun = false)
	_btn_turun.visible = false
	kolom.add_child(_btn_turun)

func _gambar_joy() -> void:
	var tengah := Vector2(R_JOY, R_JOY)
	_area_joy.draw_circle(tengah, R_JOY, Color(0, 0, 0, 0.3))
	_area_joy.draw_arc(tengah, R_JOY - 2.0, 0, TAU, 48, Color(1, 1, 1, 0.4), 2.5)
	var posisi_kenop := tengah + _joy_nilai * (R_JOY * 0.52)
	_area_joy.draw_circle(posisi_kenop, 30, Color(1, 1, 1, 0.45))

func _input_joy(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _joy_sentuh == -1:
			_joy_sentuh = event.index
			_joy_pusat = event.position
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
	var tengah := Vector2(R_JOY, R_JOY)
	var geser := lokal - tengah
	if geser.length() > R_JOY:
		geser = geser.normalized() * R_JOY
	_joy_nilai = geser / R_JOY
	var nilai := _joy_nilai
	if nilai.length() < 0.14:
		nilai = Vector2.ZERO
	pemain.sentuh_gerak = nilai
	_area_joy.queue_redraw()

func _input(event: InputEvent) -> void:
	# Geser di luar joystick & tombol = putar kamera
	if event is InputEventScreenDrag and event.index != _joy_sentuh:
		if event.position.x > get_viewport_rect().size.x * 0.35:
			pemain.lihat(event.relative.x, event.relative.y)

func _process(delta: float) -> void:
	if _btn_turun and pemain:
		_btn_turun.visible = pemain.terbang
	# Tahan tombol = bongkar/pasang berulang (setiap 0,25 dtk)
	if _tahan_hancur or _tahan_pasang:
		_akumulasi += delta
		if _akumulasi >= 0.25:
			_akumulasi = 0.0
			if _tahan_hancur:
				pemain.aksi_hancur()
			if _tahan_pasang:
				pemain.aksi_pasang()
	else:
		_akumulasi = 0.2
