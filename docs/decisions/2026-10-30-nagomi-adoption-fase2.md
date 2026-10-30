# Catatan Keputusan Arsitektur: Adopsi Nagomi Desktop Fase 2 (Z-Depth & Kinematika Renang Organik)

**Tanggal**: 30 Oktober 2026  
**Status**: Disetujui & Diimplementasikan Penuh  
**Cakupan**: Simulasi Menyelam 3D (`depth: 0.0...1.0`), Modulasi Visual Kedalaman Air & Z-Sorting, Siklus Renang 5-State (`KoiSwimCadence`), dan 4 Gaya Pendekatan Target (`KoiApproachStyle`) Berbasis `FishTraits`.

---

## 1. Konteks & Masalah

Pada Fase 1, kita telah menyelesaikan kalibrasi warna 8 varietas, pola corak tubuh matematis yang lentur mengikuti kurva tulang belakang (`spine`), serta atmosfer malam dengan kunang-kunang `lowbias32` dan ikan kecil berpendar. Namun pada Fase 1, simulasi renang koi masih berada pada bidang 2D datar murni:
1. Seluruh ikan tampak berada pada tingkat kedalaman air yang sama persis, tanpa variasi visual kedalaman (bayangan selalu berada pada jarak offset konstan dan kecerahan tubuh seragam).
2. Ketika dua ikan saling melintas, tidak ada hierarki kedalaman (siapa di atas dan siapa di bawah) selain urutan indeks array bawaan.
3. Gerakan renang berkeliaran (`wandering`) hanya mengandalkan kecepatan datar konstan dan variasi frekuensi sinus kecil, tanpa ritme alami ikan nyata (meluncur tenang, mengapung mengamati, hentakan dorongan, atau belokan tajam).
4. Saat menghampiri makanan atau riak klik, semua ikan bergerak dengan gaya lintasan yang sama.

Mengacu pada dekonstruksi aplikasi **Nagomi Desktop v1.0.5** (`analysis/desktop-breakdown/library/presets/koi/default.json`), Nagomi menggunakan parameter kedalaman air yang sangat kaya, siklus renang 5-state, dan parameter pendekatan multi-gaya. Tujuan Fase 2 adalah mengadopsi seluruh fitur kinematika dan kedalaman ini ke dalam arsitektur CoreGraphics dan simulasi Swift native tanpa merusak performa deterministik atau pengujian yang sudah ada.

---

## 2. Keputusan Arsitektur & Implementasi

### 2.1 Simulasi Menyelam 3D (`depth: 0.0...1.0`)
- **Model Data**: Ditambahkan ke [`KoiFish.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Simulation/KoiFish.swift):
  - `depth: Double` (nilai `0.0` = tepat di permukaan air, `1.0` = dasar kolam / deep bed).
  - `targetDepth: Double`, `depthStateTimer: Double`, dan `depthTransitionDuration: Double`.
  - Inisialisasi awal mengambil rentang acak `[0.05, 0.18]` sesuai spesifikasi Nagomi.
- **Karakteristik Kepribadian (`boldness`)**:
  - Ikan dengan `traits.boldness >= 0.60` (pemberani, misal Kohaku, Ogon, Showa) memiliki peluang 75% berada di lapisan dangkal `shallowRange [0.04, 0.22]` dengan durasi lebih lama (`8–22 detik`).
  - Ikan pemalu (`boldness < 0.60`, misal Asagi) lebih sering menyelam ke lapisan dalam `deepRange [0.45, 0.75]` selama `4–10 detik`.
  - Waktu transisi menyelam/naik berkisar antara `2–5 detik` secara mulus.
- **Stimulus Panggilan & Makan**:
  - Saat ada makanan dilempar (`seekingFood`) atau air diklik (`investigatingClick`), `targetDepth` ikan seketika ditargetkan ke permukaan (`callRiseDepth = 0.035`) dengan durasi respons `2.4 detik` (`callRiseSeconds`).

### 2.2 Modulasi Visual Kedalaman Air (Visual Water Absorption)
Diimplementasikan pada [`KoiArtwork.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Rendering/KoiArtwork.swift) dan [`PondRenderer.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Rendering/PondRenderer.swift):
1. **Bayangan Dinamis**:
   - Offset bayangan bergeser mendekat ke bawah tubuh ikan saat menyelam:
     $$\text{shadowOffset} = \text{baseOffset} + \begin{pmatrix} -3.0 \\ -7.0 \end{pmatrix} \times \frac{\text{length}}{48.0} \times \text{depth}$$
   - Opasitas bayangan menjadi lebih pekat saat mendekati dasar kolam:
     $$\alpha = \alpha_{\text{style}} \times \frac{0.38 + (0.56 - 0.38) \times \text{depth}}{0.38}$$
2. **Penyerapan Cahaya Air**:
   - Fungsi `applyDepthWaterAbsorption(to:depth:)` diterapkan pada seluruh lapisan warna tubuh, corak, sirip, aksen, dan mata ikan:
   - Antara kedalaman `visualStart = 0.10` hingga `visualEnd = 0.72`:
     - Kecerahan (*brightness*) meredup menuju `0.59`.
     - Saturasi warna menurun menuju `0.76`.
     - Dicampurkan dengan warna air dalam `deepWaterTint [0.66, 0.84, 0.80]`.
3. **Z-Depth Sorting**:
   - Pada [`PondRenderer.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Rendering/PondRenderer.swift), entitas ikan diurutkan berdasarkan kedalaman menurun:
     ```swift
     let sortedFish = simulation.fish.sorted { $0.depth > $1.depth }
     ```
   - Bayangan dan tubuh ikan terdalam digambar terlebih dahulu, sehingga ikan yang berada di permukaan selalu melintas di atas ikan yang sedang menyelam.

