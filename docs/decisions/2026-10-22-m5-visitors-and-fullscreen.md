# Keputusan Arsitektur: M5 — Pengunjung dan Tampilan Penuh

Tanggal: 22 Oktober 2026 (Asia/Jakarta).  
Status baseline M5: Diterima & Terverifikasi melalui Suite `KoiWallpaperVerify` (T10.1–T10.4, total 53 assertion) dan `KoiWallpaperSimTest` (T12.1–T12.4, total 23 pengujian).

## Pembaruan pasca-M5 — siklus hidup angsa otomatis (24 Oktober 2026)

Perilaku angsa pada wallpaper diperbarui setelah M5. Saat setiap wallpaper
dibuat, satu angsa langsung muncul di titik acak di dalam kolam; pengguna tidak
perlu memanggil aksi spawn. Angsa berkelok dengan perubahan haluan yang
diperhalus dan variasi kecepatan kecil selama 18–30 detik, lalu mengarahkan diri
ke tepi terdekat. Simulasi menghapusnya setelah seluruh siluet keluar dari
batas kolam. Angsa berikutnya muncul setelah jeda acak 5–9 detik.

Skala artwork berubah dari `1.4` menjadi `1.512`, yaitu kenaikan 8%. Aksi menu
“Undang Angsa” diganti informasi “Angsa melintas otomatis”; hitungan pengunjung
manual tidak memasukkan angsa otomatis. Preview interaktif yang menampilkan
perilaku ini dijalankan dengan `swift run KoiWallpaperPreview --preview-swan`.
Implementasi utamanya ada di [`PondSimulation`](../../Sources/KoiWallpaperCore/Simulation/PondSimulation.swift), [`PondVisitor`](../../Sources/KoiWallpaperCore/Simulation/PondVisitor.swift), [`PondArtwork`](../../Sources/KoiWallpaperCore/Rendering/PondArtwork.swift), [`ScreenManager`](../../Sources/KoiWallpaperCore/Desktop/ScreenManager.swift), dan [`KoiWallpaperPreview`](../../Sources/KoiWallpaperPreview/main.swift).

> Catatan validasi: `swift build` dan `git diff --check` lulus untuk follow-up
> ini. Suite 23/23 dan 53/53 pada status di atas adalah hasil verifikasi M5
> sebelumnya; suite tersebut belum dijalankan ulang untuk siklus hidup angsa
> otomatis.

---

## 1. Konteks & Tujuan

Milestone M5 bertujuan menghadirkan interaksi dinamis tingkat lanjut pada ekosistem kolam melalui:
1. Pengunjung permukaan sederhana (*surface visitors*), seperti angsa (*swan*) dan bola tradisional Jepang (*temari ball*), yang memengaruhi target gerak dan rasa ingin tahu ikan koi secara organik.
2. Mode kolam tampilan penuh manual (*manual fullscreen pond mode*) yang menyajikan kolam secara imersif melintasi layar dengan jalur keluar yang intuitif, termasuk penekanan tombol **Escape (⎋)**, serta pemulihan keadaan desktop sebelumnya secara utuh.
3. Pemisahan tegas antara keputusan *idle* otomatis dari aktivasi *fullscreen* manual.
4. Perlindungan ketat integritas sistem: tidak ada perubahan pada setelan sleep, lock, atau daya macOS, serta tidak menyamakan fullscreen aplikasi dengan integrasi bundle screen saver macOS (`.saver`).

---

## 2. Pengunjung Permukaan Kolam (*Surface Visitors*)

### 2.1 Model Data `PondVisitor` & Tipe Pengunjung
Pengunjung dimodelkan melalui struktur `PondVisitor` dalam lapisan simulasi murni (`Simulation/PondVisitor.swift`):
- **Angsa (Swan)** (`.swan`):
  - Visitor biasa menggunakan kecepatan awal $24.0$ pt/s dan medan vektor penghindaran batas kolam; mode ini tetap tersedia untuk pemanggilan visitor manual.
  - Mode otomatis wallpaper muncul di dalam kolam dengan kecepatan dasar acak $34$–$44$ pt/s dan variasi kecil. Haluan mengubah arah perlahan; angsa menjelajah selama 18–30 detik, lalu berbelok menuju tepi terdekat dan keluar layar.
  - Setelah siluet sepenuhnya melewati batas kolam, visitor dihapus dan timer menjadwalkan kemunculan berikutnya setelah jeda 5–9 detik.
  - Menghasilkan fase anggukan/ombak lembut (*bobbing phase*) pada frekuensi $2.2$ rad/s.
- **Bola Temari (Ball)** (`.ball`):
  - Mengapung dan hanyut di permukaan air dengan redaman hidrodinamik lembut ($0.08 \times \Delta t$).
  - Memantul secara elastis saat menyentuh batas tepi kolam.
  - Menghasilkan fase anggukan air dengan frekuensi $3.4$ rad/s.
- **Batas Kapasitas**: Dibatasi maksimal $6$ pengunjung aktif (`maxVisitors = 6`) untuk mencegah pertumbuhan memori atau komputasi tak terbatas.

