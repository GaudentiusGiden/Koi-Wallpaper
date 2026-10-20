# Rencana implementasi Koi Wallpaper

Rencana ini mengikuti [analisis referensi](REA.md) dan [hasil REA CLI](REA_FINDINGS.md). Fondasi native M0 telah dibangun, diverifikasi (executable `KoiWallpaper`, bundle `.app`, dan suite verifikasi `KoiWallpaperVerify`), dan **resmi diterima pada 20 Oktober 2026 (Asia/Jakarta)** dengan batasan platform WindowServer macOS yang disepakati (Koi Wallpaper terbukti tidak mengambil fokus; klik fisik pada kolam desktop dapat mengaktifkan Finder dan mendefokuskan aplikasi sebelumnya). Milestone **M1 (Simulasi Kolam Mandiri)** telah selesai diimplementasikan, diverifikasi melalui unit test in-process 17/17 lulus (termasuk 4 uji regresi geometri kapsul tirus T0.1–T0.4 dan uji non-penetrasi geometri kapsul multi-langkah deterministik T3.1 pada 5 skenario benturan ekstrim dengan oracle independen), dan divalidasi secara visual melalui 14 tangkapan layar Retina alur kerja dan 3 tangkapan layar benturan dinamis berhadapan pada jendela GUI macOS WindowServer dengan perbaikan tuntas pada cacat penumpukan makan, pembagian target sirkumferensial klik air, relaksasi posisi kapsul tulang belakang, dan pemotongan batas resize (status visual temporal kolam diklasifikasikan parsial untuk ketiadaan kerumunan jangka panjang; T3.1 berlaku pada skenario ber-seed dan bukan klaim jaminan universal matematis). Milestone **M2 (Wallpaper yang Dapat Dipakai)** telah selesai diimplementasikan penuh sebagai MVP satu monitor, mengintegrasikan simulasi M1 ke host desktop M0, menyediakan menu lengkap status bar, Time of Day multi-fase, persistensi pengaturan, isolasi multi-alasan pause baterai/sleep/manual, mitigasi lonjakan delta waktu simulasi, dan kode sumber bebas dependensi jaringan (terverifikasi melalui suite in-process 21 assertion `KoiWallpaperVerify` [15 regresi M0 + 6 penerimaan M2] dan 17/17 pada `KoiWallpaperSimTest`). Milestone **M3 (Banyak Monitor dan Efisiensi)** telah selesai diimplementasikan pada tingkat perangkat lunak dan arsitektur, menghadirkan `ScreenManager` untuk orkestrasi multi-display, dunia simulasi dan viewport mandiri per monitor dengan sinkronisasi pengaturan global, penanganan hot-plug (attach/detach bersih dengan pembersihan observer dan pelepasan memori tanpa jendela yatim atau timer bocor), adaptasi Retina heterogen, pemetaan origin negatif presisi, isolasi stasis occlusion mandiri per monitor, dan profil performa perangkat target (terverifikasi 27/27 lulus pada `KoiWallpaperVerify` dan 17/17 pada `KoiWallpaperSimTest`; validasi fisik multi-monitor dengan kabel/layar eksternal kedua serta pengukuran energi kuantitatif Watt tetap berstatus PENDING). Milestone berikutnya adalah **M4 (Perilaku Personal dan Atmosfer)**. Status dan rincian keputusan M0 dicatat di [audit M0](M0_AUDIT.md).

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

Status: **IMPLEMENTASI INTI & PENGUJIAN LULUS, VALIDASI VISUAL TEMPORAL PARSIAL** (Simulasi inti dan artwork CoreGraphics mandiri selesai, unit test in-process 17/17 assertion lulus termasuk uji regresi geometri kapsul tirus T0.1–T0.4 dan pemisahan fisik multi-langkah T3.1 deterministik dengan oracle independen, jendela preview `KoiWallpaperPreview` tervalidasi via 14 tangkapan layar Retina alur kerja dan 3 tangkapan layar benturan dinamis pada jarak minimum aktual; status visual live wandering diklasifikasikan parsial karena satu rekaman simulasi acak tidak membuktikan ketiadaan kerumunan sepanjang masa simulasi tanpa batas).

Tujuan: membuat perilaku inti yang dapat dilihat terlebih dahulu dalam jendela preview biasa.

Pekerjaan:

- [x] Implementasikan dunia simulasi mandiri terpisah dari AppKit (`PondSimulation`, `PondBounds`, `PondVector`).
- [x] Implementasikan PRNG deterministik ber-seed (SplitMix64 via `SeededRandomNumberGenerator`) untuk menjamin keterulangan 100% pada seluruh skenario pengujian simulasi.
- [x] Implementasikan autonomous steering: wandering halus, penghindaran tepi kolam (soft margin), pemisahan target klik perimeter riak ($R = 42$ pt), dan relaksasi posisi non-penetrasi fisik geometri kapsul tirus 5 segmen antarikan (`resolveFishSeparation` dengan safety margin $0.5$ pt dan kompensasi batas kolam). Model kapsul tirus adalah proxy konservatif massa tubuh utama (bukan kesetaraan analitik kurva Bézier visual).
- [x] Buat artwork CoreGraphics prosedural proyek sendiri untuk air, koi (8 varietas Jepang dengan artikulasi tulang & sirip hidrodinamis), tanaman teratai, bayangan, dan riak air, berbagi model geometri penampang melintang tulang belakang dengan simulasi.
- [x] Tambahkan animasi renang sinus/ekor/sirip, target sementara klik air sirkumferensial, pemberian pelet makanan via Option+klik, dan konsumsi pelet atomik sekali makan.
- [x] Pisahkan dunia simulasi, penanganan input, update fisika timestep tetap (catch-up clamping), dan visual renderer; batasi kuota pelet (48) dan riak (64).
- [x] Buat preview GUI mandiri (`KoiWallpaperPreview`) dengan jendela biasa, HUD diagnostik, mode validasi otomatis (--validate-visual), dan mode validasi benturan dinamis (--validate-collision) dengan deteksi titik belok jarak minimum.
- [x] Buat suite pengujian unit simulasi in-process (`KoiWallpaperSimTest`) dengan 17 assertion lulus 100% (termasuk 4 regresi geometri kapsul tirus dan oracle independen disk chain).

