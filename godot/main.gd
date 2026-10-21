extends Node3D
## PoggyCraft — titik masuk: bangun lingkungan, dunia, pemain, dan HUD.

const Pemain := preload("res://pemain.gd")

var dunia: Dunia
var pemain: CharacterBody3D
var label_balok: Label
var slot_hotbar: Array = []

const WARNA_SLOT := {
	Blok.RUMPUT: Color(0.35, 0.62, 0.22), Blok.TANAH: Color(0.5, 0.35, 0.2),
	Blok.BATU: Color(0.5, 0.5, 0.52), Blok.PAPAN: Color(0.66, 0.5, 0.3),
	Blok.KAYU: Color(0.4, 0.3, 0.16), Blok.KACA: Color(0.8, 0.92, 1.0),
	Blok.BATA: Color(0.62, 0.25, 0.2),
}

func _ready() -> void:
	_bangun_lingkungan()
	dunia = Dunia.new()
	add_child(dunia)
	dunia.hasilkan()
	dunia.bangun_semua()
	pemain = Pemain.new()
	pemain.dunia = dunia
	add_child(pemain)
	pemain.global_position = dunia.titik_spawn()
	pemain.pilihan_berubah.connect(_perbarui_hotbar)
	_bangun_hud()
	_perbarui_hotbar(pemain.pilihan())

func _bangun_lingkungan() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var langit := Sky.new()
	var bahan_langit := ProceduralSkyMaterial.new()
	bahan_langit.sky_top_color = Color(0.22, 0.42, 0.78)
	bahan_langit.sky_horizon_color = Color(0.72, 0.83, 0.94)
	bahan_langit.ground_bottom_color = Color(0.25, 0.22, 0.18)
	bahan_langit.ground_horizon_color = Color(0.72, 0.83, 0.94)
	langit.sky_material = bahan_langit
	env.background_mode = Environment.BG_SKY
	env.sky = langit
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.83, 0.94)
	env.fog_density = 0.012
	we.environment = env
	add_child(we)
	var matahari := DirectionalLight3D.new()
	matahari.rotation_degrees = Vector3(-52, -35, 0)
	matahari.light_energy = 1.15
	matahari.shadow_enabled = true
	add_child(matahari)

func _label(teks: String, ukuran: int, warna := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = teks
	l.add_theme_font_size_override("font_size", ukuran)
	l.add_theme_color_override("font_color", warna)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l

func _bangun_hud() -> void:
	var lapis := CanvasLayer.new()
	add_child(lapis)
	# Bidik tengah
	var bidik := _label("+", 30)
	bidik.set_anchors_preset(Control.PRESET_CENTER)
	bidik.position -= Vector2(10, 20)
	lapis.add_child(bidik)
	# Info kiri atas
	var info := _label("⛏️ PoggyCraft — klik layar untuk bermain\nWASD: jalan • Spasi: lompat • Shift: lari • F: terbang\nKlik kiri: hancurkan • Klik kanan: pasang balok • 1–7 / rol: pilih balok • Esc: lepas kursor", 14)
	info.position = Vector2(14, 10)
	lapis.add_child(info)
	# Nama balok terpilih
	label_balok = _label("", 17, Color(1, 0.95, 0.6))
	label_balok.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label_balok.position = Vector2(-80, -118)
	label_balok.custom_minimum_size = Vector2(160, 24)
	label_balok.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lapis.add_child(label_balok)
	# Hotbar bawah tengah
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.position = Vector2(-196, -78)
	bar.add_theme_constant_override("separation", 6)
	lapis.add_child(bar)
	for i in Pemain.PILIHAN.size():
		var jenis: int = Pemain.PILIHAN[i]
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(50, 50)
		var gaya := StyleBoxFlat.new()
		gaya.bg_color = WARNA_SLOT[jenis]
		gaya.set_corner_radius_all(8)
		gaya.set_border_width_all(3)
		gaya.border_color = Color(1, 1, 1, 0.25)
		panel.add_theme_stylebox_override("panel", gaya)
		var angka := _label(str(i + 1), 13)
		angka.position = Vector2(4, 2)
		panel.add_child(angka)
		bar.add_child(panel)
		slot_hotbar.append(panel)

func _perbarui_hotbar(jenis: int) -> void:
	label_balok.text = "Balok: " + Blok.NAMA[jenis]
	for i in slot_hotbar.size():
		var panel: PanelContainer = slot_hotbar[i]
		var gaya := (panel.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
		gaya.border_color = Color(1, 0.85, 0.2) if Pemain.PILIHAN[i] == jenis else Color(1, 1, 1, 0.25)
		panel.add_theme_stylebox_override("panel", gaya)
