# Catatan Keputusan Arsitektur: Adopsi Nagomi Desktop Fase 3 (Micro-Interactions Ekosistem & Arsitektur Hybrid Flora)

**Tanggal**: 30 Oktober 2026  
**Status**: Disetujui & Diimplementasikan Penuh (dengan Amandemen Daun Teratai Statis)  
**Cakupan**: Hybrid [`PondLilyPad.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Simulation/PondLilyPad.swift) & Arsitektur Teratai Statis, Katak Kaget & Melompat Antar-Teratai ([`PondFrog.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Simulation/PondFrog.swift)), Ikan Kecil Mencuri Makanan / `tinyFishSteal` ([`FoodPellet.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Simulation/FoodPellet.swift) & [`DecorativeSchool.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Simulation/DecorativeSchool.swift)), Kupu-Kupu Mengorbit & Hinggap di Bunga Teratai ([`PondInsect.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Simulation/PondInsect.swift)), serta 5 Tipe Riak Lengkap & Gelombang Dorong Partikel Apung ([`WaterRipple.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Simulation/WaterRipple.swift) & [`FloatingDebris.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Simulation/FloatingDebris.swift)).

---

## 1. Konteks & Masalah

Setelah menyelesaikan Fase 1 (palet, pola spine, dan kunang-kunang) serta Fase 2 (Z-Depth 3D, siklus 5 cadence, dan 4 gaya renang), kolam telah memiliki kedalaman optik dan renang yang luwes. Namun, elemen ekosistem lainnya masih berjalan secara independen tanpa mikro-interaksi organik:
1. Daun teratai (*water lily pads*) belum terpetakan dalam model data spasial mandiri sehingga sulit dijadikan acuan koordinat bagi lompatan katak dan hinggapan serangga.
2. Katak pohon (*Nihon Amagaeru*) yang hinggap di daun teratai hanya memiliki satu lokasi hinggap tetap dan siklus lompat tunggal ke air.
3. Ikan kecil dekoratif (*medaka*) mengabaikan pelet makanan yang jatuh, meskipun di aplikasi referensi Nagomi terdapat dinamika serbuan ikan kecil (`tinyFishSteal`).
4. Kupu-kupu hanya berkeliaran di udara tanpa pernah mendekati, mengorbit, atau hinggap di 4 bunga teratai merah muda.
5. Dedaunan apu-apu dan serpihan musiman (*floating debris*) belum merespons gelombang riak secara diferensial berdasarkan tipe riak air.

---

## 2. Keputusan Arsitektur & Implementasi

### 2.1 Arsitektur Hybrid `PondLilyPad` & Daun Teratai Statis
- **Keputusan Estetika & Stabilitas (Amandemen Pengguna)**: Goyangan daun teratai (*wobble/displacement*) dihilangkan agar daun teratai tetap statis seperti sebelumnya. Hal ini menjaga estetika zen kolam yang tenang, mencegah distorsi bitmap kluster flora, dan memastikan daun teratai tetap terjangkar kokoh di garis pantai.
- **Model Simulasi Spasial**: Dibuat [`PondLilyPad.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Simulation/PondLilyPad.swift) yang merepresentasikan ke-16 daun teratai kolam (4 di antaranya membawa bunga teratai mekar):
  - Memetakan koordinat dunia `(x, y)` dan radius daun secara proporsional terhadap ukuran kolam sesuai geometri [`PondFloraArtwork.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Rendering/PondFloraArtwork.swift).
  - Mengimplementasikan `contactCooldown: Double` (`contactCooldownSeconds = 0.6s`) untuk men-debounce kontak benturan tanpa menggeser posisi fisik daun (`displacementOffset == .zero`, `currentWobbleAngle == 0.0`).
- **Deteksi Kontak Permukaan (`PondSimulation.swift`)**:
  - Saat koi berenang di dekat permukaan air (`depth < 0.25`), kontak fisik moncong/tubuh dengan daun teratai memicu riak `.padBump` dan peluang katak kaget melalui `contactCooldown`. Daun teratai itu sendiri tetap diam dan stabil tak bergerak.
- **Rendering Bersih**:
  - Pada [`PondRenderer.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Rendering/PondRenderer.swift), fungsi `animateFlora` mempertahankan gerak ayunan angin alami yang sangat halus tanpa translasi sentakan benturan koi.
  - [`PondFloraArtwork.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Rendering/PondFloraArtwork.swift) menggambar daun teratai secara statis dan elegan.

### 2.2 Katak Kaget & Melompat Antar-Teratai (`PondFrog.swift`)
- Ditambahkan state `.hoppingToPad` pada `PondFrogState`.
- Ketika daun teratai tempat katak bertengger tersenggol koi:
  - Dijalankan evaluasi probabilistik 40% (`bumpStartleChance = 0.40`).
  - Katak mendeteksi daun teratai tetangga terdekat dalam radius jelajah (`hopRange = 70.0pt`).
  - Katak melompat parabolik (apex ~18pt, durasi `hopSeconds = 0.50s`) dengan siluet kaki terentang menuju teratai tetangga, mendarat dengan bantalan membal (*squash-and-stretch*), lalu menetap di daun baru tersebut.

### 2.3 Serbuan Ikan Kecil Mencuri Makanan (`tinyFishSteal`)
- Pada [`FoodPellet.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Simulation/FoodPellet.swift):
  - Ditambahkan properti `bitesRemaining: Double` (rentang 1.0–3.0 per pelet).
  - Metode `takeBite(amount: 0.35)` yang mengurangi porsi pelet dan menandai `isConsumed = true` saat habis ($\le 0.05$).
- Pada [`DecorativeSchool.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Simulation/DecorativeSchool.swift) & [`PondSimulation.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Simulation/PondSimulation.swift):
  - Jika pelet berada dalam radius 70pt (`tinyFishStealRadius = 70.0pt`), terdapat peluang 55% (`tinyFishStealChance = 0.55`) beberapa ikan kecil dekoratif melesat menyerbu pelet (kecepatan serbu ~62–78 pt/s).
  - Saat mencapai makanan, ikan kecil memakan porsi 0.35 dan memicu riak halus `.eatingNibble`.

### 2.4 Kupu-Kupu Mengorbit & Hinggap di Bunga Teratai (`PondInsect.swift`)
- Ditambahkan 4 state perilaku kupu-kupu (`ButterflyState`):
  - `.wandering`: Terbang meliuk santai melintasi kolam.
  - `.approaching`: Setelah timer berkeliaran habis (peluang 92%), kupu-kupu menargetkan salah satu dari 4 bunga teratai mekar dan meluncur turun mendekat (`speed = 18.0pt/s`).
  - `.orbiting`: Mengorbit melingkari kelopak bunga teratai dengan radius `[7, 12]pt` dan kecepatan sudut `[0.9, 1.5] rad/s` selama 2.2–4.6 detik.
  - `.resting`: Hinggap beristirahat tepat di atas kelopak bunga teratai (`altitude = 0.06`), melipat sayap perlahan selama 0.8–1.8 detik sebelum terbang kembali.

### 2.5 Kelengkapan 5 Tipe Riak & Dorongan Gelombang Partikel Apung
- [`WaterRipple.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Simulation/WaterRipple.swift) kini memiliki 5 varian lengkap:
  1. `.waterCall`: Klik reguler / sentuhan air (cyan splash).
  2. `.foodDrop`: Lemparan makanan Option+klik (oranye cerah).
  3. `.eatingNibble`: Gigitan makan koi / curian ikan kecil (cincin putih-cyan lembut).
  4. `.rainDrop`: Tetesan air hujan atmosferik (cincin perak reflektif).
  5. `.padBump`: Senggolan koi ke daun teratai (gelombang pirus zamrud).
- [`FloatingDebris.swift`](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/Sources/KoiWallpaperCore/Simulation/FloatingDebris.swift):
  - Mengimplementasikan `applyRippleImpulse(...)` sesuai spesifikasi Nagomi duckweed:
    - Bobot riak: `rainDrop = 1.4`, `waterCall = 0.8`, `eatingNibble = 0.8`, `foodDrop = 0.6`, `padBump = 0.5`.
    - Menghitung dorongan radial outward dan putaran spin acak terkalibrasi (`spin: 0.39`).

---

## 3. Hasil Pengujian & Bukti Verifikasi

1. **Uji Simulasi In-Process (`KoiWallpaperSimTest`)**:
   - Seluruh **71/71 pengujian lulus 100%**:
     - `T22.1`: Inisialisasi 16 pad, 4 bunga, garansi kestabilan teratai statis tanpa translasi/rotasi, dan debouncing kontak.
     - `T22.2`: Katak kaget senggolan teratai (peluang 40%), deteksi tetangga radius 70pt, lompatan parabolik, dan pendaratan.
     - `T22.3`: Dinamika pelet `bitesRemaining`, serbuan ikan kecil radius 70pt (peluang 55%), pengurangan gigitan 0.35, dan riak `.eatingNibble`.
     - `T22.4`: Siklus 4-state kupu-kupu (`wandering`, `approaching`, `orbiting 7–12pt`, `resting`).
     - `T22.5`: Kelengkapan 5 varian `RippleType` dan dorongan gelombang `applyRippleImpulse` pada serpihan apung.
     - `T16.1`: Uji kestabilan 57.600 frame (16 menit simulasi multi-seed) tetap mencatat **0 penetrasi** dengan clearance kapsul positif.
2. **Uji Verifikasi Aplikasi (`KoiWallpaperVerify`)**:
   - Seluruh **68/68 assertion in-process lulus 100%**.
   - Total pengujian otomatis: **139/139 test passed**.
3. **Status Runtime Aplikasi Desktop**:
   - App Release berhasil di-build (`build/KoiWallpaper.app`) dan berjalan aktif di latar belakang.
