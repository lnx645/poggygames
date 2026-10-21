extends Node3D
## PoggyClimb — titik masuk: lingkungan, lintasan, pemain, HUD, awan.

const Pemain3 := preload("res://pemain3.gd")
const Kontrol3 := preload("res://kontrol3.gd")

var lintasan: Lintasan
var pemain: CharacterBody3D
var awan: Array = []
var waktu := 0.0
var berjalan := true
var cp_tercapai := 0

var label_waktu: Label
var label_cp: Label
var label_persen: Label
var bar_progres: ProgressBar
var label_toast: Label
var panel_menang: PanelContainer
var label_hasil: Label
var _toast_sisa := 0.0

const Y_PUNCAK := 37.2

func _ready() -> void:
	_bangun_lingkungan()
	lintasan = Lintasan.new()
	add_child(lintasan)
	lintasan.bangun()
	pemain = Pemain3.new()
	pemain.lintasan = lintasan
	pemain.titik_respawn = lintasan.posisi_spawn()
	add_child(pemain)
	pemain.global_position = lintasan.posisi_spawn()
	lintasan.checkpoint_dicapai.connect(_cp_dicapai)
	lintasan.kena_lava.connect(func() -> void:
		pemain.respawn()
		_toast("🔥 Kena lava! Balik ke checkpoint."))
	lintasan.sampai_puncak.connect(_menang)
	pemain.jatuh.connect(func() -> void: _toast("💦 Jatuh! Kembali ke checkpoint terakhir."))
	_bangun_awan()
	_bangun_hud()

func _bangun_lingkungan() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var langit := Sky.new()
	var bahan := ProceduralSkyMaterial.new()
	bahan.sky_top_color = Color(0.2, 0.45, 0.9)
	bahan.sky_horizon_color = Color(0.65, 0.82, 0.98)
	bahan.ground_bottom_color = Color(0.3, 0.35, 0.3)
	bahan.ground_horizon_color = Color(0.65, 0.82, 0.98)
	bahan.sun_angle_max = 25.0
	langit.sky_material = bahan
	env.background_mode = Environment.BG_SKY
	env.sky = langit
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.86, 0.97)
	env.fog_density = 0.006
	we.environment = env
	add_child(we)
	var matahari := DirectionalLight3D.new()
	matahari.rotation_degrees = Vector3(-48, -28, 0)
	matahari.light_energy = 1.2
	matahari.shadow_enabled = true
	add_child(matahari)

func _bangun_awan() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.92)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 12:
		var a := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(rng.randf_range(6, 13), rng.randf_range(1.2, 2), rng.randf_range(4, 7))
		mesh.material = mat
		a.mesh = mesh
		a.position = Vector3(rng.randf_range(-70, 70), rng.randf_range(46, 58), rng.randf_range(-70, 70))
		add_child(a)
		awan.append(a)

func _gaya_panel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.06, 0.14, 0.78)
	s.set_corner_radius_all(14)
	s.set_border_width_all(2)
	s.border_color = Color(1, 1, 1, 0.14)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 9
	s.content_margin_bottom = 9
	return s