Selesai ketika:

- [~] Tampilan dan kontrol interaksi di jendela preview GUI diverifikasi secara visual melalui event GUI sintetis `NSEvent` via `window.sendEvent` (inspeksi 14 tangkapan layar alur kerja Retina aktual sekuensial 2048×1336 / 1440×976 dan 3 tangkapan layar benturan berhadapan dinamis `m1_collision_*.png`; 8 varietas koi, sirip hidrodinamis, bayangan, teratai, riak, pelet, atraksi klik biasa terpisah sirkumferensial, Option+klik makanan, konsumsi atomik dengan HUD akurat, pemisahan teramati, penyebaran keluar sekuensial, pembekuan pause 0.8s, resume bebas lonjakan, penyesuaian batas proporsional tanpa clipping pada resize jendela, dan reset elips acak terbukti bekerja). Ditandai **Parsial** karena inspeksi frame tunggal/sekuensial membuktikan lintasan yang diuji, namun bukan pembuktian ketiadaan kerumunan sepanjang masa simulasi tanpa batas (*infinite wandering*).
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

### M4 — Perilaku personal dan atmosfer

Pekerjaan:

- Tambahkan sifat ikan, mood Calm/Playful, dan ingatan jadwal/lokasi makan.
- Simpan grid lokasi 12 × 8 dan histogram 48 slot waktu secara terpisah, dengan peluruhan waktu dan versi skema.
- Tambahkan sapaan harian, hujan, dan efek malam yang dibatasi jumlahnya.

Selesai ketika:

- Klik yang berdekatan digabung sebagai satu sesi; kebiasaan bergantung pada bobot beberapa sesi, tersimpan setelah restart, dan memudar tanpa penguatan.
- Parameter awal: paruh waktu 7 hari, penggabungan sesi 90 detik, dan tingkat kepercayaan berbasis parameter minimal 3 sesi. Kriteria menguji bobot yang dihitung, bukan menghitung tiga klik mentah.
- Lokasi makan tersimpan secara proporsional ketika ukuran kolam berubah.
- Waktu dekat tengah malam dihitung berdekatan; perpindahan zona waktu mengikuti kebijakan yang didokumentasikan.
- Sapaan harian mengikuti batas hari 04:00 dan tidak terulang setiap kali jendela terlihat kembali pada hari yang sama.
- Data memori rusak tidak menghalangi peluncuran aplikasi.
- Hujan dan mood dapat dinyalakan/dimatikan tanpa menghapus keadaan dunia.

### M5 — Pengunjung dan tampilan penuh

Pekerjaan:

- Tambahkan bola atau angsa dengan perilaku sederhana yang memengaruhi target ikan.
- Tambahkan mode kolam fullscreen manual dan jalur keluar yang jelas.
- Tentukan kebutuhan idle otomatis secara terpisah dari fullscreen manual.

Selesai ketika:

- Pengunjung dapat ditambahkan/dihapus dan tidak membuat ikan macet pada target yang sudah hilang.
- Fullscreen dapat ditutup melalui Escape serta mengembalikan keadaan desktop sebelumnya.
- Mode ini tidak mengubah konfigurasi penguncian atau waktu sleep sistem.

Integrasi screen saver sistem, bila diperlukan, menjadi target tambahan tersendiri. Jangan menyebut fullscreen aplikasi sebagai integrasi screen saver macOS.

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

- M4 (Memori & Lifecycle): penggabungan sesi, peluruhan, restart, slot waktu melintasi tengah malam, batas hari sapaan 04:00, pergantian zona waktu, dan data rusak.
- Pengujian Fisik Tambahan Multi-Monitor: pengujian visual langsung dengan perangkat keras kabel/monitor eksternal fisik kedua secara live (saat ini divalidasi via 1 layar Retina fisik aktual dan in-process synthetic topology T7.1–T7.5).
- Pengukuran Energi Kuantitatif (Watt): pengukuran daya listrik absolut berbasis `sudo powermetrics` atau wattmeter eksternal (tertunda karena ketiadaan izin root pada lingkungan eksekusi; efisiensi idle divalidasi via proksi stasis timer dan CPU proses 0.04%–0.35%).

Perilaku Finder, urutan window server, integrasi multi-monitor fisik, dan pengukuran daya absolut tidak dapat dibuktikan hanya melalui pengujian unit atau verifikasi in-process.
