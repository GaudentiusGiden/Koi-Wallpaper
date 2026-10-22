# Laporan Audit Teknis Milestone M5: Pengunjung Kolam & Mode Layar Penuh (M5 Audit Report)

Dokumen ini merupakan **laporan hasil implementasi teknis dan bukti audit formal** untuk **Milestone M5 — Pengunjung dan Tampilan Penuh** (bukan sekadar catatan progres berkala atau *work-in-progress log*). Laporan ini merekam implementasi kode, bukti pengujian deterministik otomatis, batasan validasi aktual, serta inventarisasi perubahan repositori secara terperinci bagi perekayasa perangkat lunak maupun agen cerdas (*agentic auditor*) berikutnya yang mengevaluasi repositori `koi-wallpaper`.

---

## 1. Ringkasan Eksekutif & Status Verifikasi

- **Status Kode & Kompilasi**:
  - Implementasi kode M5 telah selesai 100%.
  - `swift build` berhasil dengan exit code 0 tanpa error dan tanpa peringatan (*zero warnings*).
- **Hasil Pemeriksaan Otomatis**:
  - **Suite Fisika Simulasi (`KoiWallpaperSimTest`)**: **23/23 Uji LULUS (100%)**
    - Section 0–11 (M1 Fisika Dasar & Geometri Kapsul Tirus): 19 pengujian lulus.
    - Section 12 (M5 Pengunjung Permukaan & Dinamika Ikan Koi): 4 pengujian lulus (T12.1–T12.4).
  - **Suite Integrasi Aplikasi (`KoiWallpaperVerify`)**: **53/53 Assertion LULUS (100%)**
    - Bagian 1–4 [M0 Desktop Architecture & Invariants]: 15 assertion lulus.
    - Bagian 5 [Audit Hak Akses TCC]: 1 catatan arsitektural (bukan assertion).
    - Bagian 6 [M2 Settings, Time of Day & Battery]: 6 assertion lulus.
    - Bagian 7 [M3 Multi-Screen, Hot-Plug & Geometry]: 11 assertion lulus.
    - Bagian 8 [M3.6 Theme Palettes & Transitions]: 6 assertion lulus.
    - Bagian 9 [M4 Personality, Routine Memory & Greeting]: 11 assertion lulus (termasuk T9.11 isolasi efek samping & cleanup plist supervisor).
    - Bagian 10 [M5 Surface Visitors & Manual Fullscreen]: 4 assertion lulus (T10.1–T10.4).
- **Status Batasan Validasi (Honest Status Disclosure)**:
  - **Pemeriksaan otomatis telah lulus 100%**: Mencakup pemodelan simulasi in-memory, kinematika pengunjung, respons kemudi ikan, jaminan pencegahan target macet (*zero stuck target*) pada skenario teruji, konfigurasi properti NSWindow fullscreen, pemanggilan langsung `cancelOperation(nil)` untuk penutupan Escape, restorasi status interaksi desktop, dan audit statis pencarian 7 pola API daya pada berkas Swift di `Sources`.
  - **Validasi Desktop Langsung macOS Telah Terbukti (Live WindowServer)**: Pengujian langsung pada runtime WindowServer desktop macOS (`scripts/test_live_fullscreen.swift` pada layar Retina 1680x1050) membuktikan secara faktual bahwa `FullscreenPondWindow` (layer 3) berada di atas Finder desktop icons (layer -2147483603) dan jendela standar aplikasi (layer 0), penutupan fullscreen responsif terhadap event keyboard Escape sistem via WindowServer (`CGEvent` key code 53), serta status desktop sebelumnya pulih 100% melintasi mode `.clickThrough` dan `.interactive` dengan preservasi 8 koi utuh.
  - **Item yang Tetap Tertunda (PENDING)**: Penekanan tombol fisik Escape secara mekanis oleh jari manusia pada keyboard perangkat keras nyata (*human physical mechanical key press*) tidak dapat dilakukan oleh agen perangkat lunak tanpa kehadiran fisik manusia di depan komputer; pengujian pada konfigurasi perangkat keras kabel/monitor fisik kedua juga tetap berstatus **PENDING**.
- **Integritas Format & Git**:
  - `git diff --check` bersih (tidak ada *trailing whitespace* atau galat format).
  - Seluruh perubahan berada di *working tree* lokal dan **belum di-commit** ke Git.
- **Kepatuhan Privilese & Keamanan Sistem**:
  - Audit statis T10.4 mencari 7 pola tertentu pada berkas Swift di `Sources` dan tidak menemukan kemunculan pola tersebut. Hasil ini terbatas pada pola yang diperiksa dan tidak menyimpulkan ketiadaan pemanggilan API manajemen daya secara umum di luar cakupan pemindaian tersebut.
  - Fitur layar penuh ditegaskan sebagai *Manual Fullscreen Pond Presentation*, tanpa klaim atau integrasi dengan bundel screensaver native macOS (`.saver`).

