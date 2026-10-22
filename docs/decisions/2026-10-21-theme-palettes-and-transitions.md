# Palet dan Transisi Tema Kolam (M3.6)

Tanggal: 21 Oktober 2026 (Asia/Jakarta).  
Status: Implementasi 7 tema dan jalur transisi tersedia; `swift build` berhasil. Filter Core Image native belum diperiksa secara visual saat runtime.

> Catatan pembaruan 22 Oktober: nilai palet dan perlakuan visual terbaru dipusatkan serta dikalibrasi ulang di [keputusan penyelarasan visual](2026-10-22-visual-alignment-nagomi.md). Dokumen ini tetap menyimpan desain awal M3.6 dan detail transisi yang tidak berubah.

## 1. Acuan Visual: Bukti Teramati vs Interpretasi Desain

Sesuai panduan audit dan integritas dokumentasi proyek, pembagian sumber visual diklasifikasikan secara transparan:

1. **Tema dengan Bukti Screenshot Langsung di `analysis/rea/nagomi/screenshots/`**:
   - **Day** ([fullscreen-visible.png](../../analysis/rea/nagomi/screenshots/fullscreen-visible.png)): Kolam teal/jade jernih, sorotan bukaan atas yang hidup, berkas cahaya diagonal kiri, dan jaringan caustics terang. Hasil implementasi: [theme_m3_6_day.png](../../reports/screenshots/theme_m3_6_day.png).
   - **Night** ([night-response.png](../../analysis/rea/nagomi/screenshots/night-response.png)): Nuansa navy malam yang pekat namun mempertahankan keterbacaan ikan melalui siluet kontras dan aksen cyan lembut pada air dalam. Hasil implementasi: [theme_m3_6_night.png](../../reports/screenshots/theme_m3_6_night.png).
   - **Rain** ([rain-response.png](../../analysis/rea/nagomi/screenshots/rain-response.png)): Langit mendung muram, nada air abu-abu-teal desaturasi, caustics meredup lembut, dan permukaan air yang lebih reflektif. Hasil implementasi: [theme_m3_6_rain.png](../../reports/screenshots/theme_m3_6_rain.png).
2. **Tema Berdasarkan Interpretasi Desain (Tanpa Screenshot Langsung di REA)**:
   - **Dawn**: Cahaya hangat peach/emas lembut di atas air yang tetap sejuk dan segar (matahari terbit). Hasil implementasi: [theme_m3_6_dawn.png](../../reports/screenshots/theme_m3_6_dawn.png).
   - **Golden Hour**: Berkas sinar amber/emas pekat sore hari yang menembus permukaan air biru-hijau seimbang. Hasil implementasi: [theme_m3_6_goldenHour.png](../../reports/screenshots/theme_m3_6_goldenHour.png).
   - **Dusk**: Pantulan senja coral/lembayung ungu dengan air dalam berwarna indigo-teal sejuk. Hasil implementasi: [theme_m3_6_dusk.png](../../reports/screenshots/theme_m3_6_dusk.png).
   - **Deep Clear**: Preset manual air turquoise kaya dengan kejernihan maksimal dan penetrasi kedalaman ekstra kontras. Hasil implementasi: [theme_m3_6_deepClear.png](../../reports/screenshots/theme_m3_6_deepClear.png).

> [!NOTE]
> **Pemisahan Preset Rain dari Efek Cuaca**: Preset visual Rain pada M3.6 terbatas secara ketat pada palet pencahayaan atmosfer, air, dan permukaan mendung. Simulasi partikel tetes hujan, riak cuaca berkala, dan audio hujan termasuk dalam cakupan atmosfer M4 dan sengaja tidak ditambahkan pada M3.6.

---

## 2. Model Data dan Kompatibilitas Pengaturan

1. **Model Tema Terpadu (`PondTheme`)**:
   - Didefinisikan dalam `WallpaperSettings.swift` dengan 7 kasus: `.dawn`, `.day`, `.goldenHour`, `.dusk`, `.night`, `.deepClear`, `.rain`.
   - Mengadopsi protokol `String`, `Codable`, `Sendable`, `CaseIterable`.
