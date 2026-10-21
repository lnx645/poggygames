class_name Lintasan
extends Node3D
## Lintasan mendaki PoggyClimb: gunung dekoratif + jalur rintangan ala obby Roblox.
## Semua bagian dibangun dari data: [pusat, ukuran, bahan].

signal checkpoint_dicapai(indeks: int)
signal kena_lava
signal sampai_puncak

var checkpoints: Array = [] # {area, posisi: Vector3 (titik respawn)}
var zona_tangga: Array = []
var _platform_gerak: AnimatableBody3D
var _gerak_dari := Vector3(-13, 24.2, 13)
var _gerak_ke := Vector3(-5, 24.2, 13)
var _gerak_t := 0.0
var _indeks_cp_aktif := -1

var MAT: Dictionary = {}

func _bahan(warna: Color, emisi := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = warna
	m.roughness = 0.92
	if emisi > 0.0:
		m.emission_enabled = true
		m.emission = warna
		m.emission_energy_multiplier = emisi
	return m

func _siapkan_bahan() -> void:
	MAT = {
		"rumput": _bahan(Color(0.36, 0.72, 0.28)),
		"tanah": _bahan(Color(0.55, 0.4, 0.26)),
		"batu": _bahan(Color(0.56, 0.56, 0.6)),
		"batu_gelap": _bahan(Color(0.42, 0.42, 0.47)),
		"kayu": _bahan(Color(0.66, 0.47, 0.3)),
		"kayu_gelap": _bahan(Color(0.45, 0.31, 0.18)),
		"salju": _bahan(Color(0.94, 0.97, 0.99)),
		"lava": _bahan(Color(1.0, 0.32, 0.08), 1.6),
		"emas": _bahan(Color(1.0, 0.78, 0.2), 0.35),
		"cp_mati": _bahan(Color(0.65, 0.65, 0.7)),
		"cp_hidup": _bahan(Color(0.25, 0.95, 0.45), 0.7),
		"daun": _bahan(Color(0.22, 0.55, 0.22)),
		"awan": _bahan(Color(1, 1, 1, 0.92)),
		"merah": _bahan(Color(0.9, 0.15, 0.15)),
	}

func kotak(pusat: Vector3, ukuran: Vector3, bahan: String, induk: Node3D = null) -> StaticBody3D:
	var badan := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = ukuran
	mesh.material = MAT[bahan]
	mi.mesh = mesh
	var bentuk := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = ukuran
	bentuk.shape = box
	badan.add_child(mi)
	badan.add_child(bentuk)
	badan.position = pusat
	(induk if induk else self).add_child(badan)
	return badan

func _area(pusat: Vector3, ukuran: Vector3) -> Area3D:
	var a := Area3D.new()
	# Hanya pantau layer 2 (pemain) — abaikan bagian lintasan sendiri (layer 1)
	a.collision_layer = 0
	a.collision_mask = 2
	var bentuk := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = ukuran
	bentuk.shape = box
	a.add_child(bentuk)
	a.position = pusat
	add_child(a)
	return a

func _pohon(x: float, z: float, y: float, skala := 1.0) -> void:
	kotak(Vector3(x, y + 0.9 * skala, z), Vector3(0.5, 1.8, 0.5) * skala, "kayu_gelap")
	var kerucut := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 1.5 * skala
	cm.height = 3.2 * skala
	cm.radial_segments = 8
	cm.material = MAT["daun"]
	kerucut.mesh = cm
	kerucut.position = Vector3(x, y + (1.8 + 1.6) * skala, z)
	add_child(kerucut)

func bangun() -> void:
	_siapkan_bahan()
	# ===== Tanah dasar & gunung =====
	kotak(Vector3(0, -1, 0), Vector3(110, 2, 110), "rumput")
	# Lapisan gunung (kerucut bertingkat, segmen 7 agar low-poly)
	var lapisan := [
		[15.0, 11.5, 8.0, "rumput"], [11.5, 9.0, 8.0, "batu"], [9.0, 6.8, 8.0, "batu"],
		[6.8, 4.6, 8.0, "batu_gelap"], [4.6, 0.5, 6.0, "salju"],
	]
	var y := 0.0
	for L in lapisan:
		var cyl := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.bottom_radius = L[0]
		cm.top_radius = L[1]
		cm.height = L[2]
		cm.radial_segments = 7
		cm.material = MAT[L[3]]
		cyl.mesh = cm
		cyl.position = Vector3(0, y + L[2] / 2.0, 0)
		add_child(cyl)
		var tabrak := StaticBody3D.new()
		var bentuk := CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = L[0]
		cs.height = L[2]
		bentuk.shape = cs
		tabrak.add_child(bentuk)
		tabrak.position = cyl.position
		add_child(tabrak)
		y += L[2]
	# Pohon hias di tanah (jauhi jalur selatan/timur)
	for p in [[-24, 18], [-30, -6], [-20, -24], [26, 22], [30, -14], [8, 30], [-8, 32], [34, 6], [-36, 10], [18, -30]]:
		_pohon(float(p[0]), float(p[1]), 0.0, randf_range(0.9, 1.5))

	# ===== JALUR =====
	# Bagian A — undakan rumput (selatan → timur)
	var bagian_a := [
		[8, 0.6, 16, 5, 1.2, 5], [12, 1.6, 13, 5, 1.2, 5], [16, 2.6, 10, 5, 1.2, 5], [19, 3.6, 5, 5, 1.2, 5],
	]
	for b in bagian_a:
		kotak(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), "rumput")
	_tambah_checkpoint(Vector3(20, 4.6, 0), 0)
	# Bagian B — undakan batu (timur → utara)
	var bagian_b := [
		[20, 5.6, -5, 4.6, 1.2, 4.6], [18.5, 6.6, -10, 4.6, 1.2, 4.6], [15.5, 7.6, -14.5, 4.6, 1.2, 4.6],
	]
	for b in bagian_b:
		kotak(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), "batu")
	# Lava! Kolam di bawah celah lompatan (12,8.6,-17) → (7,9.6,-19)
	var lava1 := _area(Vector3(9.5, 8.0, -18), Vector3(7, 1.2, 7))
	lava1.body_entered.connect(func(_b: Node3D) -> void: kena_lava.emit())
	var lava_mi := MeshInstance3D.new()
	var lava_mesh := BoxMesh.new()
	lava_mesh.size = Vector3(7, 0.4, 7)
	lava_mesh.material = MAT["lava"]
	lava_mi.mesh = lava_mesh
	lava_mi.position = Vector3(9.5, 7.9, -18)
	add_child(lava_mi)
	kotak(Vector3(7, 8.9, -19), Vector3(4.4, 1.2, 4.4), "batu")
	# Bagian C — papan kayu sempit (utara → barat)
	var bagian_c := [
		[2, 10.6, -20.5, 4.4, 0.6, 2.4], [-3, 11.6, -20.5, 4.4, 0.6, 2.4], [-8, 12.6, -19.5, 4.4, 0.6, 2.4],
	]
	for b in bagian_c:
		kotak(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), "kayu")
	_tambah_checkpoint(Vector3(-12.5, 13.6, -17.5), 1)
	# Tangga ke atas (zona panjat di sisi barat)
	zona_tangga.append(_bangun_tangga(Vector3(-14.5, 13.6, -14), 7.0))
	kotak(Vector3(-14.5, 19.8, -11), Vector3(4.6, 1.2, 4.6), "batu")
	# Bagian D — balok sempit zigzag (barat → selatan)
	var bagian_d := [
		[-12, 21.9, -6, 4.2, 0.5, 0.9], [-8.5, 22.9, -1.5, 4.2, 0.5, 0.9], [-10.5, 23.9, 3, 4.2, 0.5, 0.9],
	]
	for b in bagian_d:
		kotak(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), "kayu_gelap")
	_tambah_checkpoint(Vector3(-13, 24.9, 7.5), 2)
	# Platform bergerak melintasi jurang selatan
	_platform_gerak = AnimatableBody3D.new()
	var pg_mi := MeshInstance3D.new()
	var pg_mesh := BoxMesh.new()
	pg_mesh.size = Vector3(3.6, 0.6, 3.6)
	pg_mesh.material = MAT["emas"]
	pg_mi.mesh = pg_mesh
	var pg_bentuk := CollisionShape3D.new()
	var pg_box := BoxShape3D.new()
	pg_box.size = Vector3(3.6, 0.6, 3.6)
	pg_bentuk.shape = pg_box
	_platform_gerak.add_child(pg_mi)
	_platform_gerak.add_child(pg_bentuk)
	_platform_gerak.position = _gerak_dari
	add_child(_platform_gerak)
	kotak(Vector3(-4, 25.4, 13), Vector3(3.6, 1, 3.6), "batu")
	kotak(Vector3(-1.5, 26.4, 9.5), Vector3(3.6, 1, 3.6), "salju")
	# Bagian E — zona salju (selatan → timur, naik ke puncak)
	var bagian_e := [
		[1.5, 27.4, 5, 4.4, 1, 4.4], [5, 28.4, 0.5, 4.4, 1, 4.4], [8.5, 29.4, -3, 4.4, 1, 4.4],
	]
	for b in bagian_e:
		kotak(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), "salju")
	_tambah_checkpoint(Vector3(11.5, 30.4, 1), 3)
	# Pendakian akhir ke puncak
	var akhir := [
		[13, 31.4, 5.5, 4, 1, 4], [11.5, 32.4, 9.5, 4, 1, 4], [8, 33.4, 12, 4, 1, 4], [4.5, 34.4, 10, 4, 1, 4], [2, 35.4, 6, 4, 1, 4],
	]
	for b in akhir:
		kotak(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), "salju")
	# ===== PUNCAK =====
	kotak(Vector3(0, 36.6, 0), Vector3(10, 1.2, 10), "salju")
	kotak(Vector3(0, 37.4, 0), Vector3(10.6, 0.35, 10.6), "emas")
	# Tiang + bendera
	kotak(Vector3(0, 40.5, 0), Vector3(0.35, 6, 0.35), "kayu_gelap")
	var bendera := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.2, 1.8, 0.12)
	bm.material = MAT["merah"]
	bendera.mesh = bm
	bendera.position = Vector3(1.75, 42.6, 0)
	add_child(bendera)
	var area_puncak := _area(Vector3(0, 38.2, 0), Vector3(10, 2.5, 10))
	area_puncak.body_entered.connect(func(_b: Node3D) -> void: sampai_puncak.emit())

