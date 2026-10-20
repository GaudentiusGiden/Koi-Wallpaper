# Audit M0 — Koi Wallpaper

Tanggal audit: 19 Oktober 2026 (Diperbarui 20 Oktober 2026)
Status milestone: **M0 Diterima dengan Batasan Platform (20 Oktober 2026, Asia/Jakarta) — Milestone Berikutnya: M1 (Simulasi Kolam Mandiri)**. (Seluruh validasi desktop riil telah diuji oleh pengguna; batasan platform macOS diterima bahwa klik area kolam dapat mengaktifkan Finder dan mendefokuskan aplikasi aktif; Koi Wallpaper terbukti non-stealing; verifikasi signature strict dipisahkan dari metadata bundle; rujukan T1.1/T1.3 dipisahkan; klaim T4.6 diselaraskan dengan assertion verifier; kontradiksi pesan TCC dihapus).

---

## 1. Kesimpulan Audit

Milestone M0 telah menjalani seluruh rangkaian validasi fisik dan observasi desktop macOS riil yang dipandu bersama pengguna. Pengujian interaksi desktop yang memerlukan observasi visual dan fisik pengguna dipetakan ke dalam 6 kelompok pengujian (mencakup 8 item checklist: klik ikon Finder, drag file, seleksi marquee, retensi fokus saat klik kolam, visual riak air & pelet di Mode Interaksi, Show Desktop & Mission Control, live desktop occlusion `.covered`, serta hardware sleep/wake fisik).

Dari hasil pengamatan yang dilaporkan langsung oleh pengguna:
- **Lulus Observasi Fisik**: Interaksi fisik Finder (klik, drag, marquee), visual riak air cyan & Option+klik makanan oranye di Mode Interaksi, stabilitas jendela pada Show Desktop & Mission Control, deteksi live occlusion (`Paused (covered)` saat desktop tertutup 100% dan kembali `Aktif` saat dibuka), serta kestabilan pasca-hardware sleep/wake (aplikasi stabil, status kembali `Aktif`, dan riak interaksi tetap responsif).
- **Pembedaan Fokus & Keterbatasan Platform Tercatat**:
  1. *Koi Wallpaper tidak mengambil fokus*: Terkonfirmasi penuh. `Koi Wallpaper` terbukti *non-stealing* (`canBecomeKey = false`, `canBecomeMain = false`, activation policy `.accessory`), menolak aktivasi programatik saat aplikasi lain aktif, dan tidak pernah merebut menu bar sistem saat kolam diklik.
  2. *Aplikasi yang sebelumnya aktif tetap fokus*: **Tidak terpenuhi karena perilaku macOS**. Saat pengguna mengklik fisik area kolam desktop ketika aplikasi lain (seperti TextEdit, Notes, atau Terminal) sedang aktif, WindowServer macOS secara alami mendefokuskan jendela aplikasi aktif tersebut dan mengalihkan fokus menu bar ke `Finder`. Hasil observasi faktual ini tetap dipertahankan dan tidak diklaim lulus.
  3. *Keputusan Penerimaan Fokus*: Pada 20 Oktober 2026 (Asia/Jakarta), pengguna secara formal memutuskan menerima perilaku WindowServer macOS ini sebagai batasan platform M0 (klik desktop dapat mengaktifkan Finder dan mendefokuskan aplikasi sebelumnya, sedangkan Koi Wallpaper sendiri terbukti tidak mengambil fokus). Dengan keputusan ini, kriteria penerimaan fokus diselesaikan dengan penerimaan batasan platform, dan proyek melangkah ke M1.

Kendala implementasi, ketidakjujuran verifier, dan sinkronisasi lifecycle yang ditemukan pada audit awal telah **diperbaiki pada kode sumber dan diverifikasi sesuai cakupan bukti yang benar-benar tercatat**:
1. **Perbaikan Sinkronisasi View & Lifecycle**: `WallpaperView` menyinkronkan status pause dengan timer animasi. Timer animasi riak berhenti seketika saat jeda (radius riak membeku pada nilai terakhir) dan berlanjut saat resume. Sesuai pengujian unit in-process T4.6, verifier menguji bahwa radius tidak berubah selama jeda (`radiusDuringPause == initialRadius`) dan bertambah setelah resume (`radiusAfterResume > radiusDuringPause`). Verifier tidak menguji perubahan alpha atau membatasi batas atas pertambahan radius setelah resume. Alasan pause disimpan dalam `Set<PauseReason>` independen; jeda manual (`.manual`) terbukti tetap bertahan dan tidak terhapus ketika notifikasi sleep/wake sistem masuk dan selesai.
2. **Kejujuran Suite Verifikasi (`KoiWallpaperVerify`)**:
   - Pemeriksaan diklasifikasikan secara transparan menjadi `[CONFIG]`, `[MODEL/SYNC]`, `[SYNTHETIC EVENT]`, `[SYNTHETIC NOTIF]`, `[VIEW/ANIM]`, dan `[ARCH AUDIT]`.
   - Notifikasi `NSWorkspace` sleep/wake ditandai secara eksplisit sebagai sintetis in-process.
   - Pesan audit TCC telah diperbaiki untuk menghapus kontradiksi: hasil `AXIsProcessTrusted` dilaporkan apa adanya tanpa klaim kontradiktif *untrusted*. Dicatat secara eksplisit bahwa pemeriksaan ini hanya membaca status proses penguji (`KoiWallpaperVerify`), bukan izin runtime aplikasi wallpaper (`KoiWallpaper.app`), dan tidak membuktikan "zero TCC privileges".
   - Semua status `PASS` memiliki assertion nilai riil (bukan tautologi), mencakup konfigurasi window style (T1.1), collection behavior (T1.2), level jendela awal & passthrough (T1.3), konstanta layer (T1.4), penanganan `NSEvent` pada `WallpaperView.mouseDown` (T3.1, T3.2), supresi klik (T3.3), dan kelanjutan radius riak (T4.6).
