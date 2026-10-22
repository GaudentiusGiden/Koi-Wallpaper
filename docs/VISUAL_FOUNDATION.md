# Fondasi visual M3.5 — revisi sesuai acuan REA

Tanggal: 21 Oktober 2026 (Asia/Jakarta).

Palet dan perlakuan visual terbaru menyelaraskan tujuh tema dengan konsep Nagomi pada 22 Oktober. Rincian keputusan, bukti langsung, dan batas referensi ada di [keputusan penyelarasan visual](decisions/2026-10-22-visual-alignment-nagomi.md); angka di bawah ini tetap merekam revisi fondasi sebelumnya.

Revisi pencahayaan berikutnya tersedia pada [review cahaya dan bayangan](../reports/water-shadow-review.html), dengan [catatan perubahan dan verifikasi](decisions/2026-10-21-background-visual-enhancement.md). Revisi tersebut menyesuaikan naungan kanopi, sorotan air, eksposur caustics, serta arah bayangan koi, teratai, dan ikan kecil. Screenshot serta angka dalam dokumen fondasi di bawah tetap merupakan rekaman revisi fondasi sebelumnya.

Revisi ini melanjutkan implementasi M3.5 sebelumnya, dengan proporsi dan komposisi yang dinilai terhadap screenshot acuan. Pengguna menyetujui penyesuaian ukuran fisik koi bersama artwork serta penambahan ikan kecil dekoratif. Implementasi perangkat lunak M3 sudah selesai pada `f88406c`; validasi fisik monitor eksternal kedua dan pengukuran energi Watt tetap tertunda.

[Perbandingan visual interaktif](../reports/visual-review.html) menampilkan screenshot REA, hasil revisi pada viewport yang sama, versi sebelumnya, serta screenshot native preview dan desktop. Referensi utama adalah [fullscreen REA](../analysis/rea/nagomi/screenshots/fullscreen-visible.png), dengan [feed-response](../analysis/rea/nagomi/screenshots/feed-response.png) untuk detail koi. Screenshot referensi hanya dipakai dalam laporan review; aplikasi menghasilkan artwork sendiri melalui CoreGraphics.

## Implementasi

### Proporsi dan artwork

- Grid artwork mengikuti sisi pendek viewport dengan target 270 logical pixel. Pembesaran dibulatkan ke backing pixel integer, minimum satu; bentuk tidak diregangkan. Rasio 16:9 menghasilkan grid mendekati 480 × 270, termasuk adaptasi Retina.
- Delapan varietas koi memakai siluet lurus sebesar 12%, 15%, 13%, 17%, 14%, 18%, 16%, dan 12,5% sisi pendek kolam. Lebar torso produksi 34% parameter panjang tubuh. Kepala/pundak, sirip, ekor, corak tidak beraturan, dan palet terbatas digambar ulang.
- Panjang tubuh diperbarui saat spawn/reset/resize. Spine, capsules, posisi mulut, dan envelope ekor mengikuti ukuran yang sama. Envelope tetap mencakup seluruh ayunan ekor sehingga tidak tumbuh setelah posisi dijepit ke batas kolam. `initialFish` mempertahankan dimensi yang diberikan pemanggil; default rasio lebar konstruktor tetap 0,28.
- Enam kelompok vegetasi terdiri atas 16 daun teratai, empat bunga, serta tanaman kecil yang bertumpuk. Layout asimetris membingkai tepi dan menyisakan tengah untuk berenang. Setiap kelompok di-cache sebagai gambar terpotong, dengan arah bayangan dunia yang konsisten.
- Terdapat 24 ikan dekoratif, dibagi menjadi tiga kelompok berisi delapan. Panjang 1,5–2,5% sisi pendek. Geraknya dihitung dari waktu aktif dan seed visual terpisah; tidak masuk populasi koi, RNG dunia, collision, target klik, atau konsumsi makanan.

### Air dan komposit native

Air menggunakan warna jade, bidang kedalaman, beberapa sorotan lebar yang lembut, serta tekstur dasar berseed. Dua jaringan caustics Voronoi berbeda ukuran bergerak dengan arah dan periode berbeda. Kilau lokal, gerak kelompok tanaman, dan ikan kecil memakai `PondSimulation.elapsedTime`; pause membekukan seluruh scene, reset mengembalikan jam visual, dan resume mengikuti catch-up clamp yang sudah ada.

