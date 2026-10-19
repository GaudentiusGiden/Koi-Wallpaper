# Rencana implementasi Koi Wallpaper

Rencana ini mengikuti [analisis referensi](REA.md) dan [hasil REA CLI](REA_FINDINGS.md). Fondasi native M0 kini tersedia dan berhasil dibangun (executable `KoiWallpaper`, bundle `.app`, dan test suite `KoiWallpaperVerify`). Suite in-process (15 uji) serta inspeksi Window Server safe mode lulus tanpa error. Namun, integrasi desktop nyata (klik/drag/marquee Finder, fokus non-stealing, Spaces, Mission Control, Show Desktop, occlusion riil, dan hardware sleep/wake) belum divalidasi manual di GUI macOS. Status rinci, batas verifikasi, dan checklist manual tersisa dicatat di [audit M0](M0_AUDIT.md).

## Urutan kerja

### M0 — Buktikan integrasi desktop

Status: implementasi M0 tersedia, verifikasi in-process lulus, penerimaan desktop M0 masih tertunda. Struktur window, menu, input routing, dan lifecycle policy telah terintegrasi dengan view (timer animasi berhenti saat pause dan lanjut tanpa lompatan saat resume; alasan manual pause tidak hilang oleh sleep/wake). Bukti integrasi Window Server (layer -2147483623 di bawah Finder -2147483603) telah terkonfirmasi secara safe/read-only. Validasi manual interaksi desktop riil menjadi prasyarat penerimaan akhir M0. Lihat [audit M0](M0_AUDIT.md).

Tujuan: memastikan aplikasi bisa menjadi wallpaper dan tetap nyaman dipakai bersama Finder sebelum membuat artwork serta simulasi lengkap.

Pekerjaan:

- [x] Buat app macOS minimal dengan menu bar dan jendela borderless berwarna statis.
- [x] Konfigurasi tingkat jendela, perpindahan Spaces, dan collection behavior (`.stationary`, `.canJoinAllSpaces`, `.ignoresCycle`, `.fullScreenAuxiliary`).
- [x] Implementasikan tembus klik (default) dan mode interaksi eksplisit (`.interactive`).
- [x] Sinkronkan status pause manual dan notifikasi sistem (`screensDidSleep`, `willSleep`, `sessionDidResignActive`) ke `WallpaperView` tanpa lompatan waktu saat resume.
- [x] Audit kebutuhan izin TCC (memastikan app tidak meminta atau membutuhkan izin Accessibility / Input Monitoring).
- [ ] Validasi manual desktop: klik, drag, dan seleksi marquee Finder pada mode biasa.
- [ ] Validasi manual desktop: fokus aplikasi tidak berpindah saat wallpaper diklik.
- [ ] Validasi manual desktop: navigasi Spaces, Show Desktop, Mission Control, dan fullscreen app lain.
- [ ] Validasi manual desktop: perilaku occlusion saat ditutup jendela lain dan sleep/wake fisik perangkat keras.

Selesai ketika:

- Ikon Finder dapat diklik, dipindah, dan diseleksi dalam mode biasa.
- Jendela tidak mengambil fokus aplikasi saat dipasang sebagai wallpaper.
- Mode interaksi bisa diaktifkan dan dihentikan dengan jelas dari menu.
- Perilaku pause saat tertutup sudah diketahui, termasuk keterbatasannya.
- Keputusan input akhir tercatat; jika klik langsung belum aman, keterbatasan tersebut tetap terlihat dalam cakupan MVP.

### M1 — Simulasi kolam mandiri

Tujuan: membuat perilaku inti yang dapat dilihat terlebih dahulu dalam jendela preview biasa.

Pekerjaan:

- Implementasikan dunia, steering, penghindaran tepi, dan jarak antarikan.
- Buat artwork awal sendiri untuk air, koi, tanaman, bayangan, dan riak.
- Tambahkan animasi ekor/sirip, target panggilan, makanan, serta konsumsi pelet.
- Pisahkan input, update dunia, dan render; batasi objek efek.

Selesai ketika:

- Delapan koi berenang dan berbelok secara halus tanpa keluar dari kolam.
- Klik mengundang ikan dan Option + klik menaruh makanan pada lokasi yang sesuai.
- Ikan mendekati dan mengonsumsi makanan; satu pelet tidak bisa dikonsumsi dua kali.
- Input berulang tidak membuat jumlah pelet atau riak tumbuh tanpa batas.
- Kecepatan simulasi tetap konsisten ketika frame rate berubah.

### M2 — Wallpaper yang dapat dipakai

Tujuan: menyatukan hasil M0 dan M1 menjadi MVP satu monitor.

Pekerjaan:

- Pasang scene kolam pada host desktop hasil M0.
- Tambahkan menu Pause/Resume, Interaction Mode, Time of Day, Settings, dan Quit.
- Implementasikan fase waktu Auto/manual, pilihan mengikuti tema sistem, dan penyimpanan pengaturan.
- Kelola alasan pause manual, baterai, tertutup, sleep, dan sesi tidak aktif.

Selesai ketika:

- Pengaturan kembali setelah aplikasi diluncurkan ulang.
- Pergantian fase waktu tidak menghapus ikan atau makanan.
- Memasang charger tidak melanjutkan kolam yang dipause secara manual.
- Resume dari sleep tidak membuat ikan meloncat.
- Perilaku Finder dan mode interaksi tetap memenuhi keputusan M0.
- Kolam berjalan tanpa jaringan.

**M2 adalah batas MVP awal.** Dukungan beberapa monitor dan memori rutinitas belum boleh diklaim pada tahap ini.

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

Validasi yang direncanakan, belum dijalankan:

- Perilaku dunia: konsumsi pelet tunggal, batas objek, kedaluwarsa, dan gerak pada delta waktu berbeda.
- Memori: penggabungan sesi, peluruhan, restart, slot waktu melintasi tengah malam, batas hari sapaan 04:00, pergantian zona waktu, dan data rusak.
- Lifecycle: kombinasi alasan pause dan resume dari sleep.
- Integrasi desktop manual: ikon Finder, drag, Show Desktop, Spaces, Mission Control, fullscreen aplikasi lain, dan hot-plug monitor.
- Pengukuran: aktif, tertutup, pause manual, baterai, serta satu/beberapa monitor dengan kondisi yang dicatat.

Perilaku Finder, urutan window server, dan pemakaian energi tidak dapat dibuktikan hanya melalui pengujian unit.
