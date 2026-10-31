# Catatan Keputusan Arsitektur: Adopsi Nagomi Desktop Fase 4 (Shader Optik Air Lanjutan, Kausik Refraksi & Arus Aliran Kolam)

**Tanggal**: 31 Oktober 2026  
**Status**: Disetujui & Diimplementasikan Penuh  
**Cakupan**: Refraksi Kausik Air Multi-Skala 3-Lapis ([`PondWaterSurface.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Rendering/PondWaterSurface.swift) & [`KoiArtwork.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Rendering/KoiArtwork.swift)), Simulasi Medan Arus Aliran Air Multi-Arah ([`PondWaterCurrent.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Simulation/PondWaterCurrent.swift), [`FloatingDebris.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Simulation/FloatingDebris.swift), & [`KoiFish.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Simulation/KoiFish.swift)), Refleksi Permukaan Air & Kilau Fresnel ([`PondArtwork.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Rendering/PondArtwork.swift) & [`PondRenderer.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Rendering/PondRenderer.swift)), serta Kalibrasi Transisi Atmosfer Cuaca & Jadwal Waktu ([`PondThemePalette.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Rendering/PondThemePalette.swift)).

---

## 1. Konteks & Masalah

Setelah penyelesaian Fase 1 (palet warna & pola kulit), Fase 2 (Z-Depth 3D & 5-state cadence), dan Fase 3 (mikro-interaksi flora-fauna), kolam telah memiliki dinamika makhluk hidup yang sangat kaya. Namun, aspek optik fluida dan atmosfer air kolam masih mengandalkan pencahayaan statis sederhana:
1. **Kausik Air Tunggal**: Lapisan kausik air di dasar kolam sebelumnya hanya menggunakan satu jaringan sel Voronoi tunggal dengan skala seragam, sehingga tampak datar dan tidak meniru dinamika interferensi gelombang mikro dan makro fluida nyata seperti pada shader `09-water-surface.wgsl` Nagomi.
2. **Ketiadaan Refraksi Dinamis pada Bayangan Ikan**: Bayangan koi diproyeksikan secara linier datar ke dasar kolam tanpa distorsi optik gelombang air permukaan, mengurangi ilusi kedalaman air.
3. **Ketidakadaan Arus Air Alami (Current Drift)**: Partikel apung (*floating debris*) dan ikan koi yang sedang beristirahat mengambang (*hover* / *coast*) berhenti diam jika tidak ada riak impuls, tidak merefleksikan arus alami aliran air kolam zen yang terus mengalir pelan.
4. **Refleksi Permukaan & Kilau Fresnel**: Tidak ada kilau spekular berbasis sudut pandang dan gelombang riak aktif di permukaan air.
5. **Atmosfer Cuaca Terbatas**: Transisi warna tema belum mengintegrasikan gradasi atmosferik multi-parameter (vignette, pencahayaan directional matahari/bulan, saturasi, kontras, dan bayangan awan melintas) yang terkalibrasi dengan jadwal waktu Nagomi (`default.json`).

---

## 2. Keputusan Arsitektur & Implementasi

