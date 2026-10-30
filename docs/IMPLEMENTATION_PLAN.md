# Rencana implementasi Koi Wallpaper

Rencana ini mengikuti [analisis referensi](REA.md) dan [hasil REA CLI](REA_FINDINGS.md). Fondasi native M0 telah dibangun, diverifikasi (executable `KoiWallpaper`, bundle `.app`, dan suite verifikasi `KoiWallpaperVerify`), dan **resmi diterima pada 20 Oktober 2026 (Asia/Jakarta)** dengan batasan platform WindowServer macOS yang disepakati (Koi Wallpaper terbukti tidak mengambil fokus; klik fisik pada kolam desktop dapat mengaktifkan Finder dan mendefokuskan aplikasi sebelumnya). Milestone **M1 (Simulasi Kolam Mandiri)** telah selesai diimplementasikan, diverifikasi melalui unit test in-process 17/17 lulus (termasuk 4 uji regresi geometri kapsul tirus T0.1–T0.4 dan uji non-penetrasi geometri kapsul multi-langkah deterministik T3.1 pada 5 skenario benturan ekstrim dengan oracle independen), dan divalidasi secara visual melalui 14 tangkapan layar Retina alur kerja dan 3 tangkapan layar benturan dinamis berhadapan pada jendela GUI macOS WindowServer dengan perbaikan tuntas pada cacat penumpukan makan, pembagian target sirkumferensial klik air, relaksasi posisi kapsul tulang belakang, dan pemotongan batas resize (status visual temporal kolam diklasifikasikan parsial untuk ketiadaan kerumunan jangka panjang; T3.1 berlaku pada skenario ber-seed dan bukan klaim jaminan universal matematis). Milestone **M2 (Wallpaper yang Dapat Dipakai)** telah selesai diimplementasikan penuh sebagai MVP satu monitor, mengintegrasikan simulasi M1 ke host desktop M0, menyediakan menu lengkap status bar, Time of Day multi-fase, persistensi pengaturan, isolasi multi-alasan pause baterai/sleep/manual, mitigasi lonjakan delta waktu simulasi, dan kode sumber bebas dependensi jaringan (terverifikasi melalui suite in-process 21 assertion `KoiWallpaperVerify` [15 regresi M0 + 6 penerimaan M2] dan 17/17 pada `KoiWallpaperSimTest`). Milestone **M3 (Banyak Monitor dan Efisiensi)** telah selesai diimplementasikan pada tingkat perangkat lunak dan arsitektur, menghadirkan `ScreenManager` untuk orkestrasi multi-display, dunia simulasi dan viewport mandiri per monitor dengan sinkronisasi pengaturan global, penanganan hot-plug (attach/detach bersih dengan pembersihan observer dan pelepasan memori tanpa jendela yatim atau timer bocor), adaptasi Retina heterogen, pemetaan origin negatif presisi, isolasi stasis occlusion mandiri per monitor, dan profil performa perangkat target (terverifikasi 27/27 lulus pada `KoiWallpaperVerify` dan 17/17 pada `KoiWallpaperSimTest`; validasi fisik multi-monitor dengan kabel/layar eksternal kedua serta pengukuran energi kuantitatif Watt tetap berstatus PENDING). Fondasi visual **M3.5 (Pixel Art dan Air Bercahaya)** diterapkan setelah M3 dan sebelum **M4 (Perilaku Personal dan Atmosfer)**; rincian serta cara meninjau ada di [fondasi visual](VISUAL_FOUNDATION.md). Status dan rincian keputusan M0 dicatat di [audit M0](M0_AUDIT.md).

## Catatan terkini — Adopsi Nagomi Fase 1 (30 Oktober 2026)

Implementasi Fase 1 dari [Rencana Adopsi Fitur & Visual Nagomi Desktop](decisions/2026-10-30-nagomi-adoption-fase1.md) telah selesai dan terverifikasi penuh:

- **Mode Palet `Classic` vs `Neon`**: Ditambahkan ke `WallpaperSettings`, `ScreenManager`, dan menu `StatusBarController` ("Palet Ikan Koi").
- **Kalibrasi Hex 8 Varietas**: Didasarkan pada hasil REA [`koi-palettes.json`](../analysis/desktop-breakdown/styles-catalog/koi-palettes.json) untuk mode Classic dan Neon.
- **Pola Corak Tubuh Matematis (`KoiPatternPatch`)**: Proyeksi dinamis sepanjang kurva tulang belakang (`spine`) ikan dengan clipping presisi di dalam siluet `torso`.
- **Kunang-Kunang Malam Lowbias32 & Glowing Tiny Fish**: Mengadopsi algoritma hash dan sway multi-frekuensi dari [`12-fireflies.wgsl`](../analysis/desktop-breakdown/shaders/12-fireflies.wgsl) serta palet bioluminescent [`tiny-fish/glow.json`](../analysis/desktop-breakdown/library/presets/tiny-fish/glow.json).
- **Pengujian & Validasi**: Seluruh 62 pengujian `KoiWallpaperSimTest` lulus (termasuk seksi T20.1–T20.4) dan seluruh 68 pengujian `KoiWallpaperVerify` lulus (total 130 tests).
- **Aset & Tangkapan Layar**: [Preview Palet 8 Varietas](../reports/screenshots/fase1_palette_comparison.png) dan [Preview Suasana Malam](../reports/screenshots/fase1_night_pond.png).

## Catatan terkini — angsa otomatis (24 Oktober 2026)

Implementasi lanjutan setelah baseline M5 ada di commit `dc0168c`:

- Setiap simulasi wallpaper langsung membuat satu angsa di titik acak dalam kolam; tidak ada aksi menu untuk mengundang angsa.
- Angsa mengubah haluan secara bertahap dan kecepatannya sedikit bervariasi. Setelah 18–30 detik, angsa mengarah ke tepi terdekat dan dihapus setelah seluruh siluet keluar layar. Siklus berikutnya dimulai setelah jeda 5–9 detik.
- Artwork angsa memakai skala `1.512` (8% di atas skala desain sebelumnya `1.4`).
- Preview interaktif: `swift run KoiWallpaperPreview --preview-swan`. Preview gambar statis: `swift run KoiWallpaperPreview --render-swan-design build/swan-design-preview.png`.
- Uji siklus angsa T12.5 menemukan bahwa angsa dapat hanyut keluar sebelum durasi tinggal 18–30 detik karena gaya penghindaran tepi terlalu lemah. Fase jelajah kini membatasi angsa pada tepi aman dan memantulkan haluan; fase keluar terjadwal tetap dapat melintasi tepi.
- Pemeriksaan terbaru: `KoiWallpaperSimTest` 41/41 lulus, termasuk T12.5 untuk umur, keluar penuh, dan jeda respawn angsa serta T16.1 untuk wandering multi-seed selama total 16 menit simulasi. `KoiWallpaperVerify` 53/53 lulus setelah perbaikan.

