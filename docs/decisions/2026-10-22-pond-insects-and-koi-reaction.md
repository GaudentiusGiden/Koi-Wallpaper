# Serangga Kolam dan Reaksi Koi (Pond Insects & Koi Reaction)

**Date**: 2026-10-22  
**Status**: Implemented & Verified

---

## 1. Konteks & Ringkasan

Menghidupkan suasana kolam dengan menambahkan fauna udara berupa serangga kolam:
- **Siang, Fajar, Senja, Golden Hour, Deep Clear, Rain**: 2 capung (*dragonfly*) dan 2 kupu-kupu (*butterfly*).
- **Malam (*Night*)**: 4 kunang-kunang (*firefly*) berpendar lembut dengan halo gradien radial.
- **Reaksi Koi**: Koi sesekali tertarik dan berenang mendekati serangga yang sedang terbang rendah di atas air (maksimal 5,5 detik), lalu kembali berenang santai tanpa meninggalkan target macet. Target makanan (*food drop*) dan klik air (*water call*) tetap diprioritaskan sepenuhnya.

---

## 2. Model & Kinematika Serangga (`PondInsect.swift`)

1. **Capung (*Dragonfly*)**:
   - Pola gerak: melayang (*hover*) dengan getaran sayap berfrekuensi tinggi (~36 rad/s) dan sesekali menyentak cepat (*dart*) dengan akselerasi tajam (140–200 pt/s selama 0,24–0,38 detik) ke arah baru.
   - Ketinggian (*altitude*): berfluktuasi lembut antara 0,15–0,55 di atas permukaan air.
   - Visual: abdomen ramping bersegmen warna *azure blue* atau *emerald teal*, mata majemuk, dan 4 sayap transparan berkilau dengan vena dan *pterostigma*.

2. **Kupu-kupu (*Butterfly*)**:
   - Pola gerak: terbang lembut (*flutter*) dengan jalur sinusoidal organik, kepakan sayap ~4,2 Hz (membuka dan menutup ritmis).
   - Ketinggian (*altitude*): meliuk antara 0,25–0,80 di atas permukaan air.
   - Visual: sayap lebar dengan variasi warna *warm monarch amber* dan *pale sulfur yellow*, tepi gelap bertotol putih, serta sepasang antena lentur.

3. **Kunang-kunang (*Firefly*)**:
   - Pola gerak: melayang lambat (13–17 pt/s) mengitari kolam malam secara tenang.
   - Pendaran cahaya: denyut lembut (*breathing glow pulse*) dengan ekspresi gradien radial bernuansa *lime chartreuse* hangat (`#D0FF52`) beradius hingga 28 pt serta lentera bercahaya terang di ujung abdomen.

---

## 3. Komposisi Lapisan & Gaya Pixel-Art (`PondSceneLayer.swift`, `PondRenderer.swift` & `PondInsectArtwork.swift`)

Sesuai estetika *coarse pixel art* retro (target grid logis 270 baris) dan persyaratan performa:
- **Layering**:
  - Berada tepat **di atas teratai / lily pads (`floraLayersA`/`floraLayersB`)** agar serangga terbang bebas di atas daun teratai dan tidak tertutup vegetasi.
  - Berada tepat **di bawah lapisan atmosfer (`tintLayer`)** agar pencahayaan waktu (seperti rona gelap malam atau hangatnya senja) tetap memengaruhi atmosfer serangga.
- **Pixel-Art Authentic Styling & Ukuran Terbaca**:
  - Serangga dirender pada kisi piksel logis kolam yang sama dengan koi dan flora (`setShouldAntialias(false)` dan filter magnifikasi `.nearest`).
  - **Ukuran diperbesar dan siluet dipertegas**:
    - **Capung**: Panjang ~32 pt (abdomen 6 blok bersegmen chunky, toraks bergradasi warna, kepala dengan mata majemuk dan *eye glint* piksel putih, 4 sayap piksel bercahaya dengan *pterostigma* tebal).
    - **Kupu-kupu**: Bentang sayap ~44 pt, badan ~18 pt (sayap berundak khas monarki/swallowtail dengan tepi gelap tebal dan aksen bintik piksel di tepian sayap, kepakan sayap terkompresi ritmis).
    - **Kunang-kunang**: Panjang kumbang ~18 pt, lebar ~8,5 pt (sayap luar *elytra* gelap dengan garis belah, perisai leher *pronotum* oranye cerah, lentera ekor berpendar kuning cerah).