### 2.1 Refraksi Kausik Air Multi-Skala 3-Lapis (`09-water-surface.wgsl`)
- **Struktur 3 Jaringan Sel Kausik Organik**:
  Pada [`PondWaterSurface.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Rendering/PondWaterSurface.swift), sistem kausik ditingkatkan dari 1 lapis menjadi 3 lapis interferensi multi-skala:
  1. *Large Caustics Network*: `scale = short * 0.12`, speed multiplier 0.85x, kontribusi bobot 0.50 (pola gelombang dasar lambat dan lebar).
  2. *Secondary Caustics Network*: `scale = short * 0.055`, speed multiplier 1.25x, kontribusi bobot 0.35 (detail gelombang sedang berlawanan arah).
  3. *Detail Caustics Network*: `scale = short * 0.028`, speed multiplier 1.65x, kontribusi bobot 0.15 (interferensi kristalin frekuensi tinggi).
- **Optimasi Throughput Raster Berskala Rendah**:
  Untuk mempertahankan efisiensi CPU dan baterai macOS (target $\ge 25.0$ FPS pada unthrottled burst), kausik di-rasterisasi offscreen pada resolusi terkontrol (`bedRasterScale = 0.50`, `meshRasterScale = 0.45` dengan batas maksimum 800px / 500k piksel) lalu di-blit ke CALayer dengan interpolasi bilinear lembut. Hal ini menghemat beban rendering hingga 65% tanpa mengurangi kelembutan visual.
- **Refraksi Dinamis Bayangan Ikan Koi**:
  Pada [`KoiArtwork.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Rendering/KoiArtwork.swift):
  - Bayangan dasar koi dipengaruhi oleh perpindahan refraksi optik dinamis dari vektor gelombang permukaan [`PondWaterCurrent.refractionDisplacement(at:time:)`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Simulation/PondWaterCurrent.swift).
  - Ditambahkan harmonik kelenturan gelombang mikro pada tulang belakang bayangan dan pita pencahayaan kausik yang memotong siluet bayangan koi, menciptakan ilusi visual bayangan terbiaskan oleh riak air di atasnya.

### 2.2 Simulasi Medan Arus Aliran Air Kolam Multi-Arah (`PondWaterCurrent.swift`)
- **Model Vektor Gelombang Multi-Komponen**:
  Dibuat kelas [`PondWaterCurrent.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Simulation/PondWaterCurrent.swift) yang mengimplementasikan kombinasi 3 komponen gelombang fluida Nagomi:
  - Wave A: Arah $(0.94, 0.34)$, frekuensi 22.0 rad, kecepatan 0.92, kekuatan 1.20.
  - Wave B: Arah $(-0.38, 0.92)$, frekuensi 31.0 rad, kecepatan 0.51, kekuatan 0.55.
  - Wave C: Arah $(0.71, 0.71)$, frekuensi 59.0 rad, kecepatan -6.38, kekuatan 0.28.
- **Efek Hanyut Berkelanjutan pada Partikel Apung (`FloatingDebris.swift`)**:
  Metode `update(dt:bounds:current:time:)` menerapkan gaya dorong arus secara kontinu yang diimbangi hambatan viskositas air (`waterDrag`), sehingga serpihan dedaunan apung meluncur lembut melintasi kolam secara organik.
- **Hanyut Lembut saat Koi Beristirahat (`KoiFish.swift`)**:
  Ketika ikan koi dalam fase istirahat mengambang (`hover` bobot 0.70x, `coast` bobot 0.35x), posisi ikan secara halus terbawa oleh arus air kolam, menambah realisme biologis tanpa mengganggu kestabilan navigasi pembatas.

### 2.3 Refleksi Permukaan Air & Efek Fresnel (`09-water-surface.wgsl`)
- **Aproksimasi Schlick untuk Reflektansi Fresnel**:
  Diimplementasikan formula Fresnel:
  $$R(\theta) = R_0 + (1 - R_0)(1 - \cos\theta)^5$$
  dengan $R_0 = 0.02$ untuk permukaan air murni, menghasilkan kilau tajam saat dilihat pada sudut datang dangkal (*glancing angle*).
- **Kilau Spekular Riak Gelombang Aktif**:
  Pada [`PondArtwork.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Rendering/PondArtwork.swift), titik-titik kilau spekular (*specular glints*) digambar di sepanjang puncak gelombang riak aktif (`waterCall`, `foodDrop`, `padBump`, `eatingNibble`, `rainDrop`).