3. **Penyempurnaan Skrip Integrasi Live (`scripts/test_live_app.swift`)**:
   - **Aman secara default (Safe Mode)**: memeriksa Window Server nyata secara non-destruktif untuk memverifikasi level jendela wallpaper (-2147483623) dan hierarki di bawah jendela Finder (-2147483603), serta memeriksa ikon desktop secara baca-saja tanpa mengaktifkan Finder, tanpa menghapus seleksi pengguna, dan tanpa mengirim event mouse sintetis.
   - **Mode interaktif (`--interactive-click-test`)**: hanya berjalan jika dipanggil dengan opsi eksplisit pengguna, menampilkan peringatan efek samping, mencocokkan nama ikon yang diklik secara presisi terhadap hasil seleksi, dan gagal jika prasyarat ikon desktop tidak terpenuhi.
4. **Kesiapan Toolchain & Bukti Bundle**: Lingkungan saat ini menyediakan Swift 6.2.4 arm64 dengan macOS 15 SDK / CommandLineTools yang berfungsi penuh. Metadata bundle `build/KoiWallpaper.app` telah diperiksa secara baca-saja langsung dari artefak biner (`file`), plist (`plutil -p`), dan metadata signature (`codesign -dvvv`). Keabsahan integritas signature diverifikasi secara terpisah menggunakan pemeriksaan ketat baca-saja `codesign --verify --deep --strict --verbose=2` (lulus: valid on disk dan memenuhi designated requirement).

---

## 2. Kriteria Penerimaan M0 dan Status Bukti

| Kriteria M0 | Yang Ada di Kode / Implementasi | Metode & Status Bukti |
| --- | --- | --- |
| **Bundle macOS 14+ & Apple Silicon** | `build/KoiWallpaper.app` berisi biner arm64, `LSMinimumSystemVersion=14.0`, `LSUIElement=true`, dan ad-hoc codesign | **LULUS (Terbukti metadata & verifikasi signature bundle)**: Diverifikasi langsung dari artefak: `file` memastikan arm64 thin binary, `plutil -p` memastikan `LSMinimumSystemVersion=14.0` dan `LSUIElement=1`, `codesign -dvvv` menampilkan rincian metadata signature ad-hoc, serta pemeriksaan baca-saja `codesign --verify --deep --strict --verbose=2` memverifikasi bundle valid pada disk dan memenuhi designated requirement. *(Terpisah dari inspeksi Window Server)* |
| **Konfigurasi Window Host** | Window borderless, `canBecomeKey = false`, `canBecomeMain = false` | **LULUS (Terbukti in-process)**: Diverifikasi oleh `KoiWallpaperVerify` (T1.1) |
| **CollectionBehavior (Spaces, Expose, Fullscreen)** | Window mengatur `.stationary`, `.canJoinAllSpaces`, `.ignoresCycle`, `.fullScreenNone`, dan `animationBehavior = .none` (diperbarui pada commit `81d1fbe` menggantikan `.fullScreenAuxiliary`) | **LULUS (Terbukti konfigurasi & observasi pengguna)**: Konfigurasi flag terverifikasi pada kode sumber dan suite verifikasi T1.2; navigasi Spaces dan transisi fullscreen terkonfirmasi aman berdasarkan observasi pengguna |
| **Hierarki Layer Window Server** | Window berada pada level `kCGDesktopWindowLevel` (-2147483623), di bawah level Finder Desktop Icon (-2147483603) | **LULUS (Terbukti in-process & live safe mode)**: Nilai awal dan passthrough terverifikasi in-process (T1.3); layer live (-2147483623 < -2147483603) terbukti via inspeksi Window Server aktual oleh `scripts/test_live_app.swift` |
| **Mode Interaksi & Sinkronisasi** | Menu bar dan coordinator mengaktifkan mode interaktif (+1 di atas ikon desktop, `ignoresMouseEvents = false`) dan kembali ke tembus klik | **LULUS (Terbukti in-process & observasi live)**: State coordinator, window level, mouse filtering, dan flag view tersinkronisasi (T2.1, T2.2); transisi menu `🐟` <-> `🐟⚡` teramati live |
| **Penanganan Klik & Option+Klik** | `WallpaperView.mouseDown` menerima klik air biasa dan Option+klik makanan, meneruskan ke coordinator | **LULUS (Terbukti in-process & observasi fisik pengguna)**: Event `NSEvent` in-memory terverifikasi (T3.1, T3.2); riak cyan (klik) dan riak oranye (Option+klik) terkonfirmasi kasat mata pada layar oleh pengguna |
| **Supresi Input Non-Interaktif** | Saat mode `clickThrough` atau saat `isPaused`, event mouse pada view diabaikan dan tidak membuat riak | **LULUS (Terbukti in-process)**: Terverifikasi oleh `KoiWallpaperVerify` (T3.3) |
| **Sinkronisasi Pause & Pertambahan Radius View** | `LifecyclePolicy` meneruskan status pause ke view; timer animasi berhenti dan bertambah setelah resume | **LULUS (Terbukti in-process & observasi live)**: Timer berhenti saat jeda (radius preserved), dan radius bertambah setelah resume (T4.2, T4.6; observasi live mengonfirmasi riak tetap aktif pasca-wake). *Batas bukti: assertion T4.6 memeriksa radius berhenti dan bertambah; tidak memeriksa alpha atau batas atas pertambahan radius.* |
| **Preservasi Alasan Pause (Multi-Reason)** | Alasan pause manual (`.manual`) tidak hilang ketika display/system sleep dan wake terjadi | **LULUS (Terbukti in-process sintetis)**: Terverifikasi dengan notifikasi `screensDidSleep/Wake` dan `willSleep/didWake` (T4.3, T4.4) |
| **Evaluasi Occlusion (Logika Model vs Live)** | Window membaca `occlusionState` untuk mendeteksi penutupan layar dan memicu jeda `.covered` | **LULUS (Terbukti logika model & observasi live)**: Logika terverifikasi via MockWindow (T4.5); status menu `Paused (covered)` saat desktop tertutup 100% dan kembali `Aktif` saat dibuka terkonfirmasi oleh observasi desktop riil pengguna |
| **Tembus Klik, Drag, & Marquee Finder** | Finder menerima klik, drag file, dan seleksi kotak di atas wallpaper pada mode biasa | **LULUS (Observasi fisik pengguna)**: Klik ikon terpilih normal, drag ikon berpindah posisi normal, dan seleksi marquee kotak biru muncul normal |
| **Fokus Aplikasi Non-Stealing (Aktivasi Programatik & UI)** | Aplikasi menolak menjadi key/main window (`canBecomeKey = false`, `canBecomeMain = false`, activation policy `.accessory`) dan tidak pernah mengambil alih menu bar | **LULUS (Terbukti penolakan programatik & observasi live)**: Window manager OS menolak aktivasi via System Events saat Finder aktif; saat area kolam diklik, Koi Wallpaper terbukti tidak merebut menu bar sistem |
| **Retensi Fokus Aplikasi Aktif Saat Klik Fisik Kolam** | Aplikasi yang sebelumnya aktif tetap fokus saat area kolam diklik fisik | **DITERIMA DENGAN BATASAN PLATFORM (Keputusan pengguna 20 Oktober 2026)**: Hasil observasi fisik pengguna mencatat klik fisik pada kolam menyebabkan aplikasi yang sebelumnya aktif kehilangan fokus dan menu bar beralih ke Finder. Koi Wallpaper terbukti tidak merebut fokus. Batasan platform WindowServer macOS ini diterima pengguna untuk M0; retensi fokus aplikasi aktif tidak diklaim lulus. |
| **Perilaku Spaces & Fullscreen** | Window berpindah mulus di semua Spaces tanpa flicker, tidak menempel ke space fullscreen lain (`.fullScreenNone`, `animationBehavior = .none`) | **LULUS (Observasi yang dilaporkan pengguna)**: Dikonfirmasi aman dan bebas flicker oleh pengguna pada sesi desktop live setelah perbaikan commit `81d1fbe` |
| **Show Desktop & Mission Control** | Window tetap diam di dasar desktop, tidak terangkat saat Mission Control | **LULUS (Observasi fisik pengguna)**: Terkonfirmasi jendela kolam tetap diam di dasar desktop, tidak mengecil menjadi thumbnail saat Mission Control, dan tetap stabil saat Show Desktop |
| **Live Desktop Occlusion** | Window mendeteksi penutupan penuh oleh aplikasi lain dan menjeda simulasi (`.covered`) | **LULUS (Observasi fisik pengguna)**: Terkonfirmasi status berubah menjadi `Paused (covered)` saat tertutup penuh dan kembali `Aktif` saat dibuka |
| **Hardware Sleep & Wake Fisik** | Laptop ditutup/dibuka atau display sleep perangkat keras | **LULUS (Observasi fisik pengguna)**: Terkonfirmasi aplikasi tetap berjalan responsif pasca-sleep fisik, status kembali `Aktif`, dan animasi riak di Mode Interaksi tetap berfungsi mulus |