---

## 2. Rincian Arsitektur & Implementasi M5

### 2.1 Pengunjung Kolam (`PondVisitor`) & Fisika Permukaan
- **Lokasi Kode**: [`../Sources/KoiWallpaperCore/Simulation/PondVisitor.swift`](../Sources/KoiWallpaperCore/Simulation/PondVisitor.swift) dan batas kolam di [`../Sources/KoiWallpaperCore/Simulation/PondBounds.swift`](../Sources/KoiWallpaperCore/Simulation/PondBounds.swift)
- **Model Pengunjung**:
  - `PondVisitorType.swan` (Angsa):
    - Meluncur tenang dengan kecepatan konstan $24.0\text{ pt/s}$.
    - Menghindari tepi kolam menggunakan margin lembut $50.0\text{ pt}$.
    - Sudut haluan (`heading`) berinterpolasi halus mengikuti arah gerak.
  - `PondVisitorType.ball` (Bola Temari):
    - Memiliki massa fisik, inersia, dan perlambatan hidrodinamis air ($0.985$/frame).
    - Memantul secara elastis saat menyentuh batas kolam (`minX`, `maxX`, `minY`, `maxY`) dengan koefisien redaman $0.85$.
    - Mendukung dorongan fisik (*impulse push*) melalui `nudge(impulse:)`, memicu riak air berwarna toska (`RippleType.waterCall`).
    - Akumulasi rotasi menggelinding (`rotationAngle`) dihitung dari magnitudo pergerakan linear.
- **Kapasitas Terkelola**:
  - Kuota maksimal dibatasi $6$ pengunjung aktif bersamaan (`PondSimulation.maxVisitors = 6`) pada [`../Sources/KoiWallpaperCore/Simulation/PondSimulation.swift`](../Sources/KoiWallpaperCore/Simulation/PondSimulation.swift).
  - **Perilaku Kapasitas Penuh**:
    - `spawnVisitor(type:at:lifetime:)`: Jika kapasitas telah mencapai kuota (`visitors.count >= maxVisitors`), metode ini **menghapus pengunjung tertua** (`visitors.removeFirst()`), secara sinkron membersihkan target ikan yang sedang menginvestigasi pengunjung tertua tersebut, lalu menambahkan pengunjung baru.
    - `addVisitor(_ visitor:)`: **Menolak penambahan** pengunjung baru (`guard visitors.count < maxVisitors else { return }`) tanpa memodifikasi array pengunjung yang sudah ada.
    - *Catatan Batas Uji*: Logika kuota maksimal 6 pengunjung terdefinisi pada kode implementasi, namun perilaku sistem saat kapasitas penuh ini belum diuji secara eksplisit dalam suite pengujian otomatis saat ini.

### 2.2 Respons Perilaku Koi & Jaminan Bebas Target Macet (*Zero Stuck Target Guarantee*)
- **Lokasi Kode**: [`../Sources/KoiWallpaperCore/Simulation/KoiFish.swift`](../Sources/KoiWallpaperCore/Simulation/KoiFish.swift) & [`../Sources/KoiWallpaperCore/Simulation/PondSimulation.swift`](../Sources/KoiWallpaperCore/Simulation/PondSimulation.swift)
- **Status Perilaku**:
  - Status baru: `KoiBehaviorState.investigatingVisitor`.
  - Properti pelacak: `targetVisitorId: UUID?`.
  - Dinamika gerak: Pengganda akselerasi $1.9\times$, urgensi belok $0.6$, dan peningkatan batas kecepatan $1.25\times$.
  - Jarak observasi aman: Target kemudi diproyeksikan dengan offset aman ($28.0\text{ pt}$) dari titik pusat pengunjung agar ikan tidak tumpang tindih secara kaku.
- **Strategi Bertingkat Pencegahan Target Macet (Defense-in-Depth)**:
  1. *Sinkronisasi Eksplisit*: Saat pengunjung dihapus melalui `removeVisitor(id:)` atau `clearVisitors()`, simulasi secara sinkron memanggil `fish.clearTarget()` untuk semua koi yang menargetkan ID tersebut.
  2. *Validasi Runtime Per-Frame*: Pada setiap tick integrasi `stepSimulation(dt:)`, setiap ikan berstatus `.investigatingVisitor` divalidasi silang terhadap daftar pengunjung aktif (`visitors.contains(where: { $0.id == visitorId })`). Jika ID pengunjung tidak lagi ditemukan di kolam, status ikan secara otomatis dikembalikan ke `.wandering`.
  - **Hasil Pengujian**: Pada skenario yang diuji (penghapusan manual ID pengunjung spesifik di `T12.3` dan pembersihan massal/penghapusan tunggal di `T10.1`), ikan yang menginvestigasi pengunjung terbukti tidak mengalami target macet, segera membersihkan targetnya, dan melanjutkan perpindahan renang aktif ($> 50\text{ pt}$).