### 2.2 Dinamika Pengaruh terhadap Gerak Ikan Koi
Ikan koi berinteraksi secara organik dengan pengunjung berdasarkan sifat kepribadian (`FishTraits`) dan suasana kolam (`PondMood`):
- **Ketertarikan Ikan (Attraction & Escorting)**:
  - Ikan dalam keadaan mengembara (*wandering*) yang berada dalam radius interaksi pengunjung ($160.0$ pt untuk angsa, $120.0$ pt untuk bola) dapat tertarik untuk menyelidiki.
  - Ambang rasa ingin tahu (`traits.curiosity`) disesuaikan dengan mood kolam: $\ge 0.35$ pada mood *Playful*, atau $\ge 0.55$ pada mood *Calm*.
  - Ikan mengadopsi status perilaku baru `KoiBehaviorState.investigatingVisitor` dengan durasi $5.5$ detik.
  - Untuk angsa, ikan berenang mengawal di sisi samping/belakang ($+0.75\pi$ dari heading angsa) dengan jarak aman agar tidak tumpang tindih secara fisik.
- **Dorongan Fisik Bola (*Ball Nudge Impulse*)**:
  - Saat moncong ikan koi mendekati bola ($d < \text{mouthRadius} + \text{ballRadius} + 4.0$ pt), ikan memberikan dorongan impuls fisik ($28.0$ pt) searah arah renang ikan.
  - Tumbukan memicu riak air cyan lembut (`WaterRippleType.waterCall`), dan ikan kembali melanjutkan pengembaraan normal.

### 2.3 Jaminan Ketiadaan Target Macet (*Zero Stuck Fish Guarantee*)
Pemberian target sementara kepada ikan memiliki risiko fatal: jika pengunjung dihapus atau kedaluwarsa, ikan dapat berenang menuju koordinat hantu atau terhenti selamanya (*stuck target*).

M5 menjamin pencegahan target macet melalui mekanisme pertahanan ganda:
1. **Pembersihan Langsung pada Mutasi Manager**: Pemanggilan `removeVisitor(id:)` atau `clearVisitors()` seketika memeriksa seluruh populasi ikan; setiap ikan yang memiliki `targetVisitorId == id` atau berstatus `.investigatingVisitor` langsung memanggil `clearTarget()`, mengembalikan status ke `.wandering`.
2. **Validasi Eksistensi Kontinu Setiap Frame Fisika**: Di dalam `stepSimulation(dt:)`, setiap ikan berstatus `.investigatingVisitor` memvalidasi ID pengunjung target terhadap daftar pengunjung aktif (`activeVisitorIds`). Jika ID tidak ditemukan, `clearTarget()` langsung dipanggil secara otomatis.
3. **Penyelidikan Mandiri Melanjutkan Renang**: Uji simulasi membuktikan bahwa setelah pengunjung dihapus, ikan koi langsung bergerak aktif menjelajah kolam tanpa penurunan kecepatan atau macet (perpindahan terverifikasi $> 50.0$ pt pasca-penghapusan).

---

## 3. Mode Tampilan Penuh Manual (*Manual Fullscreen Mode*)

### 3.1 Arsitektur Jendela `FullscreenPondWindow`
Berbeda secara mendasar dengan jendela desktop `WallpaperWindow` (yang menolak status key window `canBecomeKey = false` untuk menjaga prinsip desktop non-stealing):
- `FullscreenPondWindow` adalah turunan `NSWindow` borderless dengan:
  - `canBecomeKey = true` dan `canBecomeMain = true` agar dapat menerima interaksi papan ketik pengguna.
  - Tingkat jendela: `NSWindow.Level.floating` (di atas jendela aplikasi biasa dan ikon Finder).
  - `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`.
  - Mengabaikan bayangan dan animasi pembukaan OS untuk transisi instan bebas flicker.

### 3.2 Penanganan Tombol Escape (⎋) & Keluar yang Jelas
Keluar dari tampilan penuh dapat dilakukan melalui:
1. Menekan tombol **Escape** pada keyboard.
2. Memilih menu bar status item: *Keluar dari Layar Penuh (Escape)*.
3. Pemanggilan programatik `exitFullscreen()`.

Penerimaan tombol Escape diimplementasikan melalui redundansi AppKit yang kokoh:
- `performKeyEquivalent(with:)` mendeteksi virtual key code 53 (Escape).
- `keyDown(with:)` menangkap event karakter `\u{1b}` atau keycode 53.
- `cancelOperation(_:)` menangkap tindakan pembatalan bawaan AppKit.

### 3.3 Pemulihan Keadaan Desktop Sebelumnya (*Previous Desktop State Restoration*)
Saat memasuki fullscreen, `ManualFullscreenController` mencatat snapshot keadaan desktop (`PreviousDesktopState`):
- `interactionMode`: mode tembus klik Finder (`.clickThrough`) atau mode tangkap klik (`.interactive`).
- `isGloballyPaused`: status pause global kolam.
- Konfigurasi tingkat jendela desktop (`-2147483623` untuk click-through, `-2147483602` untuk interactive).

