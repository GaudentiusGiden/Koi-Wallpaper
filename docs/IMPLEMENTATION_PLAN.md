# Rencana implementasi Koi Wallpaper

Rencana ini mengikuti [analisis referensi](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/docs/REA.md) dan [hasil REA CLI](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/docs/REA_FINDINGS.md). Fondasi native M0 telah dibangun, diverifikasi (executable `KoiWallpaper`, bundle `.app`, dan suite verifikasi `KoiWallpaperVerify`), dan **resmi diterima pada 20 Oktober 2026 (Asia/Jakarta)** dengan batasan platform WindowServer macOS yang disepakati (Koi Wallpaper terbukti tidak mengambil fokus; klik fisik pada kolam desktop dapat mengaktifkan Finder dan mendefokuskan aplikasi sebelumnya). Milestone **M1 (Simulasi Kolam Mandiri)** telah selesai diimplementasikan, diverifikasi melalui unit test in-process 17/17 lulus (termasuk 4 uji regresi geometri kapsul tirus T0.1–T0.4 dan uji non-penetrasi geometri kapsul multi-langkah deterministik T3.1 pada 5 skenario benturan ekstrim dengan oracle independen), dan divalidasi secara visual melalui 14 tangkapan layar Retina alur kerja dan 3 tangkapan layar benturan dinamis berhadapan pada jendela GUI macOS WindowServer dengan perbaikan tuntas pada cacat penumpukan makan, pembagian target sirkumferensial klik air, relaksasi posisi kapsul tulang belakang, dan pemotongan batas resize (status visual temporal kolam diklasifikasikan parsial untuk ketiadaan kerumunan jangka panjang; T3.1 berlaku pada skenario ber-seed dan bukan klaim jaminan universal matematis). Milestone **M2 (Wallpaper yang Dapat Dipakai)** telah selesai diimplementasikan penuh sebagai MVP satu monitor, mengintegrasikan simulasi M1 ke host desktop M0, menyediakan menu lengkap status bar, Time of Day multi-fase, persistensi pengaturan, isolasi multi-alasan pause baterai/sleep/manual, resume bebas lonjakan, dan eksekusi 100% offline (terverifikasi 21/21 lulus pada `KoiWallpaperVerify` dan 17/17 pada `KoiWallpaperSimTest`). Milestone berikutnya adalah **M3 (Banyak Monitor dan Efisiensi)**. Status dan rincian keputusan M0 dicatat di [audit M0](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/docs/M0_AUDIT.md).

## Urutan kerja

### M0 — Buktikan integrasi desktop