2. **Fase Waktu (`TimeOfDayPhase`)**:
   - Ditambahkan kasus `.goldenHour` untuk melengkapi 5 fase waktu natural REA.
   - Pemetaan waktu lokal mode Auto mengikuti menit breakdown REA:
     - Dawn: 05:30 (330 menit)
     - Day: 07:30 (450 menit)
     - Golden Hour: 16:30 (990 menit)
     - Dusk: 18:00 (1080 menit)
     - Night: 19:30 (1170 menit)
   - Mode System tetap memetakan tampilan terang (`aqua` / light) ke `.day` dan tampilan gelap (`darkAqua` / dark) ke `.night`.
   - Preset manual `.deepClear` dan `.rain` diisolasi sebagai preset visual murni dan tidak dipaksakan ke dalam siklus Auto Time of Day.
3. **Kompatibilitas Backward & Deserialisasi**:
   - `WallpaperSettings` mengimplementasikan decoding kustom:
     - Jika payload JSON lama tidak memiliki properti `manualTheme`, parser secara otomatis memetakannya dari `manualTimePhase`.
     - Properti `manualTheme` dan `manualTimePhase` disinkronkan secara bidireksional sehingga kode lama yang mengakses `manualTimePhase` tetap berfungsi normal.
4. **Perilaku Reset Pengaturan**:
   - Setelah reset ke default, `TimeOfDayController.batchUpdate` mengevaluasi hasil mode dan tema sekali. `onThemeChanged` menerapkan tema akhir ke `ScreenManager` dan menu; tidak ada penerapan tema lewat callback fase. Jika temanya tidak berubah, reset hanya menyegarkan state menu yang bergantung pada mode/preset.

---

## 3. Struktur Palet Warna

Alih-alih menggunakan satu tint warna global yang membuat kolam berlumpur, pencahayaan dibangun terstruktur per lapisan visual:

| Tema | Nuansa Air (5-Stop Kedalaman) | Caustics (Luar / Dalam / Pudar) | Bayangan (`PondLighting.ShadowStyle`) | Vegetasi & Refleksi |
|---|---|---|---|---|
| **Dawn** | Mint segar ke deep teal sejuk dengan bukaan emas lembut | Cyan-emas lembut (alpha 0.50) | Core 0.30, Penumbra 0.13 (lumut hangat) | Rim highlight peach lembut pada daun |
| **Day** | Teal/jade jernih, sorotan atas lebar, berkas diagonal | Putih-mint terang (alpha 0.70) | Core 0.36, Penumbra 0.16 (dark jade) | Daun teratai hijau cerah segar |
| **Golden Hour** | Biru-hijau peimbang dengan bukaan amber/oranye hangat | Amber keemasan kaya (alpha 0.65) | Core 0.34, Penumbra 0.15 (amber-teal) | Rim highlight emas hangat pada kelopak & daun |
| **Dusk** | Indigo-teal dalam dengan sorotan bukaan atas coral/ungu | Lembayung ungu halus (alpha 0.42) | Core 0.26, Penumbra 0.11 (slate indigo) | Nada teratai teduh dengan aksen magenta lembut |
| **Night** | Navy gelap transparan dengan sorotan bukaan cyan redup | Cyan pekat redup (alpha 0.22) | Core 0.22, Penumbra 0.09 (midnight navy) | Siluet vegetasi gelap dengan kontras ikan terjaga |
| **Deep Clear** | Turquoise jernih pekat, kontras kedalaman tajam | Aquamarine kristal tajam (alpha 0.78) | Core 0.38, Penumbra 0.16 (deep turquoise) | Hijau zamrud transparan berkarakter |
| **Rain** | Abu-abu-teal mendung desaturasi, pantulan difus | Abu-abu perak lembut (alpha 0.32) | Core 0.24, Penumbra 0.14 (slate difus) | Permukaan berkilau lebih reflektif |

Koi tetap menonjol dan terbaca kontras pada seluruh tema berkat kontras siluet tubuh dan sirip berartikulasi CoreGraphics asli.

---

## 4. Mekanisme Transisi Mulus & Retargeting Kontinu