### 2.3 Siklus Renang 5-State (`KoiSwimCadence`)
Ditambahkan enum `KoiSwimCadence: String, CaseIterable, Sendable` pada [`KoiFish.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Simulation/KoiFish.swift):
- **Glide (`1.7–5.2s`)**: Kecepatan normal (`baseSpeed`), kibasan ekor standar.
- **Coast (`0.7–2.1s`)**: Melambat ke `0.30x` kecepatan dasar sambil meluncur lurus (`wiggleRate` berkurang).
- **Hover (`0.65–3.1s`)**: Mengapung tenang nyaris berhenti (`0.08x`), kibasan sirip lambat (`idleBeatRate = 0.45`).
- **Burst (`0.32–0.92s`)**: Akselerasi dorongan singkat (`1.55x`), kibasan ekor cepat (`1.5x`). Ditekan secara cerdas saat ada tetangga dekat untuk menjaga ketiadaan benturan.
- **Pivot (`0.5–1.1s` / `0.3–0.78s` saat playful)**: Belokan tajam dengan pengali turn rate `1.4x–1.8x` dan penyesuaian kelenturan tubuh.

### 2.4 Empat Gaya Menghampiri Target (`KoiApproachStyle`)
Ditambahkan enum `KoiApproachStyle: String, CaseIterable, Sendable` pada [`KoiFish.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Simulation/KoiFish.swift), dipetakan secara alami dari `FishTraits`:
- **Direct**: Ikan sangat rakus (`feedingEagerness >= 0.80`, misal *Kohaku, Showa Sanshoku, Yamabuki Ogon*) melaju lurus tanpa ragu.
- **Curved Arc**: Ikan dengan sifat seimbang (*Taisho Sanke, Shiro Utsuri, Tancho*) mengambil lintasan kurva anggun dengan gelombang sinus lateral.
- **Cautious**: Ikan pemalu (*Asagi*, `boldness < 0.55`) melambat ke `0.75x` saat mendekati target dan berhenti sejenak mengamati sebelum menyambar.
- **Overshoot & Orbit**: Ikan sangat lincah (*Kikusui*, `agility >= 1.10`) melesat melewati target sedikit (`1.10x`), lalu berputar mengorbit ke target.

---

## 3. Hasil Pengujian & Bukti Verifikasi

1. **Uji Simulasi In-Process (`KoiWallpaperSimTest`)**:
   - Seluruh **66/66 pengujian lulus 100%**:
     - `T21.1`: Simulasi Z-Depth, preferensi kedalaman boldness, dan call rise ke permukaan air `0.035` saat makan.
     - `T21.2`: Siklus 5 cadence (`glide`, `coast`, `hover`, `burst`, `pivot`) terbukti seluruhnya terjangkau dan termodulasi secara dinamis.
     - `T21.3`: Pemetaan 4 gaya pendekatan terhadap kepribadian varietas koi terverifikasi presisi.
     - `T21.4`: Modulasi penyerapan cahaya air dalam dan sorting render descending terverifikasi.
     - `T16.1`: Uji kestabilan 57.600 frame (16 menit simulasi multi-seed) tetap mencatat **0 penetrasi** dengan clearance kapsul positif.
2. **Uji Verifikasi Aplikasi (`KoiWallpaperVerify`)**:
   - Seluruh **68/68 assertion in-process lulus 100%**.
   - Total pengujian otomatis: **134/134 test passed**.
3. **Artefak Visual**:
   - `reports/screenshots/fase2_zdepth_visuals.png`: Perbandingan visual kedalaman `depth = 0.04`, `0.25`, `0.50`, dan `0.75`.
   - `reports/screenshots/fase2_zsorting_overlap.png`: Demonstrasi Z-sorting bertingkat 3 ikan yang bersilangan.