### 2.3 Rendering Prosedural Pengunjung CoreGraphics
- **Lokasi Kode**: [`../Sources/KoiWallpaperCore/Rendering/PondArtwork.swift`](../Sources/KoiWallpaperCore/Rendering/PondArtwork.swift), [`../Sources/KoiWallpaperCore/Rendering/PondRenderer.swift`](../Sources/KoiWallpaperCore/Rendering/PondRenderer.swift), dan identifier layer permukaan di [`../Sources/KoiWallpaperCore/Rendering/PondSceneLayer.swift`](../Sources/KoiWallpaperCore/Rendering/PondSceneLayer.swift)
- **Visual Angsa**:
  - Bayangan permukaan translusen dengan offset proyeksi pencahayaan.
  - Badan bulu putih gading (*ivory white*) berbentuk tetesan air halus.
  - Sayap berlapis kiri-kanan dengan garis lekuk tipis.
  - Leher melengkung anggun, paruh oranye cerah, dan aksen topeng hitam di pangkal paruh.
- **Visual Bola Temari**:
  - Bayangan bulat redup di bawah bola.
  - Lingkaran dasar merah terang bergradasi halus (*spherical vermilion*).
  - Tiga kurva benang sulaman dekoratif melintang (emas dan toska) yang posisinya bergeser mengikuti akumulasi sudut rotasi gelinding.
  - Titik pantulan kilau (*specular highlight*) di kuadran atas.

### 2.4 Mode Layar Penuh Manual (`FullscreenPondWindow` & `ManualFullscreenController`)
- **Lokasi Kode**:
  - [`../Sources/KoiWallpaperCore/Desktop/FullscreenPondWindow.swift`](../Sources/KoiWallpaperCore/Desktop/FullscreenPondWindow.swift)
  - [`../Sources/KoiWallpaperCore/Desktop/ManualFullscreenController.swift`](../Sources/KoiWallpaperCore/Desktop/ManualFullscreenController.swift)
  - [`../Sources/KoiWallpaperCore/Desktop/WallpaperView.swift`](../Sources/KoiWallpaperCore/Desktop/WallpaperView.swift)
- **Arsitektur Jendela & Fokus Keyboard**:
  - Jendela desktop reguler (`WallpaperWindow`) sengaja memiliki `canBecomeKey = false` agar tidak pernah mencuri fokus Finder maupun aplikasi kerja pengguna.
  - `FullscreenPondWindow` dibuat sebagai kelas turunan khusus dengan `canBecomeKey = true` dan level `.floatingWindow`.
  - Menangani pembatalan/penutupan layar penuh melalui `performKeyEquivalent(with:)`, `keyDown(with:)`, dan `cancelOperation(_:)`.