- **Optimasi Performa Bebas Lag pada Mode Malam**:
  - Masalah lag sebelumnya terjadi akibat pemanggilan alokasi bitmap resolusi Retina penuh per-frame (`PondBitmap.makeImage`) dengan kalkulasi gradien radial multi-stop.
  - Diperbaiki dengan:
    1. Memanfaatkan *cached reusable context* (`insectContext`) pada ukuran kisi piksel logis kolam (<0.5 MB total memori) yang hanya dialokasikan saat ukuran jendela/layar berubah.
    2. Pendaran (*glow*) kunang-kunang digambar dengan disk pendaran bertingkat (*concentric stepped pixel disks*) yang ter-rasterisasi secara instan pada kisi piksel tanpa beban komputasi gradien GPU.
    3. Performa stabil di 60 FPS / 30 FPS tanpa alokasi memori berlebih (*zero frame-by-frame memory spikes*).

---

## 4. Transisi Tema Halus (*Smooth Cross-fading*)

- Saat transisi antara malam dan nonmalam (misalnya siang ke malam):
  - Kelompok serangga lama memudar (*fade out*: `opacity` 1.0 $\to$ 0.0).
  - Kelompok serangga baru muncul bertahap (*fade in*: `opacity` 0.0 $\to$ 1.0).
  - Saat `progress == 1.0`, kelompok lama dibersihkan sehingga jumlah serangga stabil tepat 4.
- Saat transisi sesama nonmalam (misal Siang $\to$ Golden Hour $\to$ Senja $\to$ Deep Clear $\to$ Rain):
  - Kelompok 2 capung dan 2 kupu-kupu dipertahankan terus tanpa *respawn* mendadak.

---

## 5. Reaksi Keingintahuan Koi (`followingInsect`)

- State baru pada `KoiBehaviorState`: `.followingInsect`.
- Siklus: tiap ~12–20 detik (acak), satu koi yang penasaran dan sedang bebas (`state == .wandering && currentTarget == nil`) memilih serangga aktif yang sedang terbang rendah (`isFlyingLow`).
- Koi berenang dinamis mengikuti koordinat posisi serangga hingga maksimal 5,5 detik, atau berhenti saat sudah mendekat ke bawah serangga.
- **Prioritas Mutlak**: Jika pelet makanan dijatuhkan (`handleFoodDrop`) atau permukaan air diklik (`handleWaterClick`), koi yang sedang mengikuti serangga langsung beralih ke `.seekingFood` atau `.investigatingClick`.
- **Zero Stuck Fish Guarantee**: Jika serangga target menghilang, dibersihkan, atau waktu habis, target segera di-*clear* dan koi kembali berenang santai (`wandering`).

---

## 6. Bukti Verifikasi

- **`KoiWallpaperSimTest`**: 28 dari 28 pengujian lulus, termasuk Section 13 (T13.1–T13.5).
- **`KoiWallpaperVerify`**: 53 dari 53 pengujian lulus tanpa regresi performa, kebocoran memori, atau pelanggaran frame-rate.
- **Visual Previews**:
  - `reports/screenshots/insects_day_preview.png`: 2 capung & 2 kupu-kupu siang hari.
  - `reports/screenshots/insects_night_preview.png`: 4 kunang-kunang berpendar lembut di malam hari.
  - `reports/screenshots/insects_transition_preview.png`: *Cross-fade* serangga saat peralihan tema.
  - `reports/screenshots/insects_koi_following.png`: Koi mendekati serangga yang terbang rendah.