`PondRenderer` menyediakan sumber artwork/frame bersama. `PondSceneLayer` mengompositkan frame tersebut melalui CALayer pada preview dan `WallpaperView`. Urutan layer: air/caustics → bayangan dan ikan kecil → koi/pelet → refleksi/riak → vegetasi → HUD.

Kedua view memakai `wantsUpdateLayer` agar pembaruan scene tidak menggambar ulang bitmap viewport melalui AppKit. HUD dan banner menggunakan overlay transparan maksimal 520 × 130 pt yang melewatkan hit testing ke view induk. Overlay disembunyikan saat tidak dibutuhkan. Semua animasi implisit Core Animation dimatikan; layer berubah mengikuti timestep aplikasi.

Tiga cache air dibatasi masing-masing pada sisi 1536 pixel dan 2,25 megapixel, maksimal sekitar 27 MB data RGBA per renderer sebelum overhead CoreGraphics/CoreAnimation. GPU menginterpolasi cahaya secara halus. Cache diganti saat ukuran, backing scale, atau fase berubah. Bitmap swimmer beresolusi rendah digunakan ulang dan cache tanaman hanya dibangun ulang saat layout/grid berubah. Pool garis permukaan dibatasi 140 CAShapeLayer: 12 kilau dan maksimal dua lingkaran untuk masing-masing 64 riak.

`PondRenderer.render(...)` tetap tersedia untuk ekspor offscreen dengan artwork dan urutan layer yang sama. Komposit CPU ekspor diukur terpisah dari jalur native.

### Antarmuka dan kompatibilitas

- `KoiFish` menerima parameter opsional `bodyWidthRatio`, default 0,28. Panjang hanya dapat diperbarui di dalam modul simulasi.
- `PondSceneLayer(renderer:)` dan `update(simulation:bounds:backingScale:phase:)` dipakai bersama oleh preview/desktop.
- `PondOverlayView` menyimpan callback gambar HUD dan melewatkan klik; kedua view menyediakan penghitung diagnostik `totalRenderedFrames`.
- Pengaturan tersimpan, aturan steering/makan, input, koordinat monitor, pause, dan lifecycle M3 tetap digunakan. Tidak ada migrasi data atau dependensi baru. Fase waktu lama tetap tersedia. Mood, memori, sapaan, hujan, dan variasi malam M4 tidak ditambahkan.

## Verifikasi

Build release dan bundle lokal `build/KoiWallpaper.app` berhasil dibuat serta ditandatangani ad-hoc.

**19/19 uji simulasi lulus.** Termasuk seluruh regresi lama, proporsi produksi, identitas ikan saat resize, kompatibilitas ukuran custom, serta lima skenario ukuran produksi: berhadapan, berpotongan, konvergensi klik, konvergensi makanan, dan dekat dinding disertai resize. Oracle disk-chain dan pemeriksaan capsule tidak menemukan penetrasi pada lintasan yang diuji. Pengujian ini tidak membuktikan seluruh lintasan acak tanpa batas.

**32/32 pemeriksaan aplikasi lulus.** Mencakup lifecycle/multi-monitor M3, preservasi entity antar fase, freeze byte-identical saat pause, resume clamp, isolasi RNG ikan dekoratif, pool layer terbatas, grid backing integer pada skala 1×/2× dan ukuran ganjil, serta hit testing overlay.

Komposisi diukur pada 1024 × 640 pt: **21,04%** pixel berisi vegetasi opak, dalam target 20–30%. Bagian tengah sampel (25–75% lebar dan 20–80% tinggi) **97,82% terbuka**. Gambar native serta frame rekaman ditinjau untuk proporsi koi, vegetasi, palet/cahaya, pola caustics, urutan kedalaman, dan gerak/interaksi.

### Performa

Pengukuran verifier: MacBook Air Apple M1, satu layar fisik 1680 × 1050 pt pada Retina, baterai 56%.

