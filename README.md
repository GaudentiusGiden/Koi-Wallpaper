# Koi Wallpaper

Rencana aplikasi wallpaper kolam koi interaktif untuk macOS, dengan Nagomi sebagai referensi perilaku produk.

Status: implementasi fondasi aplikasi macOS M0 dan bundle lokal `.app` sudah tersedia dan berhasil dibangun. Verifikasi in-process (15 uji model/event/lifecycle + audit TCC) serta inspeksi aman Window Server live lulus. Namun, kriteria interaksi desktop riil (Finder click-through/drag/marquee, fokus, Spaces, Show Desktop, occlusion nyata, dan sleep/wake perangkat keras) belum divalidasi langsung di sesi GUI macOS pengguna; penerimaan M0 masih tertunda.

- [Audit M0 dan status bukti](docs/M0_AUDIT.md)
- [Analisis referensi dan rancangan teknis](docs/REA.md)
- [Temuan dari REA CLI dan bukti interaksi](docs/REA_FINDINGS.md)
- [Tahapan implementasi dan kriteria penerimaan](docs/IMPLEMENTATION_PLAN.md)

Implementasi saat ini memakai Swift dan AppKit untuk macOS 14+ pada arsitektur Apple Silicon. SpriteKit, simulasi gerak koi, dan penyimpanan lokal berada pada milestone berikutnya (M1 & M2).