1. **Durasi dan Kurva Transisi**:
   - Transisi tema berlangsung selama **1,8 detik** secara stabil.
   - Tidak ada reset simulasi, pergantian entitas koi, pembersihan makanan aktif, atau penghentian riak air saat tema berganti.
2. **Retargeting Tanpa Patah (Seamless Retargeting)**:
   - **Pembalikan Arah (Reversing)**: Bila transisi A $\to$ B sedang berlangsung dan pengguna memilih kembali A (tanpa snapshot sebelumnya), arah transisi dibalik dengan menukar target dan progres (`progress = 1.0 - progress`), tanpa alokasi snapshot baru.
   - **Retargeting ke Tema Ketiga (A $\to$ B $\to$ C)**: Bila transisi A $\to$ B sedang berlangsung pada progres $p$ lalu pengguna memilih C, renderer membuat kandidat bed, caustics (tepat 2 jaringan lengkap), flora, shadow, tint, dan glimmer. Permukaan air disalin sebelum dibaurkan; cache aktif tidak diubah saat aset kandidat dibuat. Semua kandidat baru dipasang setelah setiap tahap berhasil. Kegagalan mengembalikan `false` tanpa menghapus atau mengganti sumber visual aktif. Saat berhasil, sumber campuran menjadi Layer Set A dan tema C menjadi target.
   - **Retarget Berulang**: Penanganan yang sama berlaku jika pengguna terus mengganti tema secara beruntun (A $\to$ B $\to$ C $\to$ D).
3. **Biaya Komposit & Alokasi Performa**:
   - **Warm Frames (Transisi Stabil)**: Tekstur dasar air, caustics, dan flora di-cache dan di-crossfade melalui `CALayer` tanpa membuat ulang bitmap transisi tema per frame.
   - **Source-Over dan Caustics**: Layer bed dan flora sumber tetap opak pada `1.0`; target dibaurkan dengan `progress`. Ini menjaga dasar scene tertutup selama crossfade source-over. Untuk caustics native, `PondSceneLayer` memakai `CIFilter(name: "CIAdditionCompositing")` pada layer target dan host `NSView` mengaktifkan `layerUsesCoreImageFilters`. Tiap pasangan jaring disusun dalam group/container tersendiri agar filter menerima sumber caustics pasangannya sebagai backdrop. Jalur offscreen memakai `CGBlendMode.plusLighter` di dalam transparency layer, sedangkan snapshot memakai blend mode yang sama saat menyiapkan bitmap. Ketiganya memberi bobot sumber $(1-p)$ dan target $p$ pada RGBA premultiplied. **Runtime filter native belum diperiksa secara visual**, jadi kesetaraan visual native tidak diklaim. Transisi tema yang sudah disiapkan memakai isi layer/cache; bitmap transisi tema tidak dibuat ulang per frame.
   - **Swimmer Bitmap**: Bitmap ikan (koi, ikan dekoratif, pelet makanan) tetap digambar ulang per frame pada logical grid rendah oleh `PondRenderer`.
   - **Biaya Snapshot Retargeting & Batas Memori**: `meshRasterScale` dihitung dengan memperhitungkan ukuran mesh sesungguhnya termasuk overscan tepi. Seluruh tekstur dibatasi secara ketat $\le 1536$ px dan $\le 2.250.000$ piksel:
     - Dasar air (bed): $\le 1536$ px, $\approx 5,9$ MB RGBA (1024×640) hingga batas atas teoritis $\le 9,0$ MB.
     - Caustics (2 jaring): $\le 1536$ px per mesh, $\approx 12,3$ MB RGBA total (1024×640) hingga batas atas teoritis $\le 18,0$ MB.
     - Flora (6 rumpun): $\approx 1,0$ MB RGBA (1024×640) hingga batas atas teoritis $\le 3,5$ MB.
     - **Total Memori Snapshot**: Tipikal $\approx 19,2$–$25$ MB RGBA, dengan batas atas teoritis mutlak $\le 30,5$ MB RGBA.
   - **Kesiapan Snapshot & Fallback Aman**: `snapshotBlend` dan `snapshotTransition` mengembalikan status `Bool`. Keduanya memvalidasi kelengkapan tepat 2 jaringan caustics dan bed pada source dan target tanpa menerima pasangan parsial (`min(countA, countB)` tidak digunakan). Untuk kandidat source snapshot campuran (`isSnapshotSource == true`), validasi memeriksa kelengkapan aset tanpa mensyaratkan `keyTheme` sama dengan tema tertentu. Pada `PondWaterSurface.prepare`, kegagalan parsial langsung me-reset state (`bed = nil`, `networks = []`, `keyTheme = nil`) sehingga tidak menyisakan caustics tidak lengkap. `isSnapshotSource` dan aset aktif hanya diperbarui setelah seluruh kandidat berhasil; jalur gagal tidak memanggil `clearSnapshotSource()`. Sebelum frame pertama dirender, tema baru diarahkan langsung tanpa snapshot. Bila snapshot gagal saat transisi terlihat, A $→$ B tetap berjalan dan tema terbaru disimpan sebagai `pendingTheme`, lalu dimulai setelahnya. Permintaan B membatalkan antrean. Permintaan kembali ke A membatalkan antrean dan membalik progres (`1-p`) bila sumbernya tema tunggal; bila sumbernya snapshot campuran, antrean dipertahankan karena campuran itu tidak dapat dibalik sebagai satu tema. `simulateSnapshotFailure` bukan API produksi publik.