func _label(teks: String, ukuran: int, warna := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = teks
	l.add_theme_font_size_override("font_size", ukuran)
	l.add_theme_color_override("font_color", warna)
	return l

func _bangun_hud() -> void:
	var lapis := CanvasLayer.new()
	add_child(lapis)
	# Panel kiri atas: waktu + checkpoint
	var panel_kiri := PanelContainer.new()
	panel_kiri.add_theme_stylebox_override("panel", _gaya_panel())
	panel_kiri.position = Vector2(14, 12)
	var v := VBoxContainer.new()
	label_waktu = _label("⏱️ 00:00", 19, Color(1, 0.95, 0.6))
	label_cp = _label("🚩 Checkpoint 0/4", 16)
	v.add_child(label_waktu)
	v.add_child(label_cp)
	panel_kiri.add_child(v)
	lapis.add_child(panel_kiri)
	# Panel tengah atas: progres ke puncak
	var panel_tengah := PanelContainer.new()
	panel_tengah.add_theme_stylebox_override("panel", _gaya_panel())
	panel_tengah.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel_tengah.position = Vector2(-160, 12)
	panel_tengah.custom_minimum_size = Vector2(320, 0)
	var v2 := VBoxContainer.new()
	label_persen = _label("🏔️ Menuju Puncak — 0%", 16)
	label_persen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar_progres = ProgressBar.new()
	bar_progres.min_value = 0
	bar_progres.max_value = 100
	bar_progres.custom_minimum_size = Vector2(290, 14)
	bar_progres.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.18)
	bg.set_corner_radius_all(7)
	var isi := StyleBoxFlat.new()
	isi.bg_color = Color(1, 0.78, 0.2)
	isi.set_corner_radius_all(7)
	bar_progres.add_theme_stylebox_override("background", bg)
	bar_progres.add_theme_stylebox_override("fill", isi)
	v2.add_child(label_persen)
	v2.add_child(bar_progres)
	panel_tengah.add_child(v2)
	lapis.add_child(panel_tengah)
	# Toast tengah
	label_toast = _label("", 24, Color(1, 0.95, 0.55))
	label_toast.set_anchors_preset(Control.PRESET_CENTER)
	label_toast.position = Vector2(-200, -120)
	label_toast.custom_minimum_size = Vector2(400, 40)
	label_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_toast.modulate.a = 0.0
	lapis.add_child(label_toast)
	# Petunjuk bawah
	var petunjuk := _label("Klik layar untuk mengunci mouse • WASD jalan • Spasi lompat • panjat tangga dengan W • Esc lepas kursor", 13, Color(1, 1, 1, 0.85))
	petunjuk.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	petunjuk.position = Vector2(-260, -30)
	petunjuk.custom_minimum_size = Vector2(520, 20)
	petunjuk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lapis.add_child(petunjuk)
	# Panel menang
	panel_menang = PanelContainer.new()
	panel_menang.add_theme_stylebox_override("panel", _gaya_panel())
	panel_menang.set_anchors_preset(Control.PRESET_CENTER)
	panel_menang.position = Vector2(-170, -110)
	panel_menang.custom_minimum_size = Vector2(340, 0)
	var v3 := VBoxContainer.new()
	v3.add_theme_constant_override("separation", 10)
	var judul := _label("🎉 SAMPAI PUNCAK!", 26, Color(1, 0.85, 0.3))
	judul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_hasil = _label("", 17)
	label_hasil.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var btn := Button.new()
	btn.text = "↺ Main Lagi"
	btn.add_theme_font_size_override("font_size", 17)
	btn.pressed.connect(_main_lagi)
	v3.add_child(judul)
	v3.add_child(label_hasil)
	v3.add_child(btn)
	panel_menang.add_child(v3)
	panel_menang.visible = false
	lapis.add_child(panel_menang)
	# Kontrol sentuh
	var lapis_sentuh := CanvasLayer.new()
	lapis_sentuh.layer = 2
	add_child(lapis_sentuh)
	var ks: Control = Kontrol3.new()
	ks.bangun(pemain)
	lapis_sentuh.add_child(ks)
	ks.visible = DisplayServer.is_touchscreen_available()
	var btn_sentuh := Button.new()
	btn_sentuh.text = "🎮 Sentuh"
	btn_sentuh.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn_sentuh.position = Vector2(-118, 12)
	btn_sentuh.pressed.connect(func() -> void: ks.visible = not ks.visible)
	lapis_sentuh.add_child(btn_sentuh)

func _toast(teks: String) -> void:
	label_toast.text = teks
	label_toast.modulate.a = 1.0
	_toast_sisa = 2.4

func _cp_dicapai(indeks: int) -> void:
	cp_tercapai = indeks + 1
	pemain.titik_respawn = lintasan.checkpoints[indeks]["posisi"]
	label_cp.text = "🚩 Checkpoint %d/4" % cp_tercapai
	_toast("🚩 Checkpoint %d tersimpan!" % cp_tercapai)

func _menang() -> void:
	if not berjalan:
		return
	berjalan = false
	label_hasil.text = "Waktu tempuh: %s\nCheckpoint: %d/4" % [_format_waktu(), cp_tercapai]
	panel_menang.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _main_lagi() -> void:
	lintasan.atur_ulang()
	cp_tercapai = 0
	waktu = 0.0
	berjalan = true
	label_cp.text = "🚩 Checkpoint 0/4"
	panel_menang.visible = false
	pemain.titik_respawn = lintasan.posisi_spawn()
	pemain.respawn()

func _format_waktu() -> String:
	var d := int(waktu)
	return "%02d:%02d" % [d / 60, d % 60]

func _process(delta: float) -> void:
	for a in awan:
		(a as Node3D).position.x += delta * 0.7
		if (a as Node3D).position.x > 85:
			(a as Node3D).position.x = -85
	if berjalan:
		waktu += delta
	label_waktu.text = "⏱️ " + _format_waktu()
	if pemain:
		var persen := clampf((pemain.global_position.y - 1.0) / Y_PUNCAK * 100.0, 0.0, 100.0)
		bar_progres.value = persen
		label_persen.text = "🏔️ Menuju Puncak — %d%%" % int(persen)
	if _toast_sisa > 0.0:
		_toast_sisa -= delta
		if _toast_sisa <= 0.0:
			label_toast.modulate.a = 0.0