---

## 3. Hasil Perintah Build dan Verifikasi

### A. Kompilasi, Packaging, & Inspeksi Metadata Bundle

Proses packaging bundle via `./scripts/build_app.sh debug`:
```bash
$ swift build
[0/1] Planning build
Building for debugging...
Build complete! (1.46s)

$ ./scripts/build_app.sh debug
==> Building KoiWallpaper (debug) via Swift Package Manager...
Build complete! (0.09s)
==> Packaging into /Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/build/KoiWallpaper.app...
==> Applying ad-hoc code signature...
/Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/build/KoiWallpaper.app: replacing existing signature
==> Successfully created /Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/build/KoiWallpaper.app
    Architecture: arm64
    Bundle ID:    com.koiwallpaper.KoiWallpaper
    LSUIElement:  true (menu bar agent)
```

Inspeksi metadata langsung (baca-saja) pada artefak bundle yang ada (`build/KoiWallpaper.app`):
```bash
$ file build/KoiWallpaper.app/Contents/MacOS/KoiWallpaper
build/KoiWallpaper.app/Contents/MacOS/KoiWallpaper: Mach-O 64-bit executable arm64

$ plutil -p build/KoiWallpaper.app/Contents/Info.plist
{
  "CFBundleDisplayName" => "Koi Wallpaper"
  "CFBundleExecutable" => "KoiWallpaper"
  "CFBundleIdentifier" => "com.koiwallpaper.KoiWallpaper"
  "CFBundleName" => "KoiWallpaper"
  "CFBundlePackageType" => "APPL"
  "CFBundleShortVersionString" => "0.1.0"
  "CFBundleVersion" => "0.1.0"
  "LSMinimumSystemVersion" => "14.0"
  "LSUIElement" => 1
  "NSHighResolutionCapable" => 1
  "NSPrincipalClass" => "NSApplication"
}

$ codesign -dvvv build/KoiWallpaper.app
Executable=/Users/gaudentiusgiden/dev/explore-dev/koi-wallpaper/build/KoiWallpaper.app/Contents/MacOS/KoiWallpaper
Identifier=com.koiwallpaper.KoiWallpaper
Format=app bundle with Mach-O thin (arm64)
CodeDirectory v=20400 size=2902 flags=0x2(adhoc) hashes=84+3 location=embedded
Hash type=sha256 size=32
CandidateCDHash sha256=aa17bee74601e209d6c4c9151ac8d1be94a07267
CandidateCDHashFull sha256=aa17bee74601e209d6c4c9151ac8d1be94a0726723bacfe936dd003b9f1b30e5
Hash choices=sha256
CMSDigest=aa17bee74601e209d6c4c9151ac8d1be94a0726723bacfe936dd003b9f1b30e5
CMSDigestType=2
CDHash=aa17bee74601e209d6c4c9151ac8d1be94a07267
Signature=adhoc
Info.plist entries=11
TeamIdentifier=not set
Sealed Resources version=2 rules=13 files=0
Internal requirements count=0 size=12
```