4. **Stasis Saat Pause**:
   - Baik pada desktop (`WallpaperView`) maupun preview (`KoiPondPreviewView`), saat simulasi dijeda (`isPaused = true`), `transitionProgress` membeku total.
   - Saat dilanjutkan, waktu frame terakhir disinkronkan ke waktu nyata (`CACurrentMediaTime()`), sehingga transisi berlanjut dari progres terakhir tanpa mengejar waktu jeda (*zero catch-up jump*).
5. **Dukungan Render Offscreen**:
   - `PondRenderer.render(simulation:in:rect:fromTheme:toTheme:progress:)` mendukung pembauran offscreen lengkap untuk keperluan ekspor atau review statis.

---

## 5. Status Verifikasi

- **Kompilasi**: `swift build` selesai dengan exit code 0 tanpa peringatan.
- **Suite Pengujian Integrasi (`KoiWallpaperVerify`)**:
  - Bagian 8 (T8.1–T8.6) dijalankan pada runtime macOS (Apple Silicon arm64) dan lulus 100%:
    - `T8.1`: Deserialisasi payload legacy tanpa properti `manualTheme` berhasil terisi dari `manualTimePhase`; sinkronisasi dua arah dan pembersihan nilai berfungsi normal.
    - `T8.2`: Evaluasi jadwal tema mode Auto (5 fase REA: Dawn 05:30, Day 07:30, Golden Hour 16:30, Dusk 18:00, Night 19:30) dan pemetaan mode System (`aqua` $\to$ day, `darkAqua` $\to$ night) terverifikasi.
    - `T8.3`: CALayer native compositing terverifikasi: `usesCoreImageFilters = true`, `CIAdditionCompositing` terpasang pada caustics container ganda, `bedLayerA.opacity == 1.0`, `bedLayerB.opacity == midP`, dan target layers disembunyikan pada steady state.
    - `T8.4`: Retargeting in-flight (A $\to$ B $\to$ C) terverifikasi: snapshot source aktif (`isSnapshotSource == true`), target diarahkan ulang ke tema C, dan transisi selesai mulus.
    - `T8.5`: Pembalikan arah in-flight (A $\to$ B $\to$ A) terverifikasi: pembalikan arah membalik progres (`1.0 - p`) tanpa alokasi snapshot baru.
    - `T8.6`: Stasis jeda selama transisi aktif terverifikasi: progres membeku total saat `isPaused = true` (0 ticks timer), dan dilanjutkan mulus tanpa lonjakan (*zero catch-up jump*, $\Delta p < 0.05$).
- **Suite Fisika Simulasi (`KoiWallpaperSimTest`)**: 19/19 pengujian lulus tanpa regresi.
- **Batasan Verifikasi GUI**: Pemeriksaan visual subjektif piksel langsung pada layar monitor eksternal fisik tetap dicatat terpisah; verifikasi di atas diperoleh secara programatik pada instance `WallpaperView` dan `CALayer` runtime macOS.