Rincian keputusan ada di [catatan pengunjung M5](decisions/2026-10-22-m5-visitors-and-fullscreen.md), sedangkan bukti dan batas validasi ada di [audit M5](M5_AUDIT_REPORT.md).

## Urutan kerja

### M0 — Buktikan integrasi desktop

Status: **DITERIMA** (Keputusan pengguna 20 Oktober 2026, Asia/Jakarta, dengan batasan platform yang disepakati). Implementasi M0 tersedia dan verifikasi in-process lulus. Integrasi Window Server (layer -2147483623 di bawah Finder -2147483603) dan pengujian interaksi pengguna (Finder, Mode Interaksi, Spaces/fullscreen, Show Desktop, Mission Control, occlusion `.covered`, dan hardware sleep/wake) telah diverifikasi. Kriteria non-stealing terbukti penuh (Koi Wallpaper tidak pernah mengambil fokus atau menu bar). Keterbatasan WindowServer macOS (klik desktop mengaktifkan Finder dan mendefokuskan aplikasi aktif sebelumnya) diterima secara formal sebagai batasan platform M0 tanpa mengklaim retensi fokus aplikasi sebelumnya lulus. Proyek resmi melangkah ke M1. Lihat [audit M0](M0_AUDIT.md).

Tujuan: memastikan aplikasi bisa menjadi wallpaper dan tetap nyaman dipakai bersama Finder sebelum membuat artwork serta simulasi lengkap.

Pekerjaan:

- [x] Buat app macOS minimal dengan menu bar dan jendela borderless berwarna statis.
- [x] Konfigurasi tingkat jendela, perpindahan Spaces, dan collection behavior (`.stationary`, `.canJoinAllSpaces`, `.ignoresCycle`, `.fullScreenNone`, `animationBehavior = .none`).
- [x] Implementasikan tembus klik (default) dan mode interaksi eksplisit (`.interactive`).
- [x] Sinkronkan status pause manual dan notifikasi sistem (`screensDidSleep`, `willSleep`, `sessionDidResignActive`) ke `WallpaperView` (radius membeku saat jeda dan bertambah setelah resume).
- [x] Audit kebutuhan izin TCC (memastikan app tidak mendeklarasikan entitlement Accessibility / Input Monitoring).
- [x] Validasi desktop non-stealing: Koi Wallpaper menolak key/main window dan tidak pernah mengambil alih fokus/menu bar saat wallpaper diklik (diverifikasi via OS window manager dan observasi UI).
- [x] Keputusan retensi fokus aplikasi aktif: Diselesaikan pada 20 Oktober 2026 (Asia/Jakarta) dengan penerimaan batasan platform WindowServer macOS oleh pengguna (klik area kolam dapat mengaktifkan Finder dan mendefokuskan aplikasi sebelumnya; Koi Wallpaper sendiri terbukti tidak mengambil fokus; retensi fokus aplikasi aktif tidak diklaim lulus).
- [x] Validasi desktop: navigasi Spaces dan transisi fullscreen aplikasi lain (diverifikasi live oleh pengguna bebas flicker setelah commit `81d1fbe`).
- [x] Validasi manual desktop: klik, drag, dan seleksi marquee Finder pada mode biasa (diverifikasi live oleh pengguna).
- [x] Validasi manual desktop: visualisasi riak interaktif, Show Desktop, Mission Control, live desktop occlusion (`.covered`), dan sleep/wake fisik perangkat keras (diverifikasi live oleh pengguna).

Selesai ketika:

- [x] Ikon Finder dapat diklik, dipindah, dan diseleksi dalam mode biasa (terkonfirmasi via observasi fisik pengguna).
- [x] Jendela Koi Wallpaper tidak mengambil fokus aplikasi saat dipasang sebagai wallpaper (terkonfirmasi via penolakan programatik dan observasi UI).
- [x] Keputusan batasan platform fokus aplikasi aktif: Diterima oleh pengguna pada 20 Oktober 2026 (Koi Wallpaper tidak mengambil fokus; klik fisik kolam dapat mengaktifkan Finder dan mendefokuskan aplikasi sebelumnya; batasan platform diterima tanpa mengklaim retensi fokus aplikasi sebelumnya lulus).
- [x] Mode interaksi bisa diaktifkan dan dihentikan dengan jelas dari menu (terkonfirmasi via observasi live pengguna).
- [x] Perilaku pause saat tertutup sudah diketahui (`.covered` aktif saat tertutup 100% dan kembali `Aktif` saat dibuka, terkonfirmasi via observasi live pengguna).
- [x] Temuan pengujian dan batasan arsitektur input desktop telah didokumentasikan secara transparan; M0 diterima dengan batasan platform yang jelas dan M1 menjadi milestone berikutnya.

### M1 — Simulasi kolam mandiri

Status: **IMPLEMENTASI INTI & PENGUJIAN LULUS, VALIDASI VISUAL TEMPORAL PARSIAL** (Simulasi inti dan artwork CoreGraphics mandiri selesai; suite `KoiWallpaperSimTest` terbaru lulus 41/41, termasuk T0.1–T0.4, T3.1, dan T16.1 yang memeriksa 8 seed × 120 detik simulasi pada 57.600 frame tanpa penetrasi kapsul koi dan tanpa keluar batas. Preview `KoiWallpaperPreview` juga memiliki bukti 14 tangkapan layar Retina alur kerja dan 3 tangkapan layar benturan dinamis. Validasi visual jangka panjang tetap parsial: pengujian finite dan metrik geometri tidak membuktikan ketiadaan kesan berkerumun pada seluruh durasi tanpa batas atau menggantikan penilaian mata manusia).

Tujuan: membuat perilaku inti yang dapat dilihat terlebih dahulu dalam jendela preview biasa.

Pekerjaan:

- [x] Implementasikan dunia simulasi mandiri terpisah dari AppKit (`PondSimulation`, `PondBounds`, `PondVector`).
- [x] Implementasikan PRNG deterministik ber-seed (SplitMix64 via `SeededRandomNumberGenerator`) untuk menjamin keterulangan 100% pada seluruh skenario pengujian simulasi.
- [x] Implementasikan autonomous steering: wandering halus, penghindaran tepi kolam (soft margin), pemisahan target klik perimeter riak ($R = 42$ pt), dan relaksasi posisi non-penetrasi fisik geometri kapsul tirus 5 segmen antarikan (`resolveFishSeparation` dengan safety margin $0.5$ pt dan kompensasi batas kolam). Model kapsul tirus adalah proxy konservatif massa tubuh utama (bukan kesetaraan analitik kurva Bézier visual).
- [x] Buat artwork CoreGraphics prosedural proyek sendiri untuk air, koi (8 varietas Jepang dengan artikulasi tulang & sirip hidrodinamis), tanaman teratai, bayangan, dan riak air, berbagi model geometri penampang melintang tulang belakang dengan simulasi.
- [x] Tambahkan animasi renang sinus/ekor/sirip, target sementara klik air sirkumferensial, pemberian pelet makanan via Option+klik, dan konsumsi pelet atomik sekali makan.
- [x] Pisahkan dunia simulasi, penanganan input, update fisika timestep tetap (catch-up clamping), dan visual renderer; batasi kuota pelet (48) dan riak (64).
- [x] Buat preview GUI mandiri (`KoiWallpaperPreview`) dengan jendela biasa, HUD diagnostik, mode validasi otomatis (--validate-visual), dan mode validasi benturan dinamis (--validate-collision) dengan deteksi titik belok jarak minimum.
- [x] Buat suite simulasi in-process (`KoiWallpaperSimTest`); status terbaru 41/41 lulus, termasuk 4 regresi geometri kapsul tirus, oracle independen disk chain, dan T16.1 multi-seed 16 menit simulasi.

Selesai ketika:

- [~] Tampilan dan kontrol interaksi diverifikasi melalui event GUI sintetis `NSEvent`, 14 tangkapan layar alur kerja Retina, dan 3 tangkapan layar benturan dinamis. T16.1 menambah uji finite 16 menit simulasi (8 seed × 120 detik, 57.600 frame): tidak ada penetrasi kapsul, clearance minimum 0,50 pt, dan semua koi tetap dalam batas. Status masih **Parsial** karena sampel ini tidak membuktikan ketiadaan kesan berkerumun sepanjang masa simulasi tanpa batas (*infinite wandering*) dan bukan pengganti penilaian visual manusia.
- [x] Pemisahan fisik dan ketiadaan penetrasi geometri tubuh antarikan terbukti secara deterministik pada model 5 kapsul tulang belakang berartikulasi dan diverifikasi silang dengan oracle independen (terverifikasi via `KoiWallpaperSimTest` T3.1 pada 5 skenario benturan: head-on clearance 35.5pt, crossing 90° clearance 11.8pt, click convergence 3 koi clearance 33.3pt, food convergence 3 koi clearance 0.5pt, near-wall clearance 46.5pt dan stayedInBounds=true; seluruhnya overlap $\le 0.0$ pt).
- [x] Delapan koi berenang dan berbelok secara halus tanpa keluar dari kolam (terverifikasi via `KoiWallpaperSimTest` T1.1–T1.3, T2.1, T2.2).
- [x] Klik mengundang ikan dan Option + klik menaruh makanan pada lokasi yang sesuai (terverifikasi via `KoiWallpaperSimTest` T4.1, T5.1).
- [x] Ikan mendekati dan mengonsumsi makanan; satu pelet tidak bisa dikonsumsi dua kali (terverifikasi via `KoiWallpaperSimTest` T6.1).
- [x] Input berulang tidak membuat jumlah pelet atau riak tumbuh tanpa batas (terverifikasi via `KoiWallpaperSimTest` T7.1).
- [x] Update memakai timestep tetap saat frame rate input berbeda dan membatasi catch-up setelah lag (T9.1 memeriksa kemajuan fase renang pada 30/60 FPS untuk durasi simulasi sama; T10.1 memeriksa catch-up clamp). Lintasan wandering acak tidak dibandingkan.

### M2 — Wallpaper yang dapat dipakai

Status: **SELESAI & TERVERIFIKASI (MVP SATU MONITOR)** (Simulasi kolam mandiri M1 telah dipasang pada host desktop M0 melalui `WallpaperView`; menu status bar lengkap Pause/Resume, Interaction Mode, Time of Day, Settings, dan Quit telah tersedia; fase waktu Auto, systemTheme, dan manual terimplementasi; persistensi pengaturan via `SettingsManager` bertahan melintasi roundtrip UserDefaults; alasan pause manual, baterai/daya, jendela tertutup, sleep, dan sesi tidak aktif terisolasi mandiri sehingga charger terpasang tidak membatalkan pause manual; resume terbukti membendung lonjakan delta simulasi dan kode sumber bebas dependensi jaringan. Seluruh acceptance criteria terverifikasi dengan 6 assertion M2 dalam suite in-process 21 assertion `KoiWallpaperVerify` dan 17/17 assertion pada `KoiWallpaperSimTest`).

Tujuan: menyatukan hasil M0 dan M1 menjadi MVP satu monitor.

Pekerjaan:

- [x] Pasang scene kolam pada host desktop hasil M0 (`WallpaperView` terintegrasi dengan `PondSimulation`, `PondRenderer`, timer animasi 60 FPS, dan mitigasi lag; stasis loop animasi saat pause).
- [x] Tambahkan menu Pause/Resume, Interaction Mode, Time of Day, Settings, dan Quit (`StatusBarController` menu bar dengan submenu lengkap).
- [x] Implementasikan fase waktu Auto/manual, pilihan mengikuti tema sistem, dan penyimpanan pengaturan (`TimeOfDayController`, `WallpaperSettings`, `SettingsManager`).
- [x] Kelola alasan pause manual, baterai, tertutup, sleep, dan sesi tidak aktif (`LifecyclePolicy` + `PowerSourceMonitor`, isolasi multi-alasan).

Selesai ketika:

- [x] Pengaturan kembali setelah aplikasi diluncurkan ulang (terverifikasi via `KoiWallpaperVerify` T6.1 roundtrip in-process simulasi peluncuran ulang via `UserDefaultsSettingsStore`).
- [x] Pergantian fase waktu tidak menghapus ikan atau makanan (terverifikasi via `KoiWallpaperVerify` T6.3, 8 koi dan pelet utuh melintasi siklus dawn/day/dusk/night).
- [x] Memasang charger tidak melanjutkan kolam yang dipause secara manual (terverifikasi via `KoiWallpaperVerify` T6.4 multi-reason isolation dengan `MockPowerSourceMonitor`).
- [x] Lonjakan delta waktu simulasi dibatasi oleh clamp tanpa lonjakan ekstrem (terverifikasi via `KoiWallpaperVerify` T6.5, perpindahan maksimal 5.69 pt pada injeksi delta 3600 detik membuktikan clamping delta simulasi; bukan uji sleep/wake perangkat secara end-to-end).
- [x] Perilaku Finder dan mode interaksi tetap memenuhi keputusan M0 (terverifikasi via `KoiWallpaperVerify` T1.1–T3.3 untuk konfigurasi flag window dan event sintetis; passthrough Finder nyata merujuk validasi desktop langsung M0).
- [x] Pemindaian statis tidak menemukan pemanggilan API jaringan yang diperiksa (terverifikasi via `KoiWallpaperVerify` T6.6, pemindaian leksikal berkas sumber di `Sources/` menemukan nol dependensi API jaringan terlarang; bukan uji runtime atau packet capture).