> [!NOTE] Pemisahan Metadata Signature dan Bukti Verifikasi Signature
> Perintah `codesign -dvvv` di atas hanya membaca dan menampilkan rincian metadata signature ad-hoc bundle, bukan membuktikan bahwa signature tersebut valid. Pemeriksaan keabsahan signature dijalankan secara baca-saja menggunakan `codesign --verify`:

```bash
$ codesign --verify --deep --strict --verbose=2 build/KoiWallpaper.app
build/KoiWallpaper.app: valid on disk
build/KoiWallpaper.app: satisfies its Designated Requirement
```
Hasil: Exit code `0` (`valid on disk` dan `satisfies its Designated Requirement`). Bukti ini memverifikasi secara langsung dan ketat bahwa bundle utuh, tidak rusak, dan memenuhi persyaratan designated requirement macOS.

### B. Suite Verifikasi In-Process (`swift run KoiWallpaperVerify`) — Working Tree dengan Perubahan Lokal di atas Commit `e50f4bd`

- **Tanggal & Waktu Eksekusi**: 19 Oktober 2026, 18:40 WIB
- **Asal Sumber**: Working tree lokal dengan perubahan belum di-commit pada `Sources/KoiWallpaperVerify/main.swift` di atas commit `HEAD` (`e50f4bd`). Log ini **tidak** berasal dari `HEAD` murni karena mencakup perubahan lokal pada `main.swift` (penyesuaian deskripsi assertion T4.6, redaksi klarifikasi audit TCC, penyesuaian nama variabel progression, dan penggantian checklist pending dengan pengungkapan cakupan bukti desktop).
- **Perintah**: `swift run KoiWallpaperVerify` (Exit code: `0`)

```text
=======================================================
Koi Wallpaper M0 Verification Suite
Target: macOS 14+ on Apple Silicon (arm64)
=======================================================

Screen Detected: 1680x1050, visibleFrame: 1680x1025

--- Section 1: Window Architecture & Configuration Properties ---
[PASS] [CONFIG] T1.1 Window Style & Non-Activation Flags: borderless=true, canBecomeKey=false, canBecomeMain=false (Live focus retention requires desktop validation)
[PASS] [CONFIG] T1.2 Collection Behavior Flags (Spaces & Mission Control): stationary=true, canJoinAllSpaces=true, ignoresCycle=true, fullScreenNone=true, animationBehavior=2
[PASS] [CONFIG] T1.3 Initial Window Level & Mouse Passthrough: level=-2147483623 (expected -2147483623), ignoresMouseEvents=true
[PASS] [CONFIG] T1.4 CoreGraphics Desktop Layer Ordering Constants: desktopWindow (-2147483623) < desktopIconWindow (-2147483603) (WindowServer compositing requires desktop validation)

--- Section 2: Mode Switching & Coordinator Synchronization ---
[PASS] [MODEL/SYNC] T2.1 Explicit Interaction Mode Activation: mode=interactive, level=-2147483602 (expected -2147483602), ignoresMouse=false, view.isInteractionMode=true
[PASS] [MODEL/SYNC] T2.2 Return to Click-Through Default Mode: mode=clickThrough, level=-2147483623 (expected -2147483623), ignoresMouse=true, view.isInteractionMode=false

--- Section 3: Synthetic NSEvent Dispatch & View Input Handling ---
[PASS] [SYNTHETIC EVENT] T3.1 View MouseDown in Interactive Mode (Regular Click -> Water Call): point=Optional((250.0, 350.0)), isOption=Optional(false), ripples=1, animating=true (Synthetic in-memory NSEvent)
[PASS] [SYNTHETIC EVENT] T3.2 View MouseDown in Interactive Mode (Option+Click -> Food Pellet): point=Optional((400.0, 500.0)), isOption=Optional(true), ripples=2 (Synthetic in-memory NSEvent)
[PASS] [SYNTHETIC EVENT] T3.3 Input Suppression in Click-Through and Paused States: clickThroughIgnored=true, pausedIgnored=true (Guarantees no accidental interactions or ripples when not interactive or paused)

--- Section 4: LifecyclePolicy & View Animation Synchronization ---
[PASS] [MODEL/SYNC] T4.1 Lifecycle Initial State (Unpaused, Zero Reasons): isPaused=false, reasons=[]
[PASS] [MODEL/SYNC] T4.2 Manual Pause Activation: isPaused=true, reasons=[KoiWallpaperCore.PauseReason.manual], delegateNotified=true
[PASS] [SYNTHETIC NOTIF] T4.3 Synthetic Display Sleep/Wake & Manual Pause Retention: Sleep added .displaySleep; Wake cleared .displaySleep while preserving .manual; app only resumed when manual pause cleared (Synthetic NSWorkspace notification)
[PASS] [SYNTHETIC NOTIF] T4.4 Synthetic System Sleep/Wake & Multi-Reason Preservation: Multi-reason state accurately tracks independent system and user pause causes without collision (Synthetic NSWorkspace notification)
[PASS] [MODEL/SYNC] T4.5 Window Occlusion Evaluation Logic (Mock Window): Hidden window sets .covered reason; visible window removes .covered (Live desktop occlusion requires desktop validation)
[PASS] [VIEW/ANIM] T4.6 Animation Freeze & Resume Radius Progression: initial=9.0, frozen=9.0, resumed=16.5. Radius is preserved during pause and increases after resume.

--- Section 5: Architectural Permissions & TCC Audit ---
[INFO] [ARCH AUDIT] TCC Privileges Audit: Test runner process AXIsProcessTrusted=true. Note: measures only the verifier process (KoiWallpaperVerify), not KoiWallpaper.app runtime permissions. Architecture does not declare Accessibility or Input Monitoring entitlements.

=======================================================
In-Process Suite Results: 15 Passed, 0 Failed
=======================================================

--------------------------------------------------------------------------------
EVIDENCE SCOPE & HONEST STATUS DISCLOSURE:
All tests above verified in-memory AppKit object configurations, state
coordinators, synthetic NSEvent dispatch, and synthetic notification handling.
THEY DO NOT PROVE REAL macOS DESKTOP WINDOW SERVER INTEGRATION.

Real macOS desktop integration (Finder interaction, window layering, focus
behavior, Spaces/fullscreen transitions, occlusion, and hardware sleep/wake)
is outside the scope of this in-process test suite.
Refer to docs/M0_AUDIT.md Section 5 for the live desktop validation checklist
and latest verified status.
--------------------------------------------------------------------------------
```