Status: **DITERIMA** (Keputusan pengguna 20 Oktober 2026, Asia/Jakarta, dengan batasan platform yang disepakati). Implementasi M0 tersedia dan verifikasi in-process lulus. Integrasi Window Server (layer -2147483623 di bawah Finder -2147483603) dan pengujian interaksi pengguna (Finder, Mode Interaksi, Spaces/fullscreen, Show Desktop, Mission Control, occlusion `.covered`, dan hardware sleep/wake) telah diverifikasi. Kriteria non-stealing terbukti penuh (Koi Wallpaper tidak pernah mengambil fokus atau menu bar). Keterbatasan WindowServer macOS (klik desktop mengaktifkan Finder dan mendefokuskan aplikasi aktif sebelumnya) diterima secara formal sebagai batasan platform M0 tanpa mengklaim retensi fokus aplikasi sebelumnya lulus. Proyek resmi melangkah ke M1. Lihat [audit M0](file:///Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/docs/M0_AUDIT.md).

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

Status: **SELESAI & TERVERIFIKASI (MVP SATU MONITOR)** (Simulasi kolam mandiri M1 telah dipasang pada host desktop M0 melalui `WallpaperView`; menu status bar lengkap Pause/Resume, Interaction Mode, Time of Day, Settings, dan Quit telah tersedia; fase waktu Auto, systemTheme, dan manual terimplementasi; persistensi pengaturan via `SettingsManager` bertahan melintasi peluncuran ulang; alasan pause manual, baterai/daya, jendela tertutup, sleep, dan sesi tidak aktif terisolasi mandiri sehingga charger terpasang tidak membatalkan pause manual; resume dari sleep terbukti bebas lonjakan dan aplikasi berjalan 100% tanpa jaringan. Seluruh acceptance criteria terverifikasi 21/21 assertion lulus pada `KoiWallpaperVerify` dan 17/17 assertion lulus pada `KoiWallpaperSimTest`).

Tujuan: menyatukan hasil M0 dan M1 menjadi MVP satu monitor.

Pekerjaan:

- [x] Pasang scene kolam pada host desktop hasil M0 (`WallpaperView` terintegrasi dengan `PondSimulation`, `PondRenderer`, timer animasi 60 FPS, dan mitigasi lag).
- [x] Tambahkan menu Pause/Resume, Interaction Mode, Time of Day, Settings, dan Quit (`StatusBarController` menu bar dengan submenu lengkap).
- [x] Implementasikan fase waktu Auto/manual, pilihan mengikuti tema sistem, dan penyimpanan pengaturan (`TimeOfDayController`, `WallpaperSettings`, `SettingsManager`).
- [x] Kelola alasan pause manual, baterai, tertutup, sleep, dan sesi tidak aktif (`LifecyclePolicy` + `PowerSourceMonitor`, isolasi multi-alasan).

Selesai ketika:

- [x] Pengaturan kembali setelah aplikasi diluncurkan ulang (terverifikasi via `KoiWallpaperVerify` T6.1).
- [x] Pergantian fase waktu tidak menghapus ikan atau makanan (terverifikasi via `KoiWallpaperVerify` T6.3, 8 koi dan pelet utuh melintasi siklus dawn/day/dusk/night).
- [x] Memasang charger tidak melanjutkan kolam yang dipause secara manual (terverifikasi via `KoiWallpaperVerify` T6.4 multi-reason isolation).
- [x] Resume dari sleep tidak membuat ikan meloncat (terverifikasi via `KoiWallpaperVerify` T6.5, perpindahan maksimal 5.69 pt pada lonjakan 3600 detik).
- [x] Perilaku Finder dan mode interaksi tetap memenuhi keputusan M0 (terverifikasi via `KoiWallpaperVerify` T1.1–T3.3).
- [x] Kolam berjalan tanpa jaringan (terverifikasi via `KoiWallpaperVerify` T6.6, audit nol dependensi jaringan).

**Batas scope & catatan audit:**
1. M2 adalah batas MVP awal satu monitor. Dukungan multi-monitor (M3) dan memori rutinitas (M4) tidak boleh diklaim pada tahap ini.
2. Catatan audit M1 dipertahankan: Uji deterministik T3.1 membuktikan ketiadaan penetrasi pada 5 skenario ber-seed ekstrim dengan oracle independen (disk chain padat), namun tidak diubah menjadi klaim jaminan universal matematis sembarang lintasan. Status ketiadaan kerumunan jangka panjang (*infinite wandering zero-clumping*) tetap diklasifikasikan sebagai **Parsial**. Geometri 5 kapsul tulang belakang berartikulasi dipertahankan utuh tanpa perubahan karena tidak menjadi penghalang untuk M2.

### M3 — Banyak monitor dan efisiensi

Pekerjaan:

- Tambahkan dunia serta host terpisah per monitor dengan pengaturan global.
- Tangani hot-plug, skala Retina, perubahan ukuran, dan koordinat origin negatif.
- Pastikan scene yang tertutup/sleep berhenti secara mandiri.
- Ukur penggunaan CPU, GPU, RAM, dan energi pada perangkat target.

Selesai ketika:

- Monitor dapat dipasang/dilepas tanpa jendela yatim atau renderer yang tertinggal.
- Klik dan makanan jatuh di posisi yang benar di semua monitor yang didukung.
- Menutup kolam pada satu monitor tidak menghentikan kolam yang masih terlihat di monitor lain.
- Tersedia catatan pengukuran beserta perangkat, jumlah monitor, resolusi, FPS aktual, dan kondisi daya.

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

- M2/M4 (Memori & Lifecycle): penggabungan sesi, peluruhan, restart, slot waktu melintasi tengah malam, batas hari sapaan 04:00, pergantian zona waktu, dan data rusak.
- M3 (Pengukuran & Multi-monitor): aktif, tertutup, pause manual, baterai, serta satu/beberapa monitor dengan kondisi yang dicatat, dan hot-plug monitor.

Perilaku Finder, urutan window server, dan pemakaian energi tidak dapat dibuktikan hanya melalui pengujian unit.