func _tambah_checkpoint(posisi: Vector3, indeks: int) -> void:
	var alas := kotak(posisi, Vector3(4.2, 0.5, 4.2), "cp_mati")
	_alas_cp.append(alas)
	var area := _area(posisi + Vector3(0, 0.6, 0), Vector3(4.2, 1.4, 4.2))
	area.body_entered.connect(func(_b: Node3D) -> void:
		if indeks > _indeks_cp_aktif:
			_indeks_cp_aktif = indeks
			(alas.get_child(0) as MeshInstance3D).mesh.material = MAT["cp_hidup"]
			checkpoint_dicapai.emit(indeks))
	checkpoints.append({"posisi": posisi + Vector3(0, 1.25, 0), "area": area})

func _bangun_tangga(posisi: Vector3, tinggi: float) -> Area3D:
	# Rel + anak tangga visual
	kotak(posisi + Vector3(-1.1, tinggi / 2.0, 0), Vector3(0.18, tinggi, 0.18), "kayu_gelap")
	kotak(posisi + Vector3(1.1, tinggi / 2.0, 0), Vector3(0.18, tinggi, 0.18), "kayu_gelap")
	var n := int(tinggi / 0.55)
	for i in n:
		kotak(posisi + Vector3(0, 0.4 + i * 0.55, 0), Vector3(2.2, 0.14, 0.3), "kayu")
	var zona := _area(posisi + Vector3(0, tinggi / 2.0, 0), Vector3(3.0, tinggi, 2.4))
	return zona

func posisi_spawn() -> Vector3:
	return Vector3(0, 1.2, 24)

func atur_ulang() -> void:
	_indeks_cp_aktif = -1
	for data in _alas_cp:
		(data.get_child(0) as MeshInstance3D).mesh.material = MAT["cp_mati"]

var _alas_cp: Array = []

func _physics_process(delta: float) -> void:
	if _platform_gerak:
		_gerak_t += delta * 0.32
		var k := (sin(_gerak_t) + 1.0) / 2.0
		_platform_gerak.position = _gerak_dari.lerp(_gerak_ke, k)
		_platform_gerak.constant_linear_velocity = (_gerak_ke - _gerak_dari) * cos(_gerak_t) * 0.32
