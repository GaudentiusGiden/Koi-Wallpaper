# Adopsi Nagomi Fase 1: Mode Palet (Classic vs Neon), Pola Corak Spine Matematis & Visual Malam

Tanggal: 30 Oktober 2026 (Asia/Jakarta).  
Status: **Implementasi Selesai & Terverifikasi Penuh** (`KoiWallpaperSimTest` 62/62 lulus; `KoiWallpaperVerify` 68/68 lulus).

---

## 1. Latar Belakang

Berdasarkan hasil pembedahan menyeluruh terhadap aplikasi [Nagomi Desktop v1.0.5](../../nagomi-breakdown/README.md) menggunakan REA, ditemukan beberapa keunggulan visual yang sangat menarik untuk diadopsi ke dalam proyek `KoiWallpaper`:
1. **Palet Warna Terkalibrasi & Mode Neon**: Nagomi memiliki kalibrasi hex autentik untuk varietas koi klasik serta mode palet `.neon` yang menyajikan visual bioluminescent modern.
2. **Pola Corak Tubuh Matematis (`koi-patterns.json`)**: Corak tubuh ikan tidak lagi menggunakan poligon statis, melainkan parameter matematis terarah (`position`, `length`, `width`, `offset`) yang diproyeksikan sepanjang kurva tulang belakang (`spine`) ikan.
3. **Kunang-Kunang Malam Berbasis Lowbias32 (`12-fireflies.wgsl`)**: Partikel cahaya malam menggunakan hash PRNG deterministik, titik awal dari 4 sudut kolam, *lazy wandering sway* 3-frekuensi, serta siklus *periodic flash envelope*.
4. **Ikan Hias Kecil Bercahaya Malam (`tiny-fish/glow.json`)**: Saat tema malam aktif, gerombolan ikan kecil bertransformasi menggunakan palet bioluminescent (cyan, gold, plum, ice pearl) dengan pendaran aura lembut.

Sesuai persetujuan rencana adopsi bertahap pada [Rencana Adopsi Nagomi](../../nagomi-breakdown/README.md), Fase 1 berfokus pada visual, palet warna, dan suasana malam tanpa mengubah fondasi pipeline CoreGraphics/CALayer dan arsitektur simulasi yang sudah ada.

---

## 2. Keputusan Desain & Implementasi Teknis

### 2.1 Mode Palet `Classic` vs `Neon`
- Menambahkan enum `KoiPaletteMode: String, Codable, CaseIterable, Sendable` dengan nilai `.classic` dan `.neon`.
- Menambahkan properti `koiPaletteMode` ke:
  - [`WallpaperSettings`](../../Sources/KoiWallpaperCore/Settings/WallpaperSettings.swift): Tersimpan otomatis ke JSON/UserDefaults dengan backward-compatibility default `.classic`.
  - [`ScreenManager`](../../Sources/KoiWallpaperCore/Desktop/ScreenManager.swift): Menyebarkan mode palet ke seluruh layar dan controller aktif.
  - [`StatusBarController`](../../Sources/KoiWallpaperCore/App/StatusBarController.swift): Menambahkan submenu *"Palet Ikan Koi (Palette)"* dengan pilihan *"Classic (Autentik Jepang)"* dan *"Neon (Bioluminescent)"*.
  - [`AppCoordinator`](../../Sources/KoiWallpaperCore/App/AppCoordinator.swift): Menghubungkan pemilihan menu dengan persistensi `SettingsManager`.

### 2.2 Kalibrasi Hex 8 Varietas & Mode Neon
Diperbarui pada [`KoiVariety.swift`](../../Sources/KoiWallpaperCore/Simulation/KoiVariety.swift):
- **Kohaku**: Classic porcelain white (`#F1EADB`) & crimson hi (`#DC4B2F`); Neon pearl white (`#FFF3E8`) & neon scarlet (`#FF3B5C`).
- **Taisho Sanke**: Classic ivory (`#F2EBDC`), red (`#DF5032`), sumi black (`#20211F`); Neon Ember (`#FF6A2B`, `#FFF0D4`, `#2C0F1B`).
- **Showa Sanshoku**: Classic lacquer black (`#242622`), red (`#D9482E`), cream (`#EEE6D5`); Neon Plum (`#2A1052`, `#FF7AD6`, `#A86BFF`).
- **Yamabuki Ogon**: Classic luminous gold (`#E7AA31`, `#CF7626`); Neon Lantern Gold (`#FFCF3A`, `#FF8A1F`).
- **Asagi**: Classic slate indigo (`#385764`, `#DC4B2F`); Neon Cyber Asagi (`#2F6FF2`, `#FFD23A`, `#0D1F5E`).
- **Shiro Utsuri**: Classic sumi black (`#252825`, `#EAE5DA`); Neon midnight cyan (`#1C3B6E`, `#5FD4FF`).
- **Tancho**: Classic snow white (`#F2EBDC`) & scarlet sun (`#DA4430`); Neon white (`#FFF3E8`) & glowing neon crimson (`#FF3B5C`).
- **Kikusui**: Classic platinum white (`#EAF2F8`) & metallic orange (`#E67E22`); Neon Electric Kikusui (`#EAF6FF`, `#FF6A2B`).