> [!NOTE] Catatan Asal Sumber, Revisi & Evaluasi Suite In-Process
> 1. **Asal Sumber & Revisi 15 PASS**: Log eksekusi 15 PASS di atas dihasilkan pada 19 Oktober 2026 pukul 18:40 WIB dari working tree lokal dengan modifikasi belum di-commit pada `Sources/KoiWallpaperVerify/main.swift` di atas commit `e50f4bd`. Modifikasi lokal tersebut menyelaraskan nama dan rincian assertion T4.6 dengan perilaku radius progression riil, memperjelas batas ukur audit TCC, serta mengganti checklist pending dengan keterangan netral bahwa integrasi desktop berada di luar cakupan in-process suite (mengarahkan pembaca ke Section 5 untuk status validasi desktop riil). Kode aplikasi dasar di bawahnya (`Sources/KoiWallpaperCore`) berbasis perbaikan commit `81d1fbe` (mengonfigurasi `.fullScreenNone` dan `animationBehavior = .none`).
> 2. **Batas Assertion T4.6**: Assertion T4.6 memverifikasi bahwa timer berhenti saat jeda (`radiusDuringPause == initialRadius`), timer kembali aktif saat resume, dan radius bertambah (`radiusAfterResume > radiusDuringPause`). Assertion ini **tidak** menguji perubahan nilai alpha dan **tidak** membatasi besarnya pertambahan radius setelah resume.
> 3. **Koreksi & Pembatasan Bukti TCC (Section 5)**:
>    - **Subjek Pemeriksaan**: Pemanggilan `AXIsProcessTrustedWithOptions(nil)` di atas hanya memeriksa status izin proses `KoiWallpaperVerify` (proses test runner di lingkungan terminal), **bukan** proses aplikasi `KoiWallpaper.app`.
>    - **Batas Klaim**: Hasil ini tidak membuktikan status izin aplikasi wallpaper atau membuktikan "zero TCC privileges". Bukti yang didukung hanyalah pada batas desain arsitektur: aplikasi tidak mendeklarasikan entitlement Accessibility atau Input Monitoring pada Info.plist, dan tidak memanggil API yang memicu prompt izin pengguna.
```

### C. Inspeksi Window Server Live dalam Safe Mode (`swift scripts/test_live_app.swift`)
```text
=======================================================
Testing Live KoiWallpaper.app Integration
Mode: SAFE (Read-only inspection)
=======================================================

Launching build/KoiWallpaper.app/Contents/MacOS/KoiWallpaper...
App is running with PID: 38251

--- Window Server Inspection ---
KoiWallpaper Window ID: 1290
KoiWallpaper Layer: -2147483623 (expected: -2147483623)
KoiWallpaper Bounds: ["Height": 1050, "X": 0, "Width": 1680, "Y": 0]
Finder Desktop Window Layer: -2147483603
Layer hierarchy check: PASS (Wallpaper layer -2147483623 < Finder layer -2147483603)

--- Desktop Icon Inspection ---
[SAFE MODE] Skipping synthesized mouse click and Finder selection modification.
To test live Finder click-through (requires explicit user consent), run with:
    swift scripts/test_live_app.swift --interactive-click-test
Side effects of --interactive-click-test:
  - Activates Finder
  - Modifies desktop icon selection
  - Dispatches CGEvent mouse clicks to desktop coordinates
Desktop icon detected: "Screenshot 2026-09-18 at 22.53.26" at position (1583, 33)

--- Terminating KoiWallpaper ---
App terminated with exit code: 15