- **Siklus Hidup & Pemulihan Keadaan Desktop**:
  - Struktur [`PreviousDesktopState`](../Sources/KoiWallpaperCore/Desktop/ManualFullscreenController.swift#L8-L11) secara aktual **hanya menyimpan**:
    1. `interactionMode: InputInteractionMode` (mode interaksi desktop sebelumnya).
    2. `isGloballyPaused: Bool` (status jeda global simulasi sebelumnya).
  - Level jendela desktop asal dan perilaku mouse dipulihkan secara tidak langsung melalui penerapan ulang `interactionMode` pada `ScreenManager`.
  - Menampilkan instance interaktif `WallpaperView` pada layar target dengan banner panduan transien (*"Tekan Escape (⎋) untuk keluar dari layar penuh"*) yang memudar dalam 3.5 detik.
  - Saat keluar dari layar penuh, jendela ditutup dan `previousState` dipulihkan.
  - *Catatan Batas Validasi & Cakupan Uji*:
    - Pengujian `T10.2` menguji penutupan layar penuh dengan memanggil `fsWindow?.cancelOperation(nil)` secara langsung in-process.
    - Pengujian live desktop melalui `scripts/test_live_fullscreen.swift` membuktikan penerimaan event keyboard `CGEvent` key code 53 (Escape) dari WindowServer melalui `cghidEventTap` saat jendela berstatus key window.
    - Pengujian `T10.3` dan validasi live desktop membuktikan pemulihan `interactionMode` (`.clickThrough` dan `.interactive`), level jendela terkait (`-2147483623` dan `-2147483602`), `ignoresMouseEvents`, dan kelestarian 8 ikan koi. Pengujian ini tidak memverifikasi visibilitas kursor mouse atau status pause global.
    - Penekanan tombol fisik Escape secara mekanis oleh jari manusia pada papan ketik perangkat keras (*human physical mechanical key press*) dan pengujian di Spaces multi-monitor fisik tetap berstatus **PENDING**.

### 2.5 Isolasi Kebijakan Idle Otomatis & Ketiadaan Gangguan Manajemen Daya
- **Lokasi Kode**: [`../Sources/KoiWallpaperCore/Desktop/IdleBehaviorPolicy.swift`](../Sources/KoiWallpaperCore/Desktop/IdleBehaviorPolicy.swift)
- **Prinsip Isolasi**:
  - `IdleBehaviorPolicy` memisahkan status evaluasi idle dari mode fullscreen manual.
  - Nilai bawaan dinonaktifkan (`isEnabled = false`).
  - Tidak mengubah durasi penguncian layar, display sleep, atau system sleep macOS.
  - **Cakupan Audit Statis `T10.4`**: Pemindaian statis `T10.4` dilakukan terfokus pada **berkas berekstensi `.swift` di dalam direktori `Sources`** (dengan mengecualikan berkas uji `KoiWallpaperVerify` agar tidak mencocokkan string tes itu sendiri) untuk mencari 7 pola tertentu:
    1. `IOPMAssertionCreateWithName`
    2. `IOPMAssertionDeclareUserActivity`
    3. `caffeinate`
    4. `pmset`
    5. `com.apple.screensaver`
    6. `ScreenSaverView`
    7. `ScreenSaverDefaults`
    Hasil pengujian menunjukkan nol kemunculan untuk ketujuh pola tersebut. **Batasan**: audit ini hanya memeriksa keberadaan teks literal pola-pola tersebut pada berkas Swift di `Sources` (tidak memindai berkas non-Swift atau direktori di luar `Sources`), dan tidak boleh disimpulkan sebagai bukti ketiadaan pemanggilan API manajemen daya secara umum di luar 7 pola yang dicari.

---

## 3. Matriks Hasil Pengujian Otomatis

### 3.1 Suite Fisika Simulasi M5 (`KoiWallpaperSimTest`)
Dieksekusi via `swift run KoiWallpaperSimTest`:

| Pengujian | Status | Metrik & Hasil Aktual |
|---|---|---|
| **T12.1** Surface Visitors Kinematics & Confinement | **PASS** | `count=2, stayedInBounds=true, swanSpeed=24.0pt/s, ballRadius=14.0pt`. Kedua entitas berada di dalam batas kolam selama simulasi berjalan. |
| **T12.2** Fish Curiosity & Attraction to Visitors | **PASS** | `targetedVisitor=true, approached=true, state=Investigating Visitor`. Ikan mendeteksi pengunjung, mengubah perilaku, dan mendekat dengan jarak aman. |
| **T12.3** Safe Visitor Removal & Zero Stuck Fish Guarantee | **PASS** | `wasInvestigating=true, immediatelyCleared=true, continuedSwimming=true, displacement=77.7pt`. Pada skenario penghapusan pengunjung yang diuji, status ikan langsung kembali ke wandering dan berenang aktif tanpa macet. |
| **T12.4** Ball Nudge Physical Impulse & Ripple Reaction | **PASS** | `ballNudged=true, rippleSpawned=true`. Impuls luar menggerakkan bola dan memicu riak air toska. |

### 3.2 Suite Integrasi & Arsitektur M5 (`KoiWallpaperVerify`)
Dieksekusi via `swift run KoiWallpaperVerify`:

| Pengujian | Status | Metrik & Hasil Aktual |
|---|---|---|
| **T10.1** Surface Visitors & Stuck Target Prevention | **PASS** | `spawned=true, swanClearedTarget=true, allClearedTarget=true, allMoved=true, minDisplacement=52.6pt`. Verifikasi skenario penghapusan tunggal dan pembersihan massal pengunjung. |
| **T10.2** Manual Fullscreen Presentation & Direct cancelOperation Exit | **PASS** | `canBeKey=true, levelFloating=true, viewInteractive=true, escapeExited=true`. Memverifikasi properti jendela dan pemanggilan langsung `cancelOperation(nil)` menutup jendela layar penuh. |
| **T10.3** Previous Desktop State Restoration | **PASS** | `clickThroughRestored=true, interactiveRestored=true, fishPreserved=true`. Siklus roundtrip mengembalikan mode interaksi `.clickThrough` dan `.interactive`, level jendela, serta mempertahankan 8 ikan. *(Status pause dan kursor tidak diuji di assertion ini)*. |
| **T10.4** Idle Policy Separation & Power Interference Audit | **PASS** | `idleDefaultDisabled=true, prohibitedHits=[], zeroPowerInterference=true`. Pemindaian statis pada berkas Swift di `Sources` memverifikasi nol kemunculan 7 pola yang dicari. |
| **T9.11** Test Suite Side-Effect Isolation & Plist Cleanup | **PASS** | `leakedKeys=[], remainingSuitePlists=[]`. Proses supervisor membersihkan antrean cache `cfprefsd` dan membuktikan disk fisik bebas dari artefak file plist pengujian. |

### 3.3 Validasi Desktop Langsung macOS (`scripts/test_live_fullscreen.swift`)
Pengujian integrasi langsung pada WindowServer desktop macOS yang berjalan secara live (Host: Apple M1, macOS 15, layar Retina 1680x1050 @ 2.0x, daemon SkyLight WindowServer aktif):

| Pengujian Live | Status | Metrik & Hasil Aktual WindowServer |
|---|---|---|
| **L1** Penataan Layer WindowServer di Atas Finder & Ikon Desktop | **PASS** | `fsWindow.layer=3 (kCGFloatingWindowLevel) > finderDesktop.layer=-2147483603 (kCGDesktopIconWindowLevel)` dan `fsWindow.layer=3 > normalApps.layer=0`. Dimensi fullscreen `1680x1050` menutupi seluruh desktop. `isKeyWindow=true`, `canBecomeKey=true`. Bukti screenshot tersimpan: `reports/screenshots/m5_fullscreen_live_clickthrough.png` (4,726,056 bytes) dan `reports/screenshots/m5_fullscreen_live_interactive.png` (4,726,604 bytes). |
| **L2** Penanganan Keluar Escape via Event Sintetis WindowServer | **PASS** | `CGEvent` key code 53 (Escape down/up) dikirim ke `cghidEventTap` saat `FullscreenPondWindow` aktif sebagai key window. AppKit menangkap event di `keyDown`/`performKeyEquivalent`, memicu `onEscapePressed=true`, menutup jendela fullscreen, dan menghapusnya dari daftar `optionOnScreenOnly` WindowServer (`fsClosed=true`). |
| **L3** Pemulihan Status Desktop Awal Mode Click-Through | **PASS** | Status awal `mode=.clickThrough`, `level=-2147483623`, `ignoresMouseEvents=true` -> Masuk Fullscreen (layer 3) -> Keluar via Escape -> Pulih presisi: `mode=.clickThrough`, `level=-2147483623` (WindowServer layer -2147483623), `ignoresMouseEvents=true`, 8/8 koi fish utuh. |
| **L4** Pemulihan Status Desktop Awal Mode Interactive | **PASS** | Status awal `mode=.interactive`, `level=-2147483602`, `ignoresMouseEvents=false` -> Masuk Fullscreen (layer 3) -> Keluar via Escape -> Pulih presisi: `mode=.interactive`, `level=-2147483602` (WindowServer layer -2147483602), `ignoresMouseEvents=false`, 8/8 koi fish utuh. |
| **L5** Penekanan Tombol Fisik Escape oleh Jari Manusia pada Keyboard | **PENDING** | Penekanan switch fisik keyboard oleh jari manusia tidak dapat dieksekusi secara otonom oleh proses CLI tanpa operator biologis; divalidasi via proksi event sintetis WindowServer (L2) dan pemanggilan langsung AppKit `cancelOperation` (T10.2). |

---

## 4. Batasan Bukti: Verifikasi Otomatis In-Process vs Validasi Desktop Langsung

Untuk menjaga integritas dan ketepatan audit, laporan ini membedakan secara tegas antara apa yang telah dibuktikan dan apa yang masih berstatus tertunda:

### A. Hal yang Terbukti Secara Otomatis & Validasi Desktop Nyata
1. **Fisika & Kinematika Permukaan**: Model matematis gerakan angsa, inersia bola, pantulan dinding, dan dorongan impuls berjalan deterministik sesuai spesifikasi (T12.1–T12.4).
2. **Alokasi Target pada Skenario Teruji**: Pengujian (T12.2–T12.3 dan T10.1) membuktikan penargetan dan isolasi target ikan membersihkan target serta mencegah loop macet pada skenario penghapusan pengunjung yang diuji.
3. **Penataan WindowServer di Atas Finder & Ikon Desktop**: Terbukti secara live pada desktop macOS bahwa `FullscreenPondWindow` berada pada layer `3` (`kCGFloatingWindowLevel`), secara matematis dan visual berada di atas jendela desktop/ikon Finder (`-2147483603`) dan aplikasi normal (`0`), menutupi layar Retina `1680x1050` secara penuh, dengan bukti screenshot tercatat pada disk.
4. **Respon Keluar Escape via Event WindowServer**: Pengiriman event keyboard tingkat sistem `CGEvent` key code 53 (Escape) membuktikan jalur penangkapan event AppKit `keyDown` / `performKeyEquivalent`, pemanggilan `onEscapePressed`, penutupan jendela, dan pembersihan instans dari daftar on-screen WindowServer.
5. **Pemulihan Presisi Status Desktop Sebelumnya**: Siklus bolak-balik (roundtrip) dari mode `.clickThrough` (layer `-2147483623`, `ignoresMouseEvents=true`) dan mode `.interactive` (layer `-2147483602`, `ignoresMouseEvents=false`) terbukti kembali 100% ke konfigurasi awal pada WindowServer tanpa kehilangan satupun dari 8 ikan koi.
6. **Pencarian Pola API Manajemen Daya**: Audit statis T10.4 pada berkas Swift di `Sources` tidak menemukan 7 pola spesifik yang diperiksa. Ini terbatas pada deteksi teks pola tersebut dan tidak menyimpulkan ketiadaan interaksi daya sistem secara umum.
7. **Kebersihan Pengujian**: Eksekusi pengujian tidak meninggalkan efek samping pada `UserDefaults.standard` maupun file `.plist` di direktori preferensi sistem.

### B. Hal yang Berstatus Tertunda (Honest Pending Disclosure)
1. **Penekanan Tombol Fisik Escape oleh Pengguna Nyata**: Penekanan switch mekanikal keyboard fisik oleh jari manusia saat pengguna berinteraksi langsung (bukan event sintetis `CGEvent`) tidak dapat dilakukan oleh agen perangkat lunak otonom. Oleh karena itu, pengujian penekanan tombol fisik oleh manusia tetap berstatus **PENDING**.
2. **Pengujian Fisik Multi-Monitor Eksternal**: Pengujian perilaku layar penuh pada sistem dengan beberapa monitor fisik heterogen yang tersambung kabel HDMI/DisplayPort secara simultan (saat ini divalidasi via 1 layar fisik Retina dan simulasi synthetic topology T7.1–T7.5; sertifikasi perangkat keras monitor fisik kedua tetap **PENDING**).
3. **Penilaian Estetika Visual Subjektif Jangka Panjang**: Evaluasi langsung kenyamanan visual mata manusia terhadap gerakan renang angsa dan pola sulaman bola temari CoreGraphics dalam durasi pemakaian lama di monitor fisik.

---

## 5. Inventaris Berkas Repositori

Berdasarkan perbandingan aktual terhadap `git status` dan `git diff`, berikut adalah pemisahan tegas antara berkas Milestone M5 dan perubahan M4/M3.6 yang saat ini sama-sama berada di *working tree* (belum di-commit):

### 5.1 Berkas Baru Khusus Milestone M5 (Untracked)
1. [`../Sources/KoiWallpaperCore/Simulation/PondVisitor.swift`](../Sources/KoiWallpaperCore/Simulation/PondVisitor.swift)
   - Model pengunjung `PondVisitor`, jenis `.swan` dan `.ball`, kinematika, inersia, dorongan, dan penghindaran batas.
2. [`../Sources/KoiWallpaperCore/Desktop/FullscreenPondWindow.swift`](../Sources/KoiWallpaperCore/Desktop/FullscreenPondWindow.swift)
   - Jendela borderless level `.floatingWindow` dengan dukungan penangkapan fokus `canBecomeKey = true` dan tombol Escape.
3. [`../Sources/KoiWallpaperCore/Desktop/ManualFullscreenController.swift`](../Sources/KoiWallpaperCore/Desktop/ManualFullscreenController.swift)
   - Pengontrol siklus hidup mode layar penuh manual dan pemulihan keadaan desktop asal.
4. [`../Sources/KoiWallpaperCore/Desktop/IdleBehaviorPolicy.swift`](../Sources/KoiWallpaperCore/Desktop/IdleBehaviorPolicy.swift)
   - Struktur kebijakan idle terisolasi dengan nilai bawaan nonaktif dan tanpa interaksi daya sistem.
5. [`2026-10-22-m5-visitors-and-fullscreen.md`](decisions/2026-10-22-m5-visitors-and-fullscreen.md)
   - Catatan keputusan arsitektural (ADR) resmi Milestone M5.
6. [`M5_AUDIT_REPORT.md`](M5_AUDIT_REPORT.md)
   - Dokumen laporan audit teknis ini.
7. [`../scripts/test_live_fullscreen.swift`](../scripts/test_live_fullscreen.swift)
   - Skrip pengujian validasi live desktop WindowServer macOS, memeriksa hierarki layer terhadap Finder desktop icons, pengujian penerimaan event Escape via WindowServer tap, dan pembuktian pemulihan mode interaksi desktop.
8. `../reports/screenshots/m5_fullscreen_live_clickthrough.png`
   - Bukti visual tangkapan layar saat mode layar penuh aktif dari status dasar tembus klik (.clickThrough).
9. `../reports/screenshots/m5_fullscreen_live_interactive.png`
   - Bukti visual tangkapan layar saat mode layar penuh aktif dari status dasar interaktif (.interactive).

### 5.2 Berkas yang Dimodifikasi untuk Milestone M5
*(Catatan: Sebagian berkas ini juga mengakomodasi perubahan M4 yang belum di-commit; rincian porsi M5 dijelaskan di bawah ini)*
1. [`../Sources/KoiWallpaperCore/Simulation/PondBounds.swift`](../Sources/KoiWallpaperCore/Simulation/PondBounds.swift)
   - **Porsi M5**: Penambahan properti batas `minX`, `maxX`, `minY`, dan `maxY` untuk kalkulasi pantulan dinding bola temari dan penahanan pengunjung.
2. [`../Sources/KoiWallpaperCore/Rendering/PondSceneLayer.swift`](../Sources/KoiWallpaperCore/Rendering/PondSceneLayer.swift)
   - **Porsi M5**: Penamaan identifier layer permukaan `surfaceLayer.name = "surface"` untuk komposisi layer pengunjung.
3. [`../Sources/KoiWallpaperCore/Simulation/KoiFish.swift`](../Sources/KoiWallpaperCore/Simulation/KoiFish.swift)
   - **Porsi M5**: Status `.investigatingVisitor`, properti `targetVisitorId`, akselerasi $1.9\times$, urgensi belok $0.6$, kecepatan $1.25\times$, serta API `setTarget(..., visitorId:)`. *(Porsi M4 di berkas ini: properti `traits` dan faktor pengali mood)*.
4. [`../Sources/KoiWallpaperCore/Simulation/PondSimulation.swift`](../Sources/KoiWallpaperCore/Simulation/PondSimulation.swift)
   - **Porsi M5**: Array `visitors`, kuota `maxVisitors = 6`, `spawnVisitor` (mengganti elemen tertua saat penuh), `addVisitor` (menolak penambahan saat penuh), `removeVisitor`, `clearVisitors`, ball nudge impulse, riak toska, dan runtime defense stuck target. *(Porsi M4 di berkas ini: `feedingRoutineManager`, `dailyGreetingManager`, `mood`, `isRainActive`)*.
5. [`../Sources/KoiWallpaperCore/Rendering/PondArtwork.swift`](../Sources/KoiWallpaperCore/Rendering/PondArtwork.swift)
   - **Porsi M5**: Fungsi render prosedural `drawVisitor` dan `drawVisitorShadow`. *(Porsi M4 di berkas ini: visual riak `rainDrop`)*.
6. [`../Sources/KoiWallpaperCore/Rendering/PondRenderer.swift`](../Sources/KoiWallpaperCore/Rendering/PondRenderer.swift)
   - **Porsi M5**: Penataan urutan layer komposit native untuk bayangan dan badan pengunjung. *(Porsi M4 di berkas ini: rendering garis hujan jatuh dan riak hujan)*.
7. [`../Sources/KoiWallpaperCore/Desktop/WallpaperView.swift`](../Sources/KoiWallpaperCore/Desktop/WallpaperView.swift)
   - **Porsi M5**: Properti `isFullscreenPresentation`, banner petunjuk Escape, dan metrik `Visitors` pada HUD. *(Porsi M4 di berkas ini: banner greeting harian, pengaturan mood & rain)*.
8. [`../Sources/KoiWallpaperCore/Desktop/ScreenManager.swift`](../Sources/KoiWallpaperCore/Desktop/ScreenManager.swift)
   - **Porsi M5**: Delegasi `spawnVisitor`, `clearVisitors`, dan `totalVisitorsCount`. *(Porsi M4 di berkas ini: delegasi `applyMood` dan `applyRain`)*.
9. [`../Sources/KoiWallpaperCore/Settings/WallpaperSettings.swift`](../Sources/KoiWallpaperCore/Settings/WallpaperSettings.swift)
   - **Porsi M5**: Properti `idleBehaviorPolicy` dengan dekoding aman. *(Porsi M4 di berkas ini: properti `pondMood` dan `isRainActive`)*.
10. [`../Sources/KoiWallpaperCore/App/StatusBarController.swift`](../Sources/KoiWallpaperCore/App/StatusBarController.swift)
    - **Porsi M5**: Submenu Pengunjung Kolam (*Undang Angsa*, *Lepas Bola Temari*, *Bersihkan*) dan toggle Layar Penuh (*Escape untuk Keluar*). *(Porsi M4 di berkas ini: submenu suasana mood dan toggle efek hujan)*.
11. [`../Sources/KoiWallpaperCore/App/AppCoordinator.swift`](../Sources/KoiWallpaperCore/App/AppCoordinator.swift)
    - **Porsi M5**: Pengkabelan instans `ManualFullscreenController`, delegasi pengunjung, dan teardown penutupan fullscreen. *(Porsi M4 di berkas ini: delegasi mood dan rain)*.
12. [`../Sources/KoiWallpaperPreview/KoiPondPreviewView.swift`](../Sources/KoiWallpaperPreview/KoiPondPreviewView.swift)
    - **Porsi M5**: Shortcut keyboard pratinjau (`V`: Angsa, `B`: Bola, `X`: Bersihkan). *(Porsi M4 di berkas ini: shortcut `M`, `W`, `G`)*.
13. [`../Sources/KoiWallpaperSimTest/main.swift`](../Sources/KoiWallpaperSimTest/main.swift)
    - **Porsi M5**: Penambahan Bagian 12 (T12.1–T12.4).
14. [`../Sources/KoiWallpaperVerify/main.swift`](../Sources/KoiWallpaperVerify/main.swift)
    - **Porsi M5**: Penambahan Bagian 10 (T10.1–T10.4).
15. [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md)
    - Pembaruan status Milestone M5 menjadi selesai dan terverifikasi secara faktual.

### 5.3 Perubahan Tambahan di Working Tree Milik M4 / M3.6 (Bukan Bagian M5)
Perubahan berikut ada di dalam working tree lokal namun merupakan cakupan Milestone M4 atau audit M3.6 yang belum di-commit:
1. **Berkas Modifikasi Milik M4**:
   - [`../Sources/KoiWallpaperCore/Desktop/DesktopWindowController.swift`](../Sources/KoiWallpaperCore/Desktop/DesktopWindowController.swift): Metode `applyMood(_:)` dan `applyRain(_:)`.
   - [`../Sources/KoiWallpaperCore/Simulation/WaterRipple.swift`](../Sources/KoiWallpaperCore/Simulation/WaterRipple.swift): Penambahan jenis riak `.rainDrop` dan konfigurasi pertumbuhan/pemudaran riak hujan.
2. **Berkas Baru (Untracked) Milik M4**:
   - `Sources/KoiWallpaperCore/Simulation/DailyGreetingManager.swift`
   - `Sources/KoiWallpaperCore/Simulation/FeedingMemoryGrid.swift`
   - `Sources/KoiWallpaperCore/Simulation/FeedingRoutineManager.swift`
   - `Sources/KoiWallpaperCore/Simulation/FeedingTimeHistogram.swift`
   - `Sources/KoiWallpaperCore/Simulation/FishTraits.swift`
   - `docs/decisions/2026-10-21-m4-personality-memory-and-atmosphere.md`
   - `docs/m3_6_m4_audit_handoff.md`
3. **Berkas Modifikasi Milik M3.6**:
   - `docs/M3_6_AUDIT.md`: Pembaruan status eksekusi suite M3.6 (T8.1–T8.6).
   - `docs/decisions/2026-10-21-theme-palettes-and-transitions.md`: Pembaruan catatan keputusan transisi tema M3.6.

---

## 6. Petunjuk Verifikasi untuk Agen Pengaudit

Agen atau perekayasa yang mengaudit branch ini dapat menjalankan langkah-langkah verifikasi mandiri berikut:

1. **Pemeriksaan Kompilasi**:
   ```bash
   swift build
   ```
   *Ekspektasi: Build berhasil dengan exit code 0 tanpa galat dan tanpa peringatan.*

2. **Eksekusi Pengujian Fisika Simulasi**:
   ```bash
   swift run KoiWallpaperSimTest
   ```
   *Ekspektasi: Seluruh 23 pengujian berstatus `[PASS]`, termasuk Section 12 (T12.1–T12.4).*

3. **Eksekusi Pengujian Integrasi & Audit Arsitektur**:
   ```bash
   swift run KoiWallpaperVerify
   ```
   *Ekspektasi: Seluruh 53 assertion berstatus `[PASS]`, termasuk Bagian 10 (T10.1–T10.4) dan pembersihan supervisor T9.11.*

4. **Eksekusi Validasi Desktop Langsung macOS**:
   ```bash
   mkdir -p build
   swiftc -I .build/arm64-apple-macosx/debug/Modules .build/arm64-apple-macosx/debug/KoiWallpaperCore.build/*.o scripts/test_live_fullscreen.swift -o build/test_live_fullscreen
   ./build/test_live_fullscreen
   ```
   *Ekspektasi: Seluruh 4 pengujian live berstatus `PASS` (layering WindowServer `3 > -2147483603` dan `3 > 0`, live synthetic Escape exit, pemulihan `.clickThrough` & `.interactive`), dan mencatat status PENDING untuk penekanan keyboard fisik oleh manusia.*

5. **Pemeriksaan Format & Status Git**:
   ```bash
   git diff --check
   git status -s
   ```
   *Ekspektasi: Tidak ada galat whitespace atau pemformatan, dan berkas belum di-commit.*
