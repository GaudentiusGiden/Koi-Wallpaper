# Penyelarasan Visual dengan Nagomi

Tanggal: 22 Oktober 2026 (Asia/Jakarta).
Status: Implementasi selesai; `swift build` berhasil; pemeriksaan visual runtime belum dijalankan.

## Latar Belakang

Palet M3.6 sudah membedakan tujuh tema, tetapi nilai warna air, caustics, bayangan, vegetasi, dan kilau tersebar di beberapa renderer. Perbandingan dengan bukti Nagomi memperlihatkan Day, Night, dan Rain sebagai referensi langsung; Dawn, Golden Hour, Dusk, dan Deep Clear tetap merupakan interpretasi desain proyek.

Konsep yang disetujui adalah [contact sheet tujuh tema](assets/2026-10-22-visual-alignment-concept.png). Gambar tersebut menjadi arahan visual, bukan aset produksi atau target piksel yang persis.

## Keputusan

- Sediakan satu palette internal per `PondTheme`; layer air, atmosfer, caustics, bayangan, tanaman, bunga, dan kilau membaca nilai tema yang sama.
- Day memakai air jade/mint lebih terang dengan bukaan atas dan berkas cahaya diagonal yang lebih jelas. Night memakai navy dengan aksen cyan redup; Rain memakai abu-abu-teal reflektif tanpa menambahkan hujan ke preset visual.
- Dawn, Golden Hour, Dusk, dan Deep Clear mengikuti deskripsi M3.6, diselaraskan dengan perlakuan visual yang sama.
- Pertahankan warna dasar dan corak varietas koi. Beri tint ambient lembut sesuai tema hanya pada bayangan bawah dan pantulan punggung, lalu interpolasikan nilainya selama transisi. Artwork tetap digambar oleh renderer CoreGraphics proyek; screenshot Nagomi tidak dimuat sebagai aset.
- Batasi raster cache air pada skala maksimal `0.85` backing pixel per point dan kurangi noise sedimen statis. Cache palette bersifat statis; tint koi hanya menambah interpolasi warna ringan, tanpa layer, tekstur, atau efek tambahan.
- Siklus tema, pengaturan, simulasi, preset hujan, efek hujan opsional, dan transisi 1,8 detik tidak berubah.

## Bukti dan Batas

- [Fullscreen Day Nagomi](../../analysis/rea/nagomi/screenshots/fullscreen-visible.png) menjadi acuan Day dan karakter artwork.
- Screenshot Night dan Rain dalam arsip REA menjadi acuan suasana kedua tema tersebut. Bukti REA menunjukkan preset Rain dan sakelar efek hujan terpisah.
- Empat tema tanpa screenshot langsung menggunakan breakdown lama di [keputusan palet M3.6](2026-10-21-theme-palettes-and-transitions.md).
- Konsep memakai ilustrasi baru, sehingga detail gambar tidak menjamin hasil runtime akan identik.

## Validasi

`swift build` berhasil. Pemeriksaan visual runtime tujuh tema masih perlu dijalankan pada ukuran canvas yang sama, dengan perhatian pada keterbacaan koi, kontras tema, kekuatan bukaan cahaya, dan transisi antar tema.