| Jalur native | Ukuran | p95 persiapan frame + pengiriman layer CPU | Anggaran |
| --- | --- | --- | --- |
| Preview | 1024 × 640 pt, 2× | 0,51 ms | 16,67 ms / 60 FPS |
| Desktop | 1680 × 1050 pt, 2× | 0,52 ms | 33,33 ms / 30 FPS |

T7.7 mengukur 60 frame setelah lima frame pemanasan. Ini adalah biaya CPU untuk frame/model layer; komposit GPU dan presentasi VSYNC diukur melalui mekanisme yang berbeda.

Review preview native mencatat **59,7 update scene/detik** selama 14 detik awal. Cadence timer desktop terukur **29,3 Hz**. Rekaman preview final berdurasi **23,65 detik**, berukuran **2048 × 1336 px**, dengan frame rate berkas sekitar **59,96 FPS**; frame pada detik 3 dan 20 telah diperiksa. Cadence update, frame rate rekaman, dan VSYNC adalah metrik yang berbeda.

RSS proses verifier terukur **119,30 MB**, di dalam gate M3 220 MB. Batas cache air mengatasi footprint yang terlalu tinggi pada percobaan cache Retina penuh. Throughput ekspor CoreGraphics offscreen T7.6 terukur **41,8 FPS** pada bitmap 1×. Ambang ekspor menjadi 30 FPS sejak komposit aplikasi berpindah ke CALayer; anggaran native 60/30 diperiksa di T7.7 dan review AppKit. Gate memori, penghentian timer saat pause, dan batas lainnya dipertahankan.

Inspeksi bundle desktop melalui `scripts/test_live_app.swift` memakai mode read-only. Screenshot host desktop Day diambil melalui `AppCoordinator`/`ScreenManager` nyata dengan `InMemorySettingsStore`, tanpa mengubah preferensi pengguna. Host berada pada layer `-2147483623`, di bawah layer ikon Finder `-2147483603`. Validasi kabel/monitor kedua dan konsumsi Watt tetap mengikuti batas bukti M3.

## Meninjau hasil

Buka [laporan visual lokal](../reports/visual-review.html). Tombol di atas perbandingan menukar hasil revisi dengan implementasi sebelumnya. Kedua gambar ditampilkan utuh; hasil revisi khusus perbandingan memakai viewport 1280 × 1000 yang sama dengan acuan.

Preview interaktif:

```bash
swift run -c release KoiWallpaperPreview
```

**H** menyembunyikan HUD, **Space** menjeda, **R** mereset, klik memanggil koi, dan **Option + klik** memberi makan. Amati kolam selama 20–30 detik, lalu resize jendela. HUD menampilkan cadence timer, bukan presentasi VSYNC.

Review native otomatis:

```bash
swift run -c release KoiWallpaperPreview --review-style
```

Mode ini memakai seed 42, menyembunyikan HUD, membawa preview ke depan selama review, mengirim panggilan air/makanan langsung ke simulasi, menjeda pada detik 15–17, lalu menutup proses sekitar detik 28. Screenshot dan video area preview disimpan di `build/visual-review/`. Perekaman menggunakan fasilitas Screen Recording macOS. Video merupakan artefak lokal yang dapat dibuat ulang; direktori build tidak masuk Git.

Wallpaper desktop:

```bash
bash scripts/build_app.sh
open build/KoiWallpaper.app
```

Tutup versi lama melalui **Keluar Koi Wallpaper** sebelum membuka bundle baru. Untuk meninjau palet utama, pilih **Waktu Kolam → Siang (Day)**. Gunakan **Settings → Tampilkan HUD Diagnostik**, **Pause/Resume**, dan **Interaction Mode** untuk memeriksa kontrol yang sudah ada.

Artefak:

- [Screenshot preview native](../reports/screenshots/style_native_preview.png).
- [Screenshot host desktop native Day](../reports/screenshots/style_native_desktop.png).
- [Render pada viewport acuan](../reports/screenshots/style_reference_viewport.png).
- [Frame offscreen awal](../reports/screenshots/style_foundation_t0.png) dan [setelah 12 detik](../reports/screenshots/style_foundation_t12.png).
- [Rekaman preview native lokal](../build/visual-review/native-preview.mov), dapat dibuka di QuickTime Player.