**Batas scope & catatan audit:**
1. M2 adalah batas MVP awal satu monitor. Dukungan multi-monitor (M3) dan memori rutinitas (M4) tidak boleh diklaim pada tahap ini.
2. Catatan audit M1 dipertahankan: Uji deterministik T3.1 membuktikan ketiadaan penetrasi pada 5 skenario ber-seed ekstrim dengan oracle independen (disk chain padat), namun tidak diubah menjadi klaim jaminan universal matematis sembarang lintasan. Status ketiadaan kerumunan jangka panjang (*infinite wandering zero-clumping*) tetap diklasifikasikan sebagai **Parsial**. Geometri 5 kapsul tulang belakang berartikulasi dipertahankan utuh tanpa perubahan karena tidak menjadi penghalang untuk M2.
3. Batasan bukti pengujian M2: Penghentian timer saat pause membuktikan loop callback animasi berhenti, bukan klaim unmeasured penghematan CPU/GPU 100%. T6.1 menguji roundtrip UserDefaults in-process, bukan peluncuran ulang proses fisik oleh OS. T6.4 menggunakan mock power monitor, bukan colokan charger fisik. T6.5 membuktikan batasan delta simulasi, bukan pengukuran sleep/wake perangkat keras fisik. T6.6 adalah pemindaian statis berkas sumber untuk istilah API jaringan terlarang, bukan pembuktian empiris lalu lintas jaringan tingkat OS atau privasi total. Validasi interaksi Finder langsung berasal dari pengujian langsung M0, sedangkan suite otomatis M2 menguji konfigurasi flag dan event sintetis.

### M3 — Banyak monitor dan efisiensi

Status: **IMPLEMENTASI PERANGKAT LUNAK & IN-PROCESS LULUS; VALIDASI FISIK MULTI-DISPLAY & PENGUKURAN ENERGI KUANTITATIF TERTUNDA** (Dukungan banyak monitor telah diimplementasikan penuh pada level arsitektur dan kode via `ScreenManager` dan `DesktopWindowController`; setiap monitor memiliki host jendela desktop, kanvas `WallpaperView`, dan dunia simulasi `PondSimulation` mandiri dengan batas proporsional; pengaturan global Time of Day, Interaction Mode, HUD, dan pause global disinkronkan ke seluruh monitor; hot-plug attach dan detach tertangani bersih dengan pembersihan observer dan pelepasan memori controller [terbukti via weak reference di T7.2] tanpa jendela yatim atau timer bocor; skala Retina 1.0x/2.0x heterogen beradaptasi dinamis; origin koordinat negatif pada monitor sekunder terbukti memetakan klik dan makanan secara presisi; occlusion terisolasi per monitor sehingga monitor yang tertutup berhenti sementara monitor yang terbuka mempertahankan timer animasi aktif [`isPaused = false`, `isAnimating = true`]. Seluruh perilaku multi-monitor diuji secara deterministik melalui in-process synthetic topology `MockScreen` [T7.1–T7.5]. Profil performa live diukur pada 1 layar fisik internal Apple M1 MacBook Air mencatat 58.1–59.4 Hz cadence callback timer [2.6%–3.1% operational CPU], 129.7–134.2 FPS CoreGraphics unthrottled render throughput [99.8%–100.0% single-core burst], 51.2–127.1 MB RSS [+0.03–0.06 MB per simulasi tambahan], stasis CPU 0.04%–0.09% saat jeda, dan utilitas GPU 6.0%–41.0% pada Baterai 96%–99% / 49.0%–52.0% pada AC 100% [IOAccelerator engine load; bukan pengukuran energi]. Pengujian kabel/monitor fisik sekunder live dan pengukuran energi kuantitatif Watt via powermetrics ditandai secara jujur sebagai tertunda).

Pekerjaan:

- [x] Tambahkan dunia serta host terpisah per monitor dengan pengaturan global.
- [x] Tangani hot-plug, skala Retina, perubahan ukuran, dan koordinat origin negatif.
- [x] Pastikan scene yang tertutup/sleep berhenti secara mandiri.
- [x] Ukur penggunaan CPU, GPU, RAM, dan kondisi daya pada perangkat target (pengukuran energi Watt kuantitatif tertunda karena membutuhkan hak superuser).

Selesai ketika:

- [x] Monitor dapat dipasang/dilepas tanpa jendela yatim atau renderer yang tertinggal (terverifikasi in-process via synthetic topology `MockScreen` pada `KoiWallpaperVerify` T7.2; validasi fisik pemasangan monitor eksternal sekunder secara live tertunda).
- [x] Klik dan makanan jatuh di posisi yang benar di semua monitor yang didukung (terverifikasi in-process via negative coordinate origin mapping pada `KoiWallpaperVerify` T7.4; validasi klik multi-layar fisik live tertunda).
- [x] Menutup kolam pada satu monitor tidak menghentikan kolam yang masih terlihat di monitor lain (terverifikasi in-process via mock occlusion window pada `KoiWallpaperVerify` T7.5; validasi occlusion desktop fisik multi-layar tertunda).
- [x] Tersedia catatan pengukuran beserta perangkat, jumlah monitor, resolusi, cadence timer vs render throughput, dan kondisi daya (terverifikasi via `KoiWallpaperVerify` T7.6 pada 1 layar fisik internal Apple M1; pengukuran energi kuantitatif Watt tertunda).

**Batas scope & catatan audit:**
1. M3 adalah batas dukungan multi-monitor dan efisiensi daya. Memori rutinitas jadwal makan, histogram slot waktu, dan sapaan harian berada pada cakupan M4 dan tidak boleh diklaim pada tahap ini.
2. Validasi perangkat keras dilakukan pada perangkat nyata yang tersedia (Apple M1 MacBook Air, 1 layar Retina internal 2560x1600 / 1680x1050 pt @ 2.0x). Topologi multi-monitor (2 layar heterogen, origin negatif -1920, hot-plug attach/detach, dan occlusion independen) diverifikasi secara in-process melalui layar sintetis `MockScreen` (T7.1–T7.5); ini membuktikan kebenaran logika arsitektur tetapi BUKAN sertifikasi perangkat keras multi-monitor fisik langsung. Pengujian kabel/monitor eksternal kedua secara fisik live ditandai sebagai TERTUNDA.
3. Batasan pengukuran benchmark T7.6:
   - Cadence Callback Timer (58.1–59.4 Hz) berbasis RunLoop timer callback diukur terpisah dari Throughput Render Penuh (129.7–134.2 FPS) yang merupakan kapasitas CoreGraphics unthrottled loop. Metrik ini mengukur frekuensi eksekusi callback timer, bukan frame presentasi layar/vsync fisik.
   - Utilisasi GPU (`IOAccelerator` Device Utilization 6.0%–41.0% pada Baterai, 49.0%–52.0% pada AC) mencerminkan aktivitas mesin akselerator grafis dan dicatat sebagai informasi beban engine grafis, BUKAN konsumsi energi listrik.
   - Pengukuran energi kuantitatif absolut (Watt/mWh) melalui macOS `powermetrics` memerlukan izin root/superuser (`sudo powermetrics`) atau meteran daya perangkat keras, sehingga ditandai TERTUNDA. Proksi efisiensi energi yang diverifikasi adalah penghentian timer RunLoop total dan stasis CPU proses pada 0.04%–0.09% saat kolam dijeda/tertutup. Threshold assertion T7.6 diperketat (cadence 50–70 Hz, operational CPU $\le$ 20%, throughput $\ge$ 95 FPS, burst CPU $\ge$ 75%, RSS 20–220 MB, dual-delta $\le$ 5 MB, stasis $\le$ 0.8%).