### 2.3 Pola Corak Tubuh Matematis (`KoiPatternPatch`)
- Menambahkan struct `KoiPatternPatch(position, length, width, offset, isSecondaryMarking)`:
  - `position`: `0.0` di moncong hingga `1.0` di pangkal ekor.
  - `length` & `width`: Skala proporsional terhadap ukuran ikan dan ketebalan tubuh.
  - `offset`: Pergeseran lateral sinus terhadap garis tulang punggung (-1.0 kiri s/d +1.0 kanan).
- Di [`KoiArtwork.swift`](../../Sources/KoiWallpaperCore/Rendering/KoiArtwork.swift), koordinat corak dihitung secara dinamis dari titik tulang belakang (`localSpinePoints`), sehingga bercak meliuk mengikuti gerakan renang ikan secara luwes dan ter-clipping sempurna di dalam siluet `torso`.

### 2.4 Kunang-Kunang Malam (Lowbias32) & Glowing Tiny Fish
- [`PondInsect.swift`](../../Sources/KoiWallpaperCore/Simulation/PondInsect.swift):
  - Mengadopsi algoritma `lowbias32` dan `fireflyFlash` dari [`12-fireflies.wgsl`](../../nagomi-breakdown/shaders/12-fireflies.wgsl).
  - Menerapkan *lazy wandering sway* 3-frekuensi (`0.35 rad/s`, `0.85 rad/s`, `1.85 rad/s`) untuk pergerakan melayang santai di udara.
- [`DecorativeFishArtwork.swift`](../../Sources/KoiWallpaperCore/Rendering/DecorativeFishArtwork.swift):
  - Mengintegrasikan preset warna [`tiny-fish/glow.json`](../../nagomi-breakdown/library/presets/tiny-fish/glow.json) saat tema malam (`theme.isNight`):
    - *Cyan Glow* (`#5FF0FF`), *Gold Glow* (`#FFB23A`), *Plum Glow* (`#FF7AD6`), dan *Ice Aqua Glow* (`#EAFFFF`).
  - Menambahkan aura pendaran lembut (*bioluminescent glow aura*) di sekeliling tubuh ikan kecil saat berenang di air gelap.

---

## 3. Bukti Verifikasi & Hasil Pengujian

### 3.1 Test Suite In-Process
- **`KoiWallpaperSimTest`**: Lulus **62 dari 62 tes** (menambahkan seksi uji baru `--- 20. Nagomi Adoption Fase 1 ---`):
  - `T20.1`: Classic & Neon Palettes for 8 Varieties (validasi nilai alpha, kelengkapan warna 8 varietas).
  - `T20.2`: Mathematical Spine Pattern Patches (validasi batas normalisasi, Tancho single forehead sun, Ogon metallic solid).
  - `T20.3`: Firefly Lowbias32 Drift & Sway Kinematics (deterministik RNG, bounds confinement, kurva flash 0..1).
  - `T20.4`: WallpaperSettings & ScreenManager KoiPaletteMode Persistence (roundtrip JSON encode/decode & propagasi).
- **`KoiWallpaperVerify`**: Lulus **68 dari 68 tes** tanpa regresi pada integrasi macOS WindowServer.

### 3.2 Visual Previews
Hasil render visual dapat ditinjau pada:
1. [Perbandingan Palet 8 Varietas Classic vs Neon](../../reports/screenshots/fase1_palette_comparison.png)
2. [Tampilan Kolam Malam dengan Ikan Kecil Bercahaya](../../reports/screenshots/fase1_night_pond.png)

---

## 4. Langkah Berikutnya (Menuju Fase 2)

Setelah Fase 1 selesai secara kokoh, langkah selanjutnya adalah **Fase 2: Kedalaman 3D (Z-Depth) & Kinematika Renang Organik**:
1. Menambahkan simulasi kedalaman `fish.depth` (0.0 permukaan s/d 1.0 dasar kolam) dengan bayangan dinamis dan modulasi penyerapan cahaya air (*underwater tint & dimming*).
2. Menerapkan siklus renang 5-state (`glide, coast, hover, burst, pivot`).
3. Menerapkan 4 gaya pendekatan makanan (`direct, curvedArc, cautious, overshootOrbit`) yang terikat dengan kepribadian `FishTraits`.
