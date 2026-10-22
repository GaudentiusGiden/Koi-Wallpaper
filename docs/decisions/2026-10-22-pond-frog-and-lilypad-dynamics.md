# Katak Kolam pada Teratai (Pond Frog & Lily Pad Dynamics)

**Date**: 2026-10-22  
**Status**: Implemented & Verified

---

## 1. Konteks & Ringkasan

Menambahkan satu katak (*Nihon Amagaeru* / Japanese Tree Frog) dengan varian terpilih **Opsi D: Hasu Kaeru (Katak Bertopi Kelopak Teratai)** yang menghuni daun teratai (*lily pad*) di kolam:
- **Posisi**: Berada di daun teratai utama **pojok kiri bawah** (Cluster 1, Pad 1 di atas bunga teratai merah muda).
- **Ukuran Diperbesar**: Skala proporsi tubuh dinaikkan menjadi **~1,8× lebih besar** (panjang ~34 pt, lebar ~30 pt) agar siluet piksel, mata emas, jari berselaput, dan gelembung suara tampak jelas dan tegas (*chunky*).
- **Aksen Unik (Opsi D)**: Katak mengenakan kelopak bunga teratai merah muda (*pink lotus petal*) di kepalanya sebagai topi mungil yang menawan.
- **Tidak Hanya Diam**: Saat hinggap, katak menampilkan mikro-animasi hidup:
  - Kantung suara berdenyut ritmis mengikuti napas (~1,8 Hz).
  - Pendaran / gelembung suara membesar (*croak vocal puff*) tiap 5–9 detik menjadi balon bulat transparan.
  - Mata mengedip (*eye blink*) tiap 3–5 detik.
  - Kepala menoleh lembut (*head twitch*) tiap 4–7 detik.
- **Siklus Melompat & Menghilang**:
  - Setelah hinggap 11–17 detik (atau seketika saat diklik air di dekatnya), katak melakukan ancang-ancang (*crouch*), lalu melompat ke udara membentuk busur parabolik meluncur sejauh ~120 pt ke arah timur laut (menuju tengah kolam).
  - Mendarat di air terbuka dan memicu riak cipratan air (*splash ripple*), lalu menyelam / menghilang (*away*) selama 5,5–9,5 detik.
  - Katak melompat kembali dari air ke atas daun teratai dengan lintasan parabolik, mendarat dengan efek bantalan (*squash-and-stretch cushion*), dan kembali bersantai di daun teratai.

---

## 2. Struktur Model & Kinematika (`PondFrog.swift`)

1. **State Machine (`PondFrogState`)**:
   - `.perched`: Hinggap di daun teratai, posisi terkunci di daun teratai, menjalankan mikro-animasi napas, kedip, dan kuak.
   - `.crouching`: Ancang-ancang menurunkan badan (0,20 detik) sebelum dorongan melompat.
   - `.jumpingOut`: Melompat parabolik menuju air terbuka (durasi 0,72 detik, $z(t) = 4 \cdot \text{apex} \cdot t(1-t)$).
   - `.away`: Menyelam di bawah daun teratai atau berenang di luar pandangan (5,5–9,5 detik, `isVisible == false`).
   - `.jumpingIn`: Melompat kembali dari air menuju daun teratai (0,74 detik).
   - `.landing`: Mendarat dengan efek membal squish-and-stretch (0,24 detik) lalu kembali ke `.perched`.

2. **Interaktivitas (*Click Startle*)**:
   - Jika pengguna mengklik air dalam radius 48 pt dari katak yang sedang hinggap, katak terkejut (*startled*) dan seketika memulai ancang-ancang melompat ke air.

3. **Adaptasi Skala Layar**:
   - Koordinat hinggap dihitung proporsional dari jangkar daun teratai (`PondFloraArtwork`), sehingga posisi katak selalu tepat di atas daun teratai pada berbagai ukuran jendela dan monitor.

---

## 3. Gaya Visual Pixel Art (`PondFrogArtwork.swift`)

- **Palet Autentik Nagomi**:
  - Punggung hijau lumut cerah (`#4EA334`) dengan kontur hijau hutan gelap dan garis punggung hijau limau terang.
  - Perut dan tenggorokan berwarna krem pucat.
  - Balon suara transparan dengan titik pantulan cahaya putih saat berkuak.
  - Mata bulat menonjol dengan iris kuning emas, pupil celah horizontal hitam, dan bintik kilau putih.
- **Bayangan Jatuh (*Drop Shadow*)**:
  - Bayangan piksel lembut di atas daun teratai atau permukaan air yang mengecil dan memudar seiring naiknya ketinggian (*altitude*) saat melompat.
- **Rendering Terpadu**:
  - Dirender pada kisi piksel logis kolam yang sama (`PondRenderer.swift`), bebas dari alokasi bitmap per frame.

---

## 4. Hasil Verifikasi

- **`KoiWallpaperSimTest`**: 34 dari 34 pengujian lulus, termasuk Section 14 (T14.1–T14.6):
  - Penempatan daun teratai, mikro-animasi napas/kedip/kuak, lompatan parabolik, riak air, siklus kembali, pemicu klik, dan ketahanan pause.
- **`KoiWallpaperVerify`**: 53 dari 53 pengujian lulus tanpa regresi performa, kebocoran memori, atau pelanggaran frame-rate.
- **Preview Visual**:
  - `reports/screenshots/frog_perched_preview.png`: Katak hinggap dengan gelembung suara berkuak.
  - `reports/screenshots/frog_leaping_preview.png`: Katak melompat di udara dengan kaki terentang.
  - `reports/screenshots/frog_night_preview.png`: Katak di malam hari di bawah pencahayaan malam.
