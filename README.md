# Koi Wallpaper

Wallpaper kolam koi untuk macOS 14+, dibuat dengan Swift, AppKit, CoreGraphics,
dan simulasi yang dapat berjalan mandiri, dengan Nagomi sebagai referensi
perilaku produk. Kode produk dan status validasinya
dirinci di [rencana implementasi](docs/IMPLEMENTATION_PLAN.md) dan [audit M5](docs/M5_AUDIT_REPORT.md).

## Angsa otomatis

Wallpaper menampilkan angsa langsung di dalam kolam. Angsa berenang dengan
lintasan yang berubah perlahan, lalu menuju tepi terdekat dan keluar layar.
Setelah jeda singkat, angsa muncul kembali di titik kolam yang berbeda. Angsa
memengaruhi rasa ingin tahu koi; menu tidak lagi menyediakan tombol untuk
mengundangnya secara manual.

Keputusan dan batas validasi fitur ini tercatat di
[keputusan pengunjung M5](docs/decisions/2026-10-22-m5-visitors-and-fullscreen.md).

## Menjalankan preview

Dari direktori proyek, jalankan preview interaktif dengan angsa otomatis:

```bash
swift run KoiWallpaperPreview --preview-swan
```

Untuk merender gambar statis dengan renderer aplikasi:

```bash
swift run KoiWallpaperPreview --render-swan-design build/swan-design-preview.png
open build/swan-design-preview.png
```

Preview interaktif hanya berjalan untuk ditinjau dan tidak memasang wallpaper.

## Dokumen proyek

- [Audit desktop M0](docs/M0_AUDIT.md)
- [Analisis referensi produk](docs/REA.md)
- [Temuan REA CLI](docs/REA_FINDINGS.md)
- [Fondasi visual M3.5](docs/VISUAL_FOUNDATION.md)
- [Keputusan arsitektur pengunjung dan fullscreen M5](docs/decisions/2026-10-22-m5-visitors-and-fullscreen.md)