Saat fullscreen ditutup:
- Jendela fullscreen ditutup, timer animasi view fullscreen dihentikan, dan view dilepas untuk mencegah retain cycle.
- Seluruh host desktop dikembalikan ke tingkat layer aslinya.
- Pengaturan tembus klik atau tangkap klik dipulihkan secara presisi sesuai keadaan sebelum fullscreen.
- Seluruh populasi ikan koi (8 ekor), pelet makanan, dan pengunjung tetap utuh tanpa reset atau kehilangan status.

---

## 4. Pemisahan Kebijakan Idle Otomatis & Netralitas Sistem

### 4.1 Pemisahan Tegas dari Fullscreen Manual
- `IdleBehaviorPolicy` memodelkan konfigurasi *idle* secara mandiri (`isEnabled: Bool`, `idleTimeoutSeconds: TimeInterval`, `action: IdleAction`).
- Secara bawaan, kebijakan idle dinonaktifkan (`isEnabled = false`, `action = .none`).
- Mode fullscreen manual adalah tindakan eksplisit pengguna dan **tidak bergantung** pada deteksi ketidakaktifan pengguna atau timer idle.

### 4.2 Ketiadaan Gangguan terhadap Pengaturan Daya / Tidur macOS
- Koi Wallpaper **tidak memodifikasi** konfigurasi penguncian layar atau waktu tidur sistem macOS.
- Pemindaian leksikal statis membuktikan ketiadaan pemanggilan API manipulasi daya sistem:
  - Bebas dari pemanggilan `IOPMAssertionCreateWithName` atau `IOPMAssertionDeclareUserActivity`.
  - Bebas dari eksekusi perintah terminal `caffeinate` atau `pmset`.
  - Bebas dari deklarasi bundle `ScreenSaverView`, `ScreenSaverDefaults`, atau identifier `com.apple.screensaver`.
- Aplikasi secara jujur menyajikan fullscreen sebagai mode tampilan aplikasi internal, bukan sebagai integrasi screen saver sistem macOS (`.saver`).

---

## 5. Matriks Hasil Verifikasi Runtime

### 5.1 Suite Simulasi Murni (`KoiWallpaperSimTest`)
| ID Pengujian | Cakupan | Status | Metrik Aktual |
|---|---|---|---|
| **T12.1** | Kinematika & Confinement Pengunjung (Angsa & Bola) | PASS | 2 pengunjung aktif, 300 frame terkungkung dalam batas kolam, kecepatan angsa $24.0$ pt/s, radius bola $14.0$ pt. |
| **T12.2** | Ketertarikan & Pengawalan Ikan terhadap Pengunjung | PASS | Ikan penasaran mengadopsi status `.investigatingVisitor`, mendekati angsa ($d < 80.0$ pt). |
| **T12.3** | Pembersihan Pengunjung & Jaminan Bebas Macet | PASS | Target ikan langsung bersih seketika (`currentTarget == nil`, status kembali `.wandering`), ikan melanjutkan renang aktif (perpindahan $77.7$ pt dalam 120 frame). |
| **T12.4** | Tumbukan Fisik Moncong Ikan ke Bola & Riak | PASS | Moncong koi menyentuh bola, kecepatan bola berubah terdorong impuls, memicu riak air cyan `RippleType.waterCall`. |
| **Total SimTest** | **Bagian 0–11 (M1) + Bagian 12 (M5)** | **23/23 LULUS (100%)** | |

### 5.2 Suite Integrasi Aplikasi (`KoiWallpaperVerify`)
| ID Assertion | Cakupan | Status | Metrik Aktual |
|---|---|---|---|
| **T10.1** | Dinamika Pengunjung & Pencegahan Target Macet | PASS | 2 pengunjung dibuat, target angsa dibersihkan instan, target bola dibersihkan instan pada `clearVisitors()`, seluruh 8 koi aktif mengembara (min displacement $52.6$ pt). |
| **T10.2** | Presentasi Fullscreen, Key Capability & Escape Exit | PASS | `canBecomeKey = true`, level `floatingWindow`, view interaktif & fullscreen banner aktif, Escape key keluar bersih, jendela fullscreen terlepas tuntas. |
| **T10.3** | Pemulihan Keadaan Desktop Melintasi Roundtrip Fullscreen | PASS | Layer click-through (`-2147483623`) pulih presisi, layer interactive (`-2147483602`) pulih presisi, populasi 8 koi utuh tanpa kebocoran memori. |
| **T10.4** | Pemisahan Kebijakan Idle & Audit Ketiadaan Modifikasi Daya | PASS | `idleDefaultDisabled = true`, pemindaian statis menemukan 0 hit API daya terlarang (`zeroPowerInterference = true`). |
| **T9.11** | Isolasi Efek Samping Suite & Pembersihan Disk Plist | PASS | Dijalankan oleh supervisor pasca-terminasi worker: `leakedKeys = []`, `remainingSuitePlists = []`. |
| **Total Assertion Verify** | **Bagian 1–9 (M0–M4: 49) + Bagian 10 (M5: 4)** | **53/53 LULUS (100%)** | |
