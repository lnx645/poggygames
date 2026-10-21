class_name Dunia
extends Node3D
## Dunia voxel PoggyCraft: data balok, pembangkitan terrain prosedural,
## pembangunan mesh per chunk (+ tabrakan), penyuntingan, & raycast voxel.

const LEBAR := 64
const DALAM := 64
const TINGGI := 32
const CHUNK := 16

var data := PackedByteArray()
var _mat_opak: StandardMaterial3D
var _mat_kaca: StandardMaterial3D
var _atlas: Texture2D
var _chunk_mesh: Dictionary = {} # Vector2i -> MeshInstance3D

# Tabel sisi kubus: [normal, 4 sudut] — sudut CCW dilihat dari luar.
const SISI := [
	[Vector3i(1, 0, 0), [Vector3(1, 1, 1), Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(1, 1, 0)]],
	[Vector3i(-1, 0, 0), [Vector3(0, 1, 0), Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1)]],
	[Vector3i(0, 1, 0), [Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)]],
	[Vector3i(0, -1, 0), [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]],
	[Vector3i(0, 0, 1), [Vector3(0, 1, 1), Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1)]],
	[Vector3i(0, 0, -1), [Vector3(1, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, 0), Vector3(0, 1, 0)]],
]
# Indeks ubin per sisi mengikuti SISI: +x,-x,+y(atas),-y(bawah),+z,-z
const URUTAN_UBIN := [2, 2, 0, 1, 2, 2]

func _init() -> void:
	data.resize(LEBAR * DALAM * TINGGI)
	_atlas = Blok.buat_atlas()
	_mat_opak = StandardMaterial3D.new()
	_mat_opak.albedo_texture = _atlas
	_mat_opak.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mat_opak.roughness = 1.0
	_mat_kaca = StandardMaterial3D.new()
	_mat_kaca.albedo_texture = _atlas
	_mat_kaca.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mat_kaca.roughness = 0.2
	_mat_kaca.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func _idx(x: int, y: int, z: int) -> int:
	return x + LEBAR * (z + DALAM * y)

func ambil(x: int, y: int, z: int) -> int:
	if y < 0:
		return Blok.BATU
	if y >= TINGGI or x < 0 or z < 0 or x >= LEBAR or z >= DALAM:
		return Blok.UDARA
	return data[_idx(x, y, z)]

func pasang(x: int, y: int, z: int, jenis: int) -> void:
	if x < 0 or z < 0 or x >= LEBAR or z >= DALAM or y < 0 or y >= TINGGI:
		return
	data[_idx(x, y, z)] = jenis

func hasilkan() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 777
	noise.frequency = 0.045
	noise.fractal_octaves = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for x in LEBAR:
		for z in DALAM:
			var n := noise.get_noise_2d(float(x), float(z))
			var h := clampi(8 + int(n * 6.0), 3, TINGGI - 12)
			for y in h + 1:
				var jenis: int = Blok.BATU
				if y == h:
					jenis = Blok.PASIR if h <= 6 else Blok.RUMPUT
				elif y > h - 4:
					jenis = Blok.PASIR if h <= 6 else Blok.TANAH
				pasang(x, y, z, jenis)
			# Pohon sesekali di atas rumput
			if h > 6 and rng.randf() < 0.012 and x > 1 and z > 1 and x < LEBAR - 2 and z < DALAM - 2:
				var tinggi_batang := 4
				for t in tinggi_batang:
					pasang(x, h + 1 + t, z, Blok.KAYU)
				for dx in range(-2, 3):
					for dz in range(-2, 3):
						for dy in [h + 4, h + 5]:
							if abs(dx) == 2 and abs(dz) == 2 and rng.randf() < 0.6:
								continue
							if ambil(x + dx, dy, z + dz) == Blok.UDARA:
								pasang(x + dx, dy, z + dz, Blok.DAUN)
				pasang(x, h + 6, z, Blok.DAUN)

func bangun_semua() -> void:
	for cx in LEBAR / CHUNK:
		for cz in DALAM / CHUNK:
			_bangun_chunk(Vector2i(cx, cz))

func ubah_balok(sel: Vector3i, jenis: int) -> void:
	pasang(sel.x, sel.y, sel.z, jenis)
	var c := Vector2i(sel.x / CHUNK, sel.y * 0 + sel.z / CHUNK)
	_bangun_chunk(Vector2i(sel.x / CHUNK, sel.z / CHUNK))
	# Balok di tepi chunk memengaruhi tampilan chunk tetangga
	if sel.x % CHUNK == 0 and c.x > 0:
		_bangun_chunk(c + Vector2i(-1, 0))
	if sel.x % CHUNK == CHUNK - 1 and c.x < LEBAR / CHUNK - 1:
		_bangun_chunk(c + Vector2i(1, 0))
	if sel.z % CHUNK == 0 and c.y > 0:
		_bangun_chunk(c + Vector2i(0, -1))
	if sel.z % CHUNK == CHUNK - 1 and c.y < DALAM / CHUNK - 1:
		_bangun_chunk(c + Vector2i(0, 1))

