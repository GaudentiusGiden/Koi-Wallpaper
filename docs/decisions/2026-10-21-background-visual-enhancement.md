# Cahaya dan bayangan kolam mengikuti acuan REA

Tanggal: 21 Oktober 2026 (Asia/Jakarta).  
Status: Diterapkan; hasil verifikasi dicatat di bawah.

## Acuan dan cara membandingkan

Acuan utama adalah [fullscreen REA](../../analysis/rea/nagomi/screenshots/fullscreen-visible.png). [Review interaktif](../../reports/water-shadow-review.html) menampilkan acuan, keadaan working tree sebelum revisi ini, hasil akhir pada viewport 1280 × 1000 yang sama, empat fase waktu, dan screenshot preview native terbaru. Render sebelum/sesudah memakai seed 42 dan 12 detik waktu aktif. Posisi ikan berbeda dari screenshot referensi karena mengikuti simulasi sendiri.

Artwork aplikasi tetap dihasilkan oleh CoreGraphics. Gambar referensi dipakai untuk penilaian visual.

## Perubahan

- `PondArtwork.drawWater` memakai gradien kedalaman lima stop dengan nada jade/teal yang lebih dalam di tepian, sorotan mint lebar pada bukaan atas, dan berkas cahaya diagonal di kiri. Area sudut terlindung (di bawah kelompok vegetasi tepi) memiliki nuansa halus hijau-olive organik (`oliveColor`), sementara jalur cahaya dan bagian tengah kolam tetap terbuka dan lebih terang tanpa membentuk vignette melingkar yang seragam. Warna serta intensitas menyesuaikan fase Day, Dawn, Dusk, dan Night tanpa membuat air tampak berlumpur.
- Sebanyak 2.800 flek sedimen berseed dibangun bersama cache dasar. Flek gelap dan mineral terang mempunyai variasi sesuai pencahayaan; tekstur tidak diacak setiap frame.
- `PondLighting` menyatukan arah bayangan dalam koordinat dunia: kanan-bawah, vektor `(0.60, -0.80)` pada koordinat artwork Y-up. Koi dan ikan kecil memakai jarak 28% panjang tubuh; teratai 44% radius daun. Arah cahaya konsisten dari kiri-atas jatuh ke kanan-bawah.
- Bayangan dasar diperjelas dengan ilusi proyeksi ke dasar kolam melalui sistem penumbra bertingkat pixel-art (pelemahan dan pelebaran tipis ~14% pada grid integer) dan umbra inti, tanpa blur halus yang menyerupai outline atau glow. Caustics air tetap terlihat meredup secara wajar di bawah bayangan.
- Palet dan intensitas bayangan (`PondLighting.shadowStyle`) disesuaikan per fase: Day (siluet gelap kehijauan/dark jade), Dawn (aksen lumut hangat), Dusk (slate indigo-jade), dan Night (midnight navy transparan), menjaga air tetap jernih dan tidak berlumpur di bagian tengah kolam.
- Bayangan ikan kecil (dekoratif) dibuat lebih ringan daripada koi dan digambar sebelum tubuh ikan dalam satu sekolah, memastikan seluruh bayangan berada strictly di bawah objek yang menaunginya.
- Bayangan koi menyertakan tubuh, ekor, dan sirip dada yang mengikuti gerak dinamis ikan. Overlap sirip dan torso mempertahankan winding yang sama tanpa artefak lubang atau kedipan.
- Offset bayangan ikan kecil dikonversi dari arah dunia ke koordinat ikan yang sudah diputar. Offset tanaman dicerminkan balik pada kelompok vegetasi sisi kanan. Cache flora diperbarui saat fase berubah tanpa menghasilkan tekstur per frame saat runtime stabil.
- `PondWaterSurface` membagi goresan caustics ke empat kelompok eksposur saat cache dibuat. Pola lebih terang di bukaan atas dan berkas kiri, serta lebih redup di air dalam. Titik terang seragam pada pertemuan garis dihilangkan. Pengelompokan ini tidak menambah tekstur mask atau layer native.

## Batas biaya render

Cache tetap terdiri dari dasar dan dua jaringan caustics, masing-masing dibatasi sisi 1536 pixel / 2,25 megapixel. Analisis pencahayaan dan tessellation hanya terjadi ketika ukuran, skala, atau fase berubah. Tidak ada timer atau animasi mandiri baru; seluruh gerak visual masih mengikuti waktu aktif simulasi.

Jalur native memakai filtering linear yang sudah tersedia pada `PondSceneLayer`. Percobaan filtering pada ekspor CoreGraphics menurunkan throughput menjadi 22,7–22,8 FPS; sampling ekspor dikembalikan ke metode sebelumnya. Ambang verifier tidak diubah.

## Verifikasi

- `swift run KoiWallpaperVerify`: **32/32 lulus**, termasuk freeze byte-identical saat pause, resume clamp, preservasi dunia antar fase, batas layer, serta grid pixel dan input overlay.
- `swift run KoiWallpaperSimTest`: **19/19 lulus**.
- T7.7, Apple M1 pada Retina 2×: p95 persiapan frame dan pengiriman layer **1,34 ms** untuk preview 1024 × 640 pt (anggaran 16,67 ms) dan **1,36 ms** untuk desktop 1680 × 1050 pt (anggaran 33,33 ms).
- T7.6 pada Battery Power 34%: cadence timer desktop **29,7 Hz**, RSS **113,17 MB**, throughput ekspor CoreGraphics **40,1 FPS**, serta CPU pause **0,07%**.
- T7.10: vegetasi opak **21,24%** dan area tengah terbuka **97,76%**, masih dalam target komposisi.
- Build release `build/KoiWallpaper.app` berhasil; arsitektur **arm64** dan tanda tangan ad-hoc.
- Review native `KoiWallpaperPreview --review-style` selesai dengan exit code 0. Cadence pengiriman scene **59,5 Hz**; screenshot awal dan akhir diperiksa, termasuk bayangan objek serta respons interaksi. Rekaman lokal berada di `build/visual-review/native-preview.mov`.
- Render Day, Dawn, Dusk, dan Night diperiksa pada viewport 1280 × 1000. [Screenshot native terbaru](../../reports/screenshots/water_shadow_native_preview.png) disimpan terpisah dari bukti fondasi sebelumnya.

Cadence update scene, biaya CPU pengiriman layer, FPS presentasi layar, dan throughput ekspor CoreGraphics merupakan pengukuran berbeda. Validasi fisik monitor eksternal serta pengukuran Watt tetap mengikuti batas bukti M3.