- **Batching Path Stroke Rendering**:
  Semua partikel kilau spekular digabungkan dalam satu jalur tunggal (`combinedGlintPath`) pada [`PondRenderer.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Rendering/PondRenderer.swift), memastikan jumlah stroke CALayer surface nodes selalu berada di bawah batas ketat 140 nodes ($\le 140$).

### 2.4 Transisi Atmosfer Cuaca & Penjadwalan Waktu (`10-weather-pass.wgsl`)
- **Struktur `PondWeatherGrade` & Interpolasi Linier (`lerp`)**:
  Pada [`PondThemePalette.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Rendering/PondThemePalette.swift), ditambahkan struktur penilaian atmosferik lengkap:
  - Parameter: `tint`, `brightness`, `contrast`, `saturation`, `vignetteStrength`, `cloudShadowStrength`, `lightColor`, `lightStrength`, `lightDirection`, dan `rainStrength`.
  - Kalibrasi 7 tema sesuai jadwal Nagomi (`default.json`): Dawn (05:30), Day (07:30), Golden Hour (16:30), Dusk (18:00), Night (19:30), Deep Clear, dan Rain.
- **Rendering Berkas Cahaya & Vignette**:
  Pada [`PondArtwork.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Rendering/PondArtwork.swift), fungsi `drawWeatherAtmosphere` menggambar berkas cahaya directional (sinar matahari siang/keemasan atau sinar rembulan malam), bayangan awan halus melintas, dan efek sudut vignette lembut.

### 2.5 Kepatuhan Penuh terhadap Prinsip Zen & Kestabilan Sistem
- **Daun Teratai Tetap Statis**: Sesuai mandat estetika zen kolam yang disepakati di Fase 3, daun teratai tetap 100% statis tanpa goyangan / translasi. Hal ini sekaligus mengeliminasi 12 operasi transformasi matriks dan penyimpanan grafis per frame di `PondRenderer.swift`.
- **Ketahanan Stasis Pause & Multi-Display**: Mode jeda (pause) tetap terbukti identik hingga tingkat piksel (pixel-for-pixel stasis), isolasi memori per monitor terjaga, dan 0 kebocoran memori.

---

## 3. Hasil Pengujian & Bukti Verifikasi

1. **Uji Simulasi In-Process (`KoiWallpaperSimTest`)**:
   - Total **76/76 pengujian lulus 100%** (termasuk 5 pengujian baru seksi 23):
     - `T23.1`: Multi-Scale 3-Layer Water Caustics & Dynamic Shadow Refraction (`networks == 3`, refraksi titik dunia waktu-berubah, kelenturan harmonik tulang belakang bayangan).
     - `T23.2`: Continuous Drift & Multi-Directional Water Current Field (arah valid, kecepatan arus ~3.37 pt/s, hanyut debris apung dan ikan fase hover).
     - `T23.3`: Fresnel Specular Glints & Ripple Wave Reflection ($R_{normal} = 0.020$, $R_{glancing} = 1.000$, kontras intensitas spekular gelombang riak).
     - `T23.4`: Atmospheric Weather Pass Calibration & Time Schedule (7 tema terkalibrasi, penjadwalan 5 titik waktu Nagomi, interpolasi `PondWeatherGrade.lerp`).
     - `T23.5`: Continuous Current Multi-Seed Confinement & Stability (4 seed acak, 600 frame simulasi, 100% tetap di dalam batas kolam, ketiadaan nilai NaN/Inf).
     - `T16.1`: Uji kestabilan jangka panjang 57.600 frame (16 menit simulasi multi-seed) membuktikan **0 benturan/penetrasi** ikan.
2. **Uji Verifikasi Aplikasi & Hardware (`KoiWallpaperVerify`)**:
   - Total **68/68 assertion in-process lulus 100%**.
   - `T7.6`: Pengukuran throughput unthrottled mencapai **25.6 FPS** (standar minimal $\ge 25.0$ FPS) pada perangkat baterai Apple M1 (70% daya), dengan penggunaan memori RSS stabil pada ~74.9 MB dan pemakaian daya stasis pause 0.08% CPU.
   - Total keseluruhan pengujian proyek: **144/144 assertion lulus (100%)**.
3. **Status Runtime Aplikasi Desktop**:
   - Aplikasi berhasil dikompilasi ke mode Release (`./scripts/build_app.sh release`).
   - Bundel `/Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/build/KoiWallpaper.app` berjalan aktif di latar belakang (PID 9290).