func _bangun_chunk(c: Vector2i) -> void:
	var kunci := c
	if _chunk_mesh.has(kunci):
		(_chunk_mesh[kunci] as Node).queue_free()
		_chunk_mesh.erase(kunci)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idxs := PackedInt32Array()
	var verts_k := PackedVector3Array()
	var normals_k := PackedVector3Array()
	var uvs_k := PackedVector2Array()
	var idxs_k := PackedInt32Array()
	var x0 := c.x * CHUNK
	var z0 := c.y * CHUNK
	for x in range(x0, x0 + CHUNK):
		for z in range(z0, z0 + CHUNK):
			for y in TINGGI:
				var jenis := ambil(x, y, z)
				if jenis == Blok.UDARA:
					continue
				var dasar := Vector3(x, y, z)
				for s in 6:
					var n: Vector3i = SISI[s][0]
					var tetangga := ambil(x + n.x, y + n.y, z + n.z)
					if tetangga != Blok.UDARA and (tetangga == jenis or not Blok.transparan(tetangga)):
						continue
					var ubin: int = Blok.UBIN[jenis][URUTAN_UBIN[s]]
					var uv4: Array = Blok.uv_ubin(ubin)
					var pakai_kaca := jenis == Blok.KACA
					var v_arr := verts_k if pakai_kaca else verts
					var n_arr := normals_k if pakai_kaca else normals
					var u_arr := uvs_k if pakai_kaca else uvs
					var i_arr := idxs_k if pakai_kaca else idxs
					var awal := v_arr.size()
					for k in 4:
						v_arr.append(dasar + (SISI[s][1][k] as Vector3))
						n_arr.append(Vector3(n))
						u_arr.append(uv4[k])
					# Godot: sisi depan = urutan SEARAH jarum jam dari luar.
					for t in [0, 2, 1, 0, 3, 2]:
						i_arr.append(awal + t)
					if pakai_kaca:
						verts_k = v_arr; normals_k = n_arr; uvs_k = u_arr; idxs_k = i_arr
					else:
						verts = v_arr; normals = n_arr; uvs = u_arr; idxs = i_arr
	var mesh := ArrayMesh.new()
	var permukaan: Array = []
	var jumlah_permukaan := 0
	if verts.size() > 0:
		permukaan.resize(Mesh.ARRAY_MAX)
		permukaan[Mesh.ARRAY_VERTEX] = verts
		permukaan[Mesh.ARRAY_NORMAL] = normals
		permukaan[Mesh.ARRAY_TEX_UV] = uvs
		permukaan[Mesh.ARRAY_INDEX] = idxs
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, permukaan)
		mesh.surface_set_material(jumlah_permukaan, _mat_opak)
		jumlah_permukaan += 1
	if verts_k.size() > 0:
		var pk: Array = []
		pk.resize(Mesh.ARRAY_MAX)
		pk[Mesh.ARRAY_VERTEX] = verts_k
		pk[Mesh.ARRAY_NORMAL] = normals_k
		pk[Mesh.ARRAY_TEX_UV] = uvs_k
		pk[Mesh.ARRAY_INDEX] = idxs_k
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, pk)
		mesh.surface_set_material(jumlah_permukaan, _mat_kaca)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)
	_chunk_mesh[kunci] = mi
	# Tabrakan dari semua segitiga kedua permukaan
	var wajah := PackedVector3Array()
	for i in range(0, idxs.size(), 1):
		wajah.append(verts[idxs[i]])
	for i in range(0, idxs_k.size(), 1):
		wajah.append(verts_k[idxs_k[i]])
	if wajah.size() > 0:
		var badan := StaticBody3D.new()
		var bentuk := CollisionShape3D.new()
		var cekung := ConcavePolygonShape3D.new()
		cekung.set_faces(wajah)
		bentuk.shape = cekung
		badan.add_child(bentuk)
		mi.add_child(badan)

## Raycast voxel (algoritma DDA Amanatides & Woo).
## Kembali: {} bila tidak kena; {sel, normal} bila kena balok padat.
func raycast_voxel(asal: Vector3, arah: Vector3, jarak_max: float) -> Dictionary:
	var sel := Vector3i(floori(asal.x), floori(asal.y), floori(asal.z))
	var langkah := Vector3i(signi(arah.x), signi(arah.y), signi(arah.z))
	var delta := Vector3(
		absf(1.0 / arah.x) if arah.x != 0.0 else 1e30,
		absf(1.0 / arah.y) if arah.y != 0.0 else 1e30,
		absf(1.0 / arah.z) if arah.z != 0.0 else 1e30)
	var batas := Vector3(
		(float(sel.x + (1 if langkah.x > 0 else 0)) - asal.x) / arah.x if arah.x != 0.0 else 1e30,
		(float(sel.y + (1 if langkah.y > 0 else 0)) - asal.y) / arah.y if arah.y != 0.0 else 1e30,
		(float(sel.z + (1 if langkah.z > 0 else 0)) - asal.z) / arah.z if arah.z != 0.0 else 1e30)
	var normal := Vector3i.ZERO
	var t := 0.0
	while t <= jarak_max:
		if ambil(sel.x, sel.y, sel.z) != Blok.UDARA:
			return {"sel": sel, "normal": normal}
		if batas.x < batas.y and batas.x < batas.z:
			sel.x += langkah.x
			t = batas.x
			batas.x += delta.x
			normal = Vector3i(-langkah.x, 0, 0)
		elif batas.y < batas.z:
			sel.y += langkah.y
			t = batas.y
			batas.y += delta.y
			normal = Vector3i(0, -langkah.y, 0)
		else:
			sel.z += langkah.z
			t = batas.z
			batas.z += delta.z
			normal = Vector3i(0, 0, -langkah.z)
	return {}

func titik_spawn() -> Vector3:
	var cx := LEBAR / 2
	var cz := DALAM / 2
	for y in range(TINGGI - 1, -1, -1):
		if ambil(cx, y, cz) != Blok.UDARA:
			# Asal pemain = PUSAT kapsul (tinggi 1.8) → permukaan balok + 0.9 + jarak aman
			return Vector3(cx + 0.5, y + 1.0 + 0.95, cz + 0.5)
	return Vector3(cx, 20, cz)