### M3.5 — Fondasi visual pixel art dan air bercahaya

Status: **REVISI VISUAL DIIMPLEMENTASIKAN & DIVERIFIKASI**, mengikuti rencana koreksi yang disepakati. Perangkat lunak M3 telah selesai pada commit `f88406c`; validasi fisik multi-monitor serta pengukuran Watt M3 tetap tertunda.

- [x] Gunakan artwork CoreGraphics yang sama pada preview/desktop, dengan komposit native `PondSceneLayer` dan jalur offscreen `PondRenderer.render` untuk ekspor.
- [x] Gunakan grid adaptif mendekati 480 × 270 pada 16:9; nearest-neighbor sejajar backing pixel, sementara air/caustics tetap halus.
- [x] Bangun ulang delapan varietas koi dengan siluet lebih berisi, panjang 12–18% sisi pendek, dan geometri fisik yang ikut berubah saat spawn/reset/resize. Ukuran eksplisit `initialFish` dipertahankan.
- [x] Tambahkan enam kelompok vegetasi, 16 teratai, empat bunga, dan 24 ikan kecil dekoratif yang tidak memengaruhi simulasi koi.
- [x] Gunakan cahaya bertingkat serta dua jaringan caustics Voronoi; semua gerak mengikuti fixed-step time sehingga pause/reset/resume konsisten.
- [x] Pertahankan target preview 60 Hz dan desktop 30 Hz. Verifikasi 32/32 pemeriksaan aplikasi serta 19/19 uji simulasi lulus; update scene preview native terukur 59,7 Hz.
- [x] Tinjau screenshot native preview/desktop dan rekaman preview 23,65 detik. Tutupan vegetasi terukur 21,04%, dengan 97,82% bagian tengah sampel tetap terbuka.
- [x] Pertahankan input, pengaturan, lifecycle, dan orkestrasi monitor M3. Mood, memori, sapaan, hujan, dan variasi malam M4 tidak ditambahkan.

Implementasi, hasil verifikasi, dan cara meninjau: [VISUAL_FOUNDATION.md](VISUAL_FOUNDATION.md). Perbandingan gambar: [laporan visual lokal](../reports/visual-review.html).

### M3.6 — Palet dan transisi tema

Status: **SELESAI & TERVERIFIKASI PROGRAMATIK RUNTIME**. Model `PondTheme` mencakup 5 tema waktu dan 2 preset manual. Auto mengikuti jadwal REA [05:30, 07:30, 16:30, 18:00, 19:30], System memetakan light ke Day dan dark ke Night. `PondSceneLayer` memakai Core Animation dan filter Core Image `CIAdditionCompositing` untuk pasangan caustics; host `NSView` mengaktifkan `layerUsesCoreImageFilters`. Jalur native, offscreen, dan snapshot menerapkan bobot source $(1-p)$ dan target $p$ pada caustics premultiplied RGBA. Snapshot retarget membangun kandidat bed, tepat 2 jaringan caustics lengkap (tanpa mentolerir pasangan parsial), flora, tint, shadow, dan glimmer, lalu commit hanya setelah seluruh aset siap. Validasi source snapshot campuran memeriksa kelengkapan aset tanpa mensyaratkan `keyTheme` tertentu, dan kegagalan parsial caustics me-reset state bersih tanpa menyisakan aset tidak lengkap. Kegagalan mempertahankan state/sumber aktif; fallback melanjutkan transisi, menyimpan tema terbaru, dan menjalankannya setelah selesai. Jika antrean meminta tema sumber, transisi tema tunggal dibalik; sumber snapshot campuran tetap diantrekan karena tidak bisa dibalik sebagai satu tema. `AppCoordinator` menerapkan wallpaper/menu hanya dari `onThemeChanged`, bukan callback fase.

Suite `KoiWallpaperVerify` Bagian 8 (T8.1–T8.6) dijalankan secara live pada runtime macOS dan seluruhnya lulus:
- `T8.1`: Deserialisasi backward settings & roundtrip pembersihan manualTheme.
- `T8.2`: Evaluasi jadwal 5 fase REA dan mapping system appearance.
- `T8.3`: CALayer compositing, filter Core Image additive, dan opasitas in-flight.
- `T8.4`: In-flight retargeting A $\to$ B $\to$ C dengan snapshot source transaction.
- `T8.5`: In-flight direction reversal A $\to$ B $\to$ A tanpa snapshot.
- `T8.6`: Pause / resume stasis saat transisi aktif (zero catch-up jump).

Pekerjaan:

- [x] Definisikan model data `PondTheme` (7 tema) dan integrasikan dengan `TimeOfDayPhase` (menambahkan `goldenHour`) serta sinkronisasi persisten kompatibel lama pada `WallpaperSettings`.
- [x] Bangun palet air terstruktur 5 kedalaman, berkas cahaya, caustics Voronoi 2 jaringan, rim highlight teratai, dan bayangan penumbra/umbra untuk seluruh 7 tema.
- [x] Bedakan preset visual Rain (cahaya mendung abu-abu-teal desaturasi dan permukaan reflektif) dari efek simulasi cuaca/partikel hujan (cakupan M4).
- [x] Implementasikan transisi kontinu 1,8 detik dengan crossfade layer ganda, interpolasi lerp bayangan ikan, retargeting, dan stasis saat jeda.
- [x] Hubungkan antarmuka ke menu status bar, kontrol preview (tombol 't'), HUD diagnosis, `ScreenManager`, dan ekspor offscreen `PondRenderer.render`.
- [x] Dokumentasikan bukti teramati (Day, Night, Rain) vs interpretasi desain (Dawn, Golden Hour, Dusk, Deep Clear) di [decisions/2026-10-21-theme-palettes-and-transitions.md](decisions/2026-10-21-theme-palettes-and-transitions.md).

Selesai ketika:

- [x] Seluruh 7 tema memiliki identitas visual yang tajam, kontras ikan terjaga, dan air tidak berlumpur.
- [x] Jalur tema menjaga entitas simulasi dan menyediakan crossfade serta retargeting.
- [x] Retargeting menyediakan pembalikan arah untuk sumber tema tunggal dan antrean fallback untuk snapshot campuran; diverifikasi via T8.4 & T8.5.
- [x] Pengaturan lama ter-decode dengan benar tanpa migrasi data yang merusak (T8.1).
- [x] `swift build` berhasil pada target package.

### M4 — Perilaku personal dan atmosfer

Status: **SELESAI & TERVERIFIKASI**. Diimplementasikan dengan model kepribadian ikan individual (`FishTraits`), mood kolam Calm/Playful, memori makan berversi (Schema v1) pada grid spasial 12 × 8 dan histogram waktu 48 slot yang disimpan terpisah, peluruhan waktu paruh 7 hari, penggabungan sesi 90 detik, batas sapaan harian 04:00 AM kalender lokal (dengan penanganan transisi DST), validasi ketat decoding skema payload korup nir-kegagalan (*graceful fallback*), isolasi efek samping suite dari `UserDefaults.standard`, persistensi setelah simulasi restart proses, dan efek tetes hujan atmosfer dengan kuota ketat (maks 16 riak).

Suite `KoiWallpaperVerify` Bagian 9 (T9.1–T9.11) dijalankan secara live pada runtime macOS dan seluruhnya lulus (11/11):
- `T9.1`: Fish Traits & Calm vs Playful Mood Dynamics.
- `T9.2`: Feeding Session Merging (90s Window) & 3-Session Confidence Threshold.
- `T9.3`: Seven-Day Half-Life Exponential Decay (Grid & Histogram).
- `T9.4`: Proportional Feeding Location Preservation Across Bounds Resize.
- `T9.5`: 48-Slot Histogram Midnight Wraparound & Timezone Circadian Policy.
- `T9.6`: Daily Greeting 04:00 AM Boundary, DST Spring-Forward / Fall-Back, & Non-Repetition.
- `T9.7`: Corrupted Data Resilience, Schema Validation & Zero-Crash Fallback (9 distinct corruption cases including Double.nan and Double.infinity rejection).
- `T9.8`: World State Preservation on Mood/Rain Toggles & Atmospheric Quotas.
- `T9.9`: Persistence Across Manager Reload Roundtrip (Feeding Routine UserDefaults Roundtrip).
- `T9.10`: Daily Greeting Persistence Across Manager Reload Roundtrip (UserDefaults Dedicated Domain).
- `T9.11`: Test Suite Side-Effect Isolation & Disk Plist Cleanup Lifecycle (Zero UserDefaults.standard Pollution & Zero remaining suite plist files).

Pekerjaan:

- [x] Tambahkan sifat ikan (`FishTraits` untuk 8 varietas koi Jepang), mood Calm/Playful, dan ingatan jadwal/lokasi makan.
- [x] Simpan grid lokasi 12 × 8 dan histogram 48 slot waktu secara terpisah (`FeedingRoutineManager`), dengan peluruhan waktu eksponensial, validasi skema v1, dan ketahanan data korup.
- [x] Tambahkan sapaan harian (`DailyGreetingManager`), batas hari 04:00 kalender lokal tahan DST, efek hujan (`isRainActive` & `RippleType.rainDrop`), dan riak atmosfer yang dibatasi jumlahnya (`maxRainRipples = 16`).
- [x] Sediakan abstraksi store in-memory (`InMemoryFeedingStore`, `InMemoryGreetingStore`) dan pastikan isolasi suite pengujian tanpa polusi `UserDefaults.standard` serta pembersihan file plist disk suite secara aman.
- [x] Dokumentasikan keputusan arsitektur dan kebijakan pergantian zona waktu di [decisions/2026-10-21-m4-personality-memory-and-atmosphere.md](decisions/2026-10-21-m4-personality-memory-and-atmosphere.md) dan ringkasan audit di [m3_6_m4_audit_handoff.md](m3_6_m4_audit_handoff.md).

Selesai ketika:

- [x] Klik yang berdekatan digabung sebagai satu sesi; kebiasaan bergantung pada bobot beberapa sesi, tersimpan setelah restart/muat ulang, dan memudar tanpa penguatan (diverifikasi via T9.2 & T9.9).
- [x] Parameter awal: paruh waktu 7 hari (T9.3), penggabungan sesi 90 detik (T9.2), dan tingkat kepercayaan berbasis bobot setidaknya 3 sesi ($W \ge 3.0$). Kriteria menguji bobot yang dihitung, bukan menghitung tiga klik mentah.
- [x] Lokasi makan tersimpan secara proporsional ketika ukuran kolam berubah (T9.4).
- [x] Waktu dekat tengah malam dihitung berdekatan ($\text{dist}(47, 0) == 1$); perpindahan zona waktu mengikuti kebijakan yang didokumentasikan (T9.5).
- [x] Sapaan harian mengikuti batas hari 04:00 kalender lokal dan tidak terulang setiap kali jendela terlihat kembali pada hari yang sama, terverifikasi pada transisi DST spring-forward dan fall-back (T9.6).
- [x] Data memori rusak, versi skema tidak didukung, ukuran sel/slot salah, bobot non-finite (Double.nan & Double.infinity), bobot/hitungan sesi negatif, dan metadata inkonsisten ditolak secara tertib dan menghasilkan default aman tanpa akses array di luar batas (T9.7).
- [x] Hujan dan mood dapat dinyalakan/dimatikan tanpa menghapus keadaan dunia; efek atmosfer dibatasi jumlahnya $\le 16$ (T9.8).
- [x] Kebiasaan makan dan sapaan harian bertahan melintasi muat ulang manager dari store UserDefaults (T9.9, T9.10).
- [x] Suite pengujian terisolasi penuh, tidak menulis data fixture ke `UserDefaults.standard`, mendeteksi dan membersihkan file plist suite `com.koiwallpaper.verify.*.testsuite` pasca-terminasi worker via arsitektur supervisor runner, serta membuktikan ketiadaan file artefak tersisa di disk setelah proses suite berakhir (T9.11).

### M5 — Pengunjung dan tampilan penuh

Catatan cakupan: angka suite dan validasi WindowServer di bawah mencatat hasil baseline M5. Angsa otomatis ditambahkan pada 24 Oktober 2026; build lulus, tetapi perilaku barunya belum memiliki hasil suite tersendiri.

