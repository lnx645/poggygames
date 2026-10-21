class_name Blok
## Definisi jenis balok + pembuatan tekstur atlas prosedural (tanpa aset luar).
## Atlas: kisi 4x4 ubin @64px di citra 256x256. Indeks ubin per jenis balok:
## [atas, bawah, samping].

const UDARA := 0
const RUMPUT := 1
const TANAH := 2
const BATU := 3
const PASIR := 4
const KAYU := 5
const DAUN := 6
const PAPAN := 7
const KACA := 8
const BATA := 9

const NAMA := {
	RUMPUT: "Rumput", TANAH: "Tanah", BATU: "Batu", PASIR: "Pasir",
	KAYU: "Batang Kayu", DAUN: "Daun", PAPAN: "Papan Kayu", KACA: "Kaca", BATA: "Bata",
}

# Indeks ubin dalam atlas untuk [atas, bawah, samping]
const UBIN := {
	RUMPUT: [0, 1, 2],
	TANAH: [1, 1, 1],
	BATU: [3, 3, 3],
	PASIR: [4, 4, 4],
	KAYU: [6, 6, 5],
	DAUN: [7, 7, 7],
	PAPAN: [8, 8, 8],
	KACA: [9, 9, 9],
	BATA: [10, 10, 10],
}

const UK_UBIN := 64
const KOLOM := 4

static func transparan(jenis: int) -> bool:
	return jenis == UDARA or jenis == KACA

static func _tabur(img: Image, x0: int, y0: int, dasar: Color, variasi: float, rng: RandomNumberGenerator) -> void:
	for y in UK_UBIN:
		for x in UK_UBIN:
			var v := rng.randf_range(-variasi, variasi)
			img.set_pixel(x0 + x, y0 + y, Color(
				clampf(dasar.r + v, 0.0, 1.0),
				clampf(dasar.g + v, 0.0, 1.0),
				clampf(dasar.b + v, 0.0, 1.0), dasar.a))

static func _pos(kolom: int, baris: int) -> Vector2i:
	return Vector2i(kolom * UK_UBIN, baris * UK_UBIN)

static func buat_atlas() -> Texture2D:
	var img := Image.create(KOLOM * UK_UBIN, KOLOM * UK_UBIN, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261021
	# 0 rumput atas (hijau)
	var p := _pos(0, 0)
	_tabur(img, p.x, p.y, Color(0.35, 0.62, 0.22), 0.06, rng)
	# 1 tanah (cokelat)
	p = _pos(1, 0)
	_tabur(img, p.x, p.y, Color(0.5, 0.35, 0.2), 0.05, rng)
	# 2 rumput samping (tanah + pita hijau di atas)
	p = _pos(2, 0)
	_tabur(img, p.x, p.y, Color(0.5, 0.35, 0.2), 0.05, rng)
	for x in UK_UBIN:
		for y in 14:
			var v := rng.randf_range(-0.05, 0.05)
			img.set_pixel(p.x + x, p.y + y, Color(0.35 + v, 0.62 + v, 0.22 + v))
	# 3 batu (abu)
	p = _pos(3, 0)
	_tabur(img, p.x, p.y, Color(0.5, 0.5, 0.52), 0.05, rng)
	# 4 pasir
	p = _pos(0, 1)
	_tabur(img, p.x, p.y, Color(0.85, 0.78, 0.55), 0.04, rng)
	# 5 batang kayu samping (garis vertikal kulit)
	p = _pos(1, 1)
	_tabur(img, p.x, p.y, Color(0.4, 0.3, 0.16), 0.05, rng)
	for x in UK_UBIN:
		if x % 10 < 2:
			for y in UK_UBIN:
				img.set_pixel(p.x + x, p.y + y, Color(0.3, 0.22, 0.11))
	# 6 ujung batang kayu (lingkaran tahun)
	p = _pos(2, 1)
	_tabur(img, p.x, p.y, Color(0.72, 0.58, 0.36), 0.03, rng)
	for y in UK_UBIN:
		for x in UK_UBIN:
			var d := Vector2(x - 32, y - 32).length()
			if int(d) % 9 == 0:
				img.set_pixel(p.x + x, p.y + y, Color(0.55, 0.42, 0.24))
	# 7 daun (hijau pekat berpori)
	p = _pos(3, 1)
	_tabur(img, p.x, p.y, Color(0.2, 0.45, 0.15), 0.09, rng)
	# 8 papan kayu (garis horizontal)
	p = _pos(0, 2)
	_tabur(img, p.x, p.y, Color(0.66, 0.5, 0.3), 0.04, rng)
	for y in UK_UBIN:
		if y % 16 == 0:
			for x in UK_UBIN:
				img.set_pixel(p.x + x, p.y + y, Color(0.45, 0.33, 0.18))
	# 9 kaca (bingkai terang, isi nyaris bening)
	p = _pos(1, 2)
	for y in UK_UBIN:
		for x in UK_UBIN:
			var tepi := x == 0 or y == 0 or x == UK_UBIN - 1 or y == UK_UBIN - 1
			img.set_pixel(p.x + x, p.y + y, Color(0.85, 0.95, 1.0, 1.0) if tepi else Color(0.8, 0.92, 1.0, 0.25))
	for i in 18:
		img.set_pixel(p.x + 10 + i, p.y + 40 - i, Color(0.95, 1.0, 1.0, 0.5))
	# 10 bata (baris bata merah + semen)
	p = _pos(2, 2)
	_tabur(img, p.x, p.y, Color(0.78, 0.75, 0.72), 0.02, rng)
	for baris in 4:
		var y0 := baris * 16
		var geser := 16 if baris % 2 == 1 else 0
		for kolom in 2:
			var x0 := kolom * 32 + geser - 16
			for y in range(2, 14):
				for x in range(2, 30):
					var xx := x0 + x
					if xx >= 0 and xx < UK_UBIN:
						var v := rng.randf_range(-0.04, 0.04)
						img.set_pixel(p.x + xx, p.y + y0 + y, Color(0.62 + v, 0.25 + v, 0.2 + v))
	return ImageTexture.create_from_image(img)

static func uv_ubin(indeks: int) -> Array:
	# Empat sudut UV ubin (kiri-bawah, kanan-bawah, kanan-atas, kiri-atas)
	var kx := float(indeks % KOLOM) / KOLOM
	var ky := float(indeks / KOLOM) / KOLOM
	var s := 1.0 / KOLOM
	var pad := 0.002
	return [
		Vector2(kx + pad, ky + s - pad),
		Vector2(kx + s - pad, ky + s - pad),
		Vector2(kx + s - pad, ky + pad),
		Vector2(kx + pad, ky + pad),
	]