=======================================================
Live Integration Summary:
1. Binary build and execution: PASS
2. Window Server layer (-2147483623): PASS
3. Finder layer precedence: PASS (Wallpaper layer -2147483623 < Finder layer -2147483603)
4. Desktop click-through: SKIPPED (Safe mode default - requires explicit approval via --interactive-click-test)
=======================================================
```

---

## 4. Batasan Bukti (Proof Boundaries)

Untuk menjaga integritas teknis, bukti pengujian dikelompokkan ke dalam domain terpisah:
1. **Bukti Kode & Konfigurasi Statis**: Membuktikan bahwa class, flag window style, collection behavior (`.stationary`, `.canJoinAllSpaces`, `.ignoresCycle`, `.fullScreenNone`), `animationBehavior = .none`, dan konstanta numerik CGWindowLevel telah diatur sesuai spesifikasi kode sumber.
2. **Bukti Metadata & Verifikasi Signature Bundle Artifact**: Membuktikan bahwa artefak `build/KoiWallpaper.app` arm64 memuat `Info.plist` (`LSMinimumSystemVersion=14.0`, `LSUIElement=true`) dan metadata signature ad-hoc (`codesign -dvvv`). Bukti keabsahan integritas bundle diverifikasi secara baca-saja via `codesign --verify --deep --strict --verbose=2 build/KoiWallpaper.app` (exit code 0, `valid on disk`, `satisfies its Designated Requirement`). *Bukti bundle ini diverifikasi secara mandiri dari struktur bundle artefak dan terpisah dari inspeksi live Window Server.*
3. **Bukti Uji Unit In-Process**: Membuktikan alur logika coordinator, delegasi, perubahan mode input, evaluasi Set alasan pause, supresi klik view saat paused/click-through, serta perilaku timer animasi riak.
   - **Rujukan Konfigurasi**: `T1.1` membuktikan window style & non-activation flags (`borderless=true`, `canBecomeKey=false`, `canBecomeMain=false`). `T1.3` membuktikan initial window level (`-2147483623`) dan mouse passthrough (`ignoresMouseEvents=true`).
   - **Batas Assertion T4.6**: Uji `T4.6` membuktikan bahwa timer animasi riak dihentikan saat jeda (radius tidak berubah selama jeda, `radiusDuringPause == initialRadius`), timer kembali aktif saat resume, dan radius bertambah setelah resume (`radiusAfterResume > radiusDuringPause`). Assertion ini **tidak** menguji nilai alpha atau membatasi batas atas besarnya pertambahan radius setelah resume, serta bukan bukti sinkronisasi clock simulasi fisika kontinu terhadap wall-clock waktu nyata.
   - **Batas Evaluasi Occlusion (T4.5)**: Evaluasi penutupan layar in-process diuji menggunakan `MockOcclusionWindow` (T4.5); integrasi occlusion desktop riil divalidasi terpisah pada sesi live desktop.
4. **Bukti Window Server Live (Safe Mode)**: Membuktikan bahwa ketika aplikasi dijalankan sebagai proses nyata, Window Server menempatkan window pada level `-2147483623` dan mendeteksi bahwa jendela desktop ikon Finder berada di atasnya pada level `-2147483603`. *Uji ini membuktikan hierarki visual jendela live, terpisah dari pengujian interaksi mouse fisik.*
5. **Validasi Interaksi Desktop (Sesi Live macOS Pengguna)**:
   - **Pembedaan Perilaku Fokus**: Uji via System Events dan observasi fisik membuktikan bahwa *Koi Wallpaper tidak pernah mengambil fokus sistem atau merebut menu bar* (`canBecomeKey = false`, `canBecomeMain = false`, accessory app). Namun, *aplikasi yang sebelumnya aktif tidak tetap fokus* saat klik fisik terjadi pada area kolam desktop, karena WindowServer macOS secara alami mendefokuskan jendela aplikasi aktif tersebut dan mengalihkan menu bar ke Finder.
   - **Observasi Dilaporkan Pengguna**: Seluruh pengujian interaksi fisik telah dilaksanakan langsung oleh pengguna (klik, drag, dan marquee Finder; riak cyan dan makanan oranye di Mode Interaksi; stabilitas Show Desktop & Mission Control; deteksi live occlusion `.covered`; serta ketahanan pasca-hardware sleep/wake).
6. **Batasan Audit Izin TCC**: Pemeriksaan `AXIsProcessTrusted` pada suite verifikasi hanya mencerminkan status proses test runner (`KoiWallpaperVerify`) dan **tidak membuktikan** batas hak akses runtime atau "zero TCC privileges" pada bundle aplikasi `KoiWallpaper.app`.

---

## 5. Checklist Validasi Desktop (Status Pengujian Nyata)

Checklist di bawah mencakup 15 item validasi sistem dan desktop. Pengujian yang memerlukan tindakan fisik manual pengguna dikelompokkan ke dalam 6 kelompok pengujian interaksi:
- **Kelompok 1 (Item #6, #7, #8)**: Interaksi mouse Finder (klik ikon, drag file, dan seleksi marquee).
- **Kelompok 2 (Item #9)**: Retensi fokus saat klik area kolam ketika aplikasi lain aktif.
- **Kelompok 3 (Item #10)**: Visualisasi riak air cyan dan Option+klik makanan oranye di Mode Interaksi.
- **Kelompok 4 (Item #12)**: Window management Show Desktop dan Mission Control.
- **Kelompok 5 (Item #14)**: Live desktop occlusion (`.covered` saat layar tertutup 100%).
- **Kelompok 6 (Item #15)**: Hardware sleep / wake fisik perangkat keras.

*(Catatan: Item #1–#5 diverifikasi melalui inspeksi programatik/safe mode; Item #11 dan #13 diverifikasi pada observasi live pengguna pasca-commit `81d1fbe`).*

| No | Skenario Validasi | Prosedur Uji & Hasil Pengamatan Langsung | Status Saat Ini |
| --- | --- | --- | :---: |
| 1 | **Fokus Aplikasi Non-Stealing (Aktivasi Programatik)** | System Events mencoba mengaktifkan `process "Koi Wallpaper"` agar menjadi frontmost saat Finder aktif. Window manager macOS menolak aktivasi; frontmost process tetap `Finder`. Window menolak key/main focus (`canBecomeKey = false`, `canBecomeMain = false`, activation policy `.accessory`). | **LULUS (Aktivasi Programatik Ditolak)** |
| 2 | **Menu Bar Mode Interaksi** | System Events mengklik status item `🐟` dan memilih "Mode Interaksi (Tangkap Klik)". Teramati: judul menu bar berubah menjadi `🐟⚡` (lebar status item berubah dari 39 ke 58); Window Server layer jendela kolam naik seketika dari `-2147483623` ke `-2147483602` (tepat di atas ikon desktop). Saat dimatikan, judul kembali ke `🐟` dan layer kembali ke `-2147483623`. | **LULUS** (Teramati langsung pada OS & Window Server) |
| 3 | **Menu Bar Jeda Manual (Pause)** | System Events mengklik status item `🐟` dan memilih "Jeda Manual (Pause)". Teramati: teks status menu bar berubah menjadi `Status Kolam: Paused (manual)`. Saat diklik ulang, teks kembali menjadi `Status Kolam: Aktif`. | **LULUS** (Teramati langsung pada OS) |
| 4 | **Hierarki Window Server Live** | Inspeksi `CGWindowListCopyWindowInfo` mendeteksi jendela Koi Wallpaper pada layer `-2147483623`, berada tepat di bawah jendela desktop Finder pada layer `-2147483603`, dengan flag `ignoresMouseEvents = true`. | **LULUS** (Teramati langsung di Window Server) |
| 5 | **Klik Sintetis CGEvent ke Finder** | Skrip `test_live_app.swift --interactive-click-test` mengirim `CGEvent` mouse click sintetis ke koordinat ikon desktop. Teramati: Finder tidak memilih ikon (seleksi kosong) karena pembatasan Quartz Event Tap latar belakang. | **KETERBATASAN SINTETIS TERCATAT** (Hanya klik fisik pengguna yang dapat dibuktikan) |
| 6 | **Klik Fisik Ikon Finder** | Klik file/folder di desktop secara manual menggunakan mouse/trackpad fisik dalam mode default. **Hasil pengamatan pengguna**: Ikon terpilih (*highlighted*) secara normal oleh Finder. | **LULUS (Observasi fisik pengguna)** |
| 7 | **Drag Fisik Ikon Finder** | Seret (drag) file desktop ke posisi lain secara manual. **Hasil pengamatan pengguna**: File dapat diseret dan berpindah posisi normal tanpa hambatan. | **LULUS (Observasi fisik pengguna)** |
| 8 | **Seleksi Marquee Finder** | Drag area kosong desktop membentuk kotak seleksi biru Finder. **Hasil pengamatan pengguna**: Kotak seleksi biru Finder muncul normal dan melingkupi ikon. | **LULUS (Observasi fisik pengguna)** |
| 9 | **Retensi Fokus Saat Klik Fisik Kolam** | Klik fisik mouse/trackpad langsung pada area kolam saat aplikasi lain (TextEdit/Notes/Terminal) aktif. **Hasil pengamatan pengguna**: Jendela aplikasi aktif kehilangan fokus saat area kolam diklik, dan menu bar atas beralih/tetap `Finder`. `Koi Wallpaper` terbukti tidak pernah mengambil fokus sistem (`canBecomeKey = false`, `canBecomeMain = false`). | **DITERIMA SEBAGAI BATASAN PLATFORM (Keputusan pengguna 20 Oktober 2026)** |
| 10 | **Visual Riak Air & Option+Klik** | Dalam Mode Interaksi (`🐟⚡`), amati banner, klik biasa untuk riak cyan, dan Option+klik untuk riak oranye. **Hasil pengamatan pengguna**: Banner *"Mode Interaksi Aktif"* muncul di kiri atas; riak cyan membesar-memudar terlihat jelas pada klik biasa; riak oranye tebal membesar-memudar terlihat jelas pada Option+klik. | **LULUS (Observasi fisik pengguna)** |
| 11 | **Navigasi Virtual Spaces** | Berpindah antar Space/Desktop (tiga jari geser atau Ctrl+Panah). Glitch awal (flicker) diperbaiki pada commit `81d1fbe` (layer background solid, `animationBehavior = .none`, dan `fullScreenNone`). Dikonfirmasi mulus dan bebas flicker oleh pengguna. | **LULUS (Observasi dilaporkan pengguna)** |
| 12 | **Show Desktop & Mission Control** | Menjalankan Mission Control (`F3` / `Ctrl+Panah Atas`) dan Show Desktop (`F11` / spread gesture). **Hasil pengamatan pengguna**: Jendela kolam tetap diam di dasar desktop (tidak mengecil menjadi thumbnail jendela) saat Mission Control, dan tetap berada di tempatnya tanpa bergeser saat Show Desktop. | **LULUS (Observasi fisik pengguna)** |
| 13 | **Aplikasi Fullscreen Lain** | Membuka aplikasi lain ke mode native Fullscreen. Glitch awal diperbaiki pada commit `81d1fbe` (`fullScreenNone`). Dikonfirmasi aman dan bebas konflik oleh pengguna. | **LULUS (Observasi dilaporkan pengguna)** |
| 14 | **Live Desktop Occlusion** | Menutup layar desktop secara penuh (100%) dengan jendela aplikasi lain untuk mengamati perubahan status kolam. **Hasil pengamatan pengguna**: Status kolam pada menu bar berubah menjadi `Status Kolam: Paused (covered)` saat tertutup penuh, dan kembali menjadi `Status Kolam: Aktif` saat dibuka kembali. | **LULUS (Observasi fisik pengguna)** |
| 15 | **Hardware Sleep & Wake Fisik** | Tutup lid laptop selama ~15 detik lalu buka kembali dan login. **Hasil pengamatan pengguna**: Aplikasi tetap stabil tanpa crash, ikon menu bar responsif, status kolam kembali `Status Kolam: Aktif`, dan animasi riak di Mode Interaksi tetap berfungsi mulus pasca-wake. | **LULUS (Observasi fisik pengguna)** |

---

## 6. Keputusan Penerimaan Milestone M0

> [!IMPORTANT] Status Penerimaan Milestone M0
> **STATUS SAAT INI: M0 DITERIMA DENGAN BATASAN PLATFORM (20 Oktober 2026, Asia/Jakarta) — MELANGKAH KE M1**
>
> Pada 20 Oktober 2026 (Asia/Jakarta), pengguna secara formal menerima batasan platform WindowServer macOS bahwa klik fisik pada area kolam desktop dapat mengaktifkan Finder dan membuat aplikasi yang sebelumnya aktif kehilangan fokus. Koi Wallpaper sendiri terbukti non-stealing dan tidak mengambil fokus (`canBecomeKey = false`, `canBecomeMain = false`, activation policy `.accessory`). Sesuai keputusan pengguna, kriteria penerimaan fokus diselesaikan dengan penerimaan batasan platform tersebut tanpa mengubah hasil observasi faktual atau mengklaim retensi fokus aplikasi sebelumnya lulus. Milestone M0 resmi diterima dan M1 (Simulasi Kolam Mandiri) menjadi milestone aktif berikutnya.

**Rincian Evaluasi:**
- **Kriteria Terverifikasi (Sesuai Bukti yang Tercatat):**
  1. **Fondasi bundle `.app` native arm64 macOS 14+**: Diverifikasi langsung dari artefak biner (`file`), plist (`plutil -p`), metadata signature (`codesign -dvvv`), serta verifikasi signature strict (`codesign --verify --deep --strict --verbose=2`). *(Bukti bundle ini terpisah dari inspeksi live Window Server).*
  2. **Konfigurasi `NSWindow` borderless non-activating & Level Desktop**: Nilai `canBecomeKey = false`, `canBecomeMain = false` terbukti in-process via `T1.1`; level desktop (`kCGDesktopWindowLevel = -2147483623`) dan `ignoresMouseEvents = true` terbukti in-process via `T1.3`.
  3. **Hierarki Window Server Live (Safe Mode)**: Window Server menempatkan window kolam pada layer `-2147483623` di bawah Finder Desktop Icon layer `-2147483603` (PID 38251 & PID 71959).
  4. **Fokus Aplikasi Non-Stealing (Koi Wallpaper Tidak Mengambil Fokus)**: System Events menolak aktivasi proses `Koi Wallpaper` saat Finder aktif. Uji fisik membuktikan aplikasi tidak pernah merebut menu bar sistem saat area kolam diklik.
  5. **Status Bar Menu Interaksi**: Toggle `🐟` <-> `🐟⚡` dan perpindahan layer runtime `-2147483602` (di atas Finder icon) teramati pada OS.
  6. **Menu Bar Pause**: Toggle status `Status Kolam: Aktif` <-> `Paused (manual)` teramati pada OS.
  7. **Sinkronisasi Lifecycle & View Animation**: Timer animasi riak berhenti saat jeda (radius terjaga) dan bertambah setelah resume (terbukti in-process T4.1-T4.4, T4.6, dan observasi live). *Batas bukti: assertion T4.6 memeriksa radius berhenti dan bertambah; tidak memeriksa alpha atau membatasi besarnya pertambahan radius.*
  8. **Navigasi Virtual Spaces & Transisi Fullscreen**: Dikonfirmasi aman dan bebas flicker melalui observasi yang dilaporkan oleh pengguna pada commit `81d1fbe` (menggunakan CALayer background solid, `animationBehavior = .none`, dan `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]`).
  9. **Tembus Klik, Drag, & Marquee Finder**: Dikonfirmasi LULUS oleh observasi fisik pengguna pada mode default (*click-through*).
  10. **Visual Riak Air & Pelet Makanan**: Dikonfirmasi LULUS oleh observasi fisik pengguna pada Mode Interaksi (`🐟⚡`).
  11. **Show Desktop & Mission Control**: Dikonfirmasi LULUS oleh observasi fisik pengguna (window tetap diam di dasar desktop).
  12. **Live Desktop Occlusion**: Dikonfirmasi LULUS oleh observasi fisik pengguna (status `Paused (covered)` saat tertutup 100%, `Aktif` saat dibuka kembali).
  13. **Hardware Sleep & Wake Fisik**: Dikonfirmasi LULUS oleh observasi fisik pengguna (aplikasi stabil, status kembali aktif, animasi riak tetap responsif).

- **Pembedaan Fokus & Catatan Keterbatasan Platform (Retensi Fokus Aplikasi Aktif):**
  - **Hasil Observasi**: Saat pengguna mengklik fisik area kolam desktop ketika aplikasi lain (seperti TextEdit, Notes, atau Terminal) sedang aktif, jendela aplikasi tersebut kehilangan fokus (*deactivated* oleh WindowServer macOS) dan fokus menu bar beralih ke `Finder`.
  - **Analisis Teknis**: `Koi Wallpaper` terbukti sepenuhnya tidak mengambil fokus (*non-stealing*, `canBecomeKey = false`, `canBecomeMain = false`, activation policy `.accessory`, dan tidak pernah merebut menu bar). Namun pada arsitektur WindowServer macOS, klik mouse fisik di luar area jendela aplikasi aktif yang jatuh pada lapisan desktop secara inheren dianggap oleh sistem operasi sebagai klik ke latar belakang Finder, sehingga WindowServer mendefokuskan aplikasi aktif sebelumnya.
  - **Keputusan Penerimaan Formal (20 Oktober 2026)**: Pengguna menerima perilaku WindowServer macOS ini sebagai batasan platform M0. Koi Wallpaper sendiri terbukti non-stealing dan tidak mengambil fokus. Keputusan penerimaan fokus dinyatakan selesai karena batasannya diterima secara sadar. Retensi fokus aplikasi aktif sebelumnya tidak diklaim lulus.

Dengan diterimanya M0 beserta batasan platform yang transparan, proyek melangkah ke **Milestone M1 (Simulasi Kolam Mandiri)** sesuai rencana implementasi.