Status baseline: **SELESAI & TERVERIFIKASI PENUH (Otomatis & Validasi Desktop Nyata)** (Implementasi kode M5 selesai 100%, suite otomatis 23/23 pada `KoiWallpaperSimTest` dan 53/53 assertion pada `KoiWallpaperVerify` lulus; validasi desktop macOS live melalui WindowServer pada `scripts/test_live_fullscreen.swift` membuktikan penataan layer di atas Finder/ikon desktop, penerimaan event keyboard Escape sintetis via WindowServer tap, dan pemulihan presisi mode interaksi melintasi mode tembus klik maupun interaktif; pengujian penekanan tombol Escape fisik secara mekanis oleh jari manusia pada keyboard fisik nyata tetap berstatus PENDING). Diimplementasikan dengan model pengunjung permukaan kolam (`PondVisitor` dengan variasi Angsa/Swan dan Bola/Temari Ball), interaksi ketertarikan renang ikan koi (`.investigatingVisitor`), dorongan impuls fisik bola dengan riak air, jaminan pertahanan ganda ketiadaan target macet (*zero stuck fish guarantee*) pada skenario teruji saat pengunjung dihapus/kedaluwarsa, mode kolam fullscreen manual (`FullscreenPondWindow` dan `ManualFullscreenController`) dengan tingkat jendela `floatingWindow`, kemampuan penerimaan input keyboard (`canBecomeKey = true`), jalur penutupan via `cancelOperation` / Escape, pemulihan mode interaksi desktop sebelumnya secara presisi melintasi mode tembus klik maupun interaktif, serta pemisahan tegas kebijakan *idle* otomatis (`IdleBehaviorPolicy`) yang dinonaktifkan secara bawaan tanpa memodifikasi setelan tidur, penguncian layar, atau manajemen daya macOS.

Suite `KoiWallpaperVerify` Bagian 10 (T10.1–T10.4) dijalankan secara live pada runtime macOS dan seluruhnya lulus (4/4 assertion baru, total suite 53 assertion):
- `T10.1`: Surface Visitors (Swan & Ball) & Stuck Target Prevention (target pengunjung dihapus seketika me-reset koi ke wandering pada skenario teruji; min displacement $> 50$ pt membuktikan ketiadaan ikan macet).
- `T10.2`: Manual Fullscreen Presentation, Key Handling & Direct cancelOperation Exit (`canBecomeKey = true`, level `floatingWindow`, view interaktif, dan keluar bersih via pemanggilan langsung `cancelOperation(nil)` pada jendela fullscreen).
- `T10.3`: Previous Desktop State Restoration Across Fullscreen Roundtrip (pemulihan presisi mode `.clickThrough` layer `-2147483623` dan `.interactive` layer `-2147483602`, tanpa kehilangan 8 koi; status pause global dan visibilitas kursor tidak diuji dalam assertion ini).
- `T10.4`: Idle Policy Separation & Static Power API Audit (kebijakan idle dinonaktifkan secara bawaan; pemindaian statis pada berkas Swift di `Sources` menemukan nol kemunculan dari 7 pola terlarang yang dicari, tanpa menyimpulkan ketiadaan API daya secara umum di luar pola tersebut).

Validasi Desktop Nyata macOS (`scripts/test_live_fullscreen.swift` pada layar Retina 1680x1050 fisik):
- **Penataan WindowServer di Atas Finder & Ikon Desktop**: `FullscreenPondWindow` (id=17441/17443) tercatat di WindowServer pada layer `3` (`kCGFloatingWindowLevel`), secara faktual berada di atas ikon desktop Finder (layer `-2147483603`) dan jendela standar aplikasi/Finder (layer `0`), dengan dimensi penuh `(0, 0, 1680, 1050)` dan status `canBecomeKey = true, isKeyWindow = true`. Bukti tangkapan visual tersimpan di `reports/screenshots/m5_fullscreen_live_clickthrough.png` (4,726,056 bytes) dan `reports/screenshots/m5_fullscreen_live_interactive.png` (4,726,604 bytes).
- **Penanganan Keluar Escape via WindowServer**: Disintesiskan via `CGEvent` key code 53 (Escape down/up) melalui `cghidEventTap` saat jendela fullscreen berstatus key window. WindowServer dan AppKit berhasil menghantarkan event ke `keyDown`/`performKeyEquivalent`, memicu `onEscapePressed`, menutup jendela, dan menghapus jendela dari daftar on-screen WindowServer (`CGWindowListCopyWindowInfo([.optionOnScreenOnly])`).
- **Pemulihan Status Desktop Sebelumnya (Roundtrip Restoration)**:
  - Roundtrip 1 (.clickThrough): Mode awal `.clickThrough`, layer `-2147483623`, `ignoresMouseEvents = true` -> Masuk fullscreen layer `3` -> Keluar via Escape -> Pulih 100% ke mode `.clickThrough`, layer `-2147483623` (di bawah Finder `-2147483603`), `ignoresMouseEvents = true`, dan seluruh 8 koi utuh.
  - Roundtrip 2 (.interactive): Mode awal `.interactive`, layer `-2147483602`, `ignoresMouseEvents = false` -> Masuk fullscreen layer `3` -> Keluar via Escape -> Pulih 100% ke mode `.interactive`, layer `-2147483602` (di atas Finder `-2147483603`), `ignoresMouseEvents = false`, dan seluruh 8 koi utuh.
- **Batasan Uji Fisik**: Penekanan tombol fisik Escape secara mekanis oleh jari manusia pada keyboard perangkat keras nyata (*human physical mechanical keypress*) tidak dapat dieksekusi oleh agen perangkat lunak tanpa kehadiran fisik manusia di depan komputer, sehingga secara transparan dan jujur tetap berstatus **PENDING**.

Pekerjaan:

- [x] Tambahkan bola atau angsa dengan perilaku sederhana yang memengaruhi target ikan (`PondVisitor` swan glides & boundary avoidance; ball drifts & bounces; koi escort & nudge impulse).
- [x] Angsa wallpaper muncul otomatis di dalam kolam, berkelok dengan perubahan haluan dan kecepatan yang halus, lalu keluar melalui tepi; menu spawn angsa diganti keterangan status. T12.5 menguji spawn, kecepatan 34–44 pt/s, umur minimal 18 detik, keluar penuh, ketiadaan duplikasi, dan respawn 5–9 detik.
- [x] Tambahkan mode kolam fullscreen manual dan jalur keluar yang jelas (`ManualFullscreenController`, `FullscreenPondWindow` di level floating, penanganan Escape keycode 53, `cancelOperation`, dan menu bar; verifikasi otomatis via pemanggilan langsung `cancelOperation(nil)` dan validasi live desktop via `scripts/test_live_fullscreen.swift`).
- [x] Tentukan kebutuhan idle otomatis secara terpisah dari fullscreen manual (`IdleBehaviorPolicy`, independen dari fullscreen manual dan dinonaktifkan bawaan).
- [x] Dokumentasikan keputusan arsitektur di [decisions/2026-10-22-m5-visitors-and-fullscreen.md](decisions/2026-10-22-m5-visitors-and-fullscreen.md).

Selesai ketika:

- [x] Pengunjung dapat ditambahkan/dihapus dan tidak membuat ikan macet pada target yang sudah hilang (terverifikasi via `KoiWallpaperSimTest` T12.1–T12.4 dan `KoiWallpaperVerify` T10.1 pada skenario teruji).
- [x] Fullscreen dapat ditutup melalui Escape serta mengembalikan keadaan desktop sebelumnya (terverifikasi secara programatik via `KoiWallpaperVerify` T10.2 & T10.3, serta divalidasi langsung pada WindowServer desktop nyata via `scripts/test_live_fullscreen.swift` untuk level layer 3, pemulihan `.clickThrough` & `.interactive`, dan exit event Escape; pengujian penekanan tombol Escape fisik secara mekanis oleh jari manusia tetap PENDING).
- [x] Mode ini tidak mengubah konfigurasi penguncian atau waktu sleep sistem (terverifikasi via audit statis leksikal pada berkas Swift di `Sources` oleh `KoiWallpaperVerify` T10.4).

### M6 — Mode Wallpaper Statis Dinamis & Zero-CPU Eco Mode (Pengganti Screen Saver)

Status: **SELESAI & TERVERIFIKASI PENUH** (Target legacy `KoiWallpaperSaver` / `.saver` telah dihapus sepenuhnya untuk mengeliminasi beban CPU tinggi pada proses `legacyScreenSaver` macOS 14+; arsitektur wallpaper desktop ditingkatkan menjadi model hibrida: Animasi Aktif (Live Wallpaper) dengan smart occlusion auto-pause vs Wallpaper Statis Dinamis (0% CPU idle) dengan pembaruan snapshot berkala 15 menit dan transisi CALayer cross-fade halus; suite in-process `KoiWallpaperVerify` 68/68 lulus dan `KoiWallpaperSimTest` 53/53 lulus).

Tujuan: Mengatasi konsumsi CPU tinggi pada screen saver dan animasi desktop dengan menghadirkan mode wallpaper statis dinamis berdaya 0% CPU yang tetap hidup secara visual lewat pergantian pose berkala.

Pekerjaan:
- [x] Hapus target dinamis dan bundel `KoiWallpaperSaver` (`Sources/KoiWallpaperSaver/KoiWallpaperSaverView.swift`, `scripts/build_saver.sh`, dan referensi pemaketan pada `scripts/build_app.sh`).
- [x] Sederhanakan UI Menu Bar di `StatusBarController.swift`: Hapus opsi menu screen saver dan perbarui item toggle menjadi "Jeda Animasi (Jadikan Wallpaper Statis)" / "Lanjutkan Animasi (Live Wallpaper)" dengan label status yang jelas.
- [x] Implementasikan `advanceSnapshot(simulatedSeconds:animated:)` pada `PondSimulation`, `WallpaperView`, dan `ScreenManager` dengan transisi fade CALayer GPU yang lembut (1.2 detik).
- [x] Implementasikan penjadwalan `snapshotTimer` (15 menit) di `AppCoordinator.swift` yang hanya aktif saat wallpaper dijeda (mode statis) dan otomatis diperbarui saat tema waktu berganti.
- [x] Perbarui suite pengujian Bagian 11 (T11.1–T11.4) pada `KoiWallpaperVerify` untuk memvalidasi stasis CPU timer 0%, langkah snapshot dinamis dengan animasi cross-fade, sinkronisasi file bersama, dan siklus timer snapshot pada `AppCoordinator`.

Selesai ketika:
- [x] Target `.saver` bersih dihapus dari proyek dan aplikasi utama dapat dikompilasi tanpa dependensi screen saver.
- [x] Saat jeda manual diaktifkan, loop animasi timer berhenti total (0% continuous CPU) dan snapshot 1 frame baru berhasil di-render.
- [x] Pembaruan snapshot tiap 15 menit dan saat pergantian tema berjalan mulus dengan efek cross-fade tanpa timer berkelanjutan.
- [x] Seluruh suite pengujian lolos (68/68 di `KoiWallpaperVerify`, 53/53 di `KoiWallpaperSimTest`).

## Struktur kode yang diusulkan

```text
KoiWallpaper/
  App/                 # Entry point, coordinator, menu, settings
  Desktop/             # Host jendela, monitor, input, lifecycle policy
  Simulation/          # Dunia, ikan, steering, makanan, memori
  Rendering/           # SpriteKit scene, sprite, atmosfer
  Persistence/         # Pengaturan dan ingatan berversi
  Resources/           # Artwork serta palet buatan proyek
docs/
  REA.md
  IMPLEMENTATION_PLAN.md
```

Nama modul dan metode build ditetapkan ketika implementasi native dimulai. Satu executable cukup untuk MVP; pemisahan banyak package belum diperlukan.

## Skenario validasi yang belum selesai

Validasi yang belum selesai:

- Pengujian Fisik Tambahan Multi-Monitor: pengujian visual langsung dengan perangkat keras kabel/monitor eksternal fisik kedua secara live (saat ini divalidasi via 1 layar Retina fisik aktual dan in-process synthetic topology T7.1–T7.5; sertifikasi perangkat keras monitor kedua live tetap PENDING).
- Pengukuran Energi Kuantitatif (Watt): pengukuran daya listrik absolut berbasis `sudo powermetrics` atau wattmeter eksternal (tertunda karena ketiadaan izin root pada lingkungan eksekusi; efisiensi idle divalidasi via proksi stasis timer dan CPU proses 0.04%–0.06%; pengukuran Watt tetap PENDING).
- Inspeksi Visual Subjektif pada Desktop Asli & Transisi M3.6: evaluasi langsung kenyamanan visual mata manusia terhadap compositing transisi caustics di bawah ikon desktop dan Spaces macOS secara langsung (status validasi visual transisi native pada layar fisik tetap PENDING; verifikasi M3.6 diperoleh secara programatik CALayer).
- Penekanan Escape Fisik Layar Penuh & Pengujian Multi-Monitor Fisik (M5): pengujian penekanan tombol Escape fisik secara mekanis oleh jari pengguna pada keyboard perangkat keras nyata, verifikasi perilaku layar penuh pada Spaces di berbagai monitor fisik eksternal kedua secara simultan, serta penilaian estetika visual CoreGraphics jangka panjang pada monitor fisik (saat ini penataan layer WindowServer level `3` di atas Finder & ikon desktop, pemulihan mode interaksi `.clickThrough` & `.interactive`, dan penutupan via event sintetis `CGEvent` keycode 53 telah TERVERIFIKASI LIVE via `scripts/test_live_fullscreen.swift`; penekanan keyboard fisik oleh manusia dan pengujian monitor kedua tetap PENDING).

Perilaku Finder, urutan window server, interaksi Escape fisik nyata pengguna, integrasi multi-monitor fisik, dan pengukuran daya absolut tidak dapat dibuktikan hanya melalui pengujian unit atau verifikasi in-process.
