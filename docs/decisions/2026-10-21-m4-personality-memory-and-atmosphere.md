# Keputusan Arsitektur: M4 — Sifat Ikan, Memori Kebiasaan Makan, dan Atmosfer

Tanggal: 21 Oktober 2026 (Asia/Jakarta).  
Status: Diterima & Terverifikasi melalui Suite `KoiWallpaperVerify` (T9.1–T9.8) dan `KoiWallpaperSimTest`.

---

## 1. Konteks & Tujuan

Milestone M4 bertujuan memberikan kepribadian individual pada setiap ikan koi, menghadirkan suasana kolam yang dinamis (*Calm* vs *Playful*), membangun ingatan kebiasaan makan jangka panjang (spasial dan temporal), serta menambahkan sentuhan atmosferik (sapaan harian dan efek hujan) tanpa mengorbankan stabilitas performa atau merusak keadaan dunia simulasi.

---

## 2. Sifat Ikan (*Fish Traits*) & Dinamika Mood

### 2.1 Struktur `FishTraits`
Setiap ikan koi memiliki profil temperamen dan responsivitas fisik yang unik:
- `curiosity` ($0.0 \dots 1.0$): Kecenderungan mendekati dan menyelidiki riak klik air.
- `boldness` ($0.0 \dots 1.0$): Keberanian mendekati pelet makanan baru dan menjelajah area terbuka.
- `agility` ($0.7 \dots 1.5$): Pengali kelincahan kemudi (*steering turn rate*).
- `feedingEagerness` ($0.0 \dots 1.0$): Kecepatan respon terhadap pelet makanan dan kebiasaan makan.

Preset bawaan diberikan sesuai karakter 8 varietas koi Jepang:
| Varietas | Keingintahuan (*Curiosity*) | Keberanian (*Boldness*) | Kelincahan (*Agility*) | Ketamakan (*Feeding Eagerness*) |
|---|---|---|---|---|
| **Kohaku** | 0.85 | 0.80 | 1.15 | 0.90 |
| **Taisho Sanke** | 0.70 | 0.65 | 1.05 | 0.75 |
| **Showa Sanshoku** | 0.60 | 0.75 | 1.00 | 0.80 |
| **Yamabuki Ogon** | 0.90 | 0.90 | 1.20 | 0.95 |
| **Asagi** | 0.45 | 0.40 | 0.90 | 0.55 |
| **Shiro Utsuri** | 0.55 | 0.60 | 0.95 | 0.65 |
| **Tancho** | 0.50 | 0.70 | 1.00 | 0.60 |
| **Kikusui** | 0.75 | 0.55 | 1.10 | 0.70 |

### 2.2 Suasana Kolam (*Pond Mood*)
Kolam mendukung dua mood:
- **Calm** (default): Kecepatan berenang santai ($1.0\times$ `baseSpeed`), radius belok lebar ($1.0\times$), dan frekuensi kibasan ekor alami ($1.0\times$).
- **Playful**: Kecepatan target meningkat ($1.25\times$ `baseSpeed`), kemudi lebih lincah ($1.15\times$ `effectiveTurnRate`), dan kibasan ekor lebih bersemangat ($1.20\times$ `wiggleRate`).
- Mengubah mood dapat dilakukan secara instan tanpa menghentikan simulasi, tanpa me-reset posisi ikan, dan tanpa menghilangkan pelet makanan aktif.

---

## 3. Sistem Memori Kebiasaan Makan (*Feeding Habit Routine*)

### 3.1 Penyimpanan Terpisah & Berversi
Memori spasial dan temporal disimpan secara terpisah dengan kunci dan skema berversi (Schema Version 1):
- Kunci Spasial: `com.koiwallpaper.memory.grid.v1`
- Kunci Temporal: `com.koiwallpaper.memory.time.v1`
Pemisahan ini mencegah overhead I/O yang tidak perlu dan memudahkan migrasi independen di masa mendatang.

### 3.2 Grid Lokasi Spasial 12 × 8 (96 Sel)
- Kolam dibagi menjadi $12$ kolom $\times$ $8$ baris sel.
- Koordinat disimpan dalam format ternormalisasi proporsional:
  $$u = \frac{x}{W} \in [0.0, 1.0], \quad v = \frac{y}{H} \in [0.0, 1.0]$$
- **Preservasi Skala Ukuran Kolam**: Saat resolusi jendela atau layar berubah (misal dari $500 \times 400$ ke $1920 \times 1080$), posisi memori tetap tepat di titik proporsional yang sama tanpa pergeseran atau distorsi.

### 3.3 Histogram Waktu 48 Slot
- 24 jam dibagi menjadi 48 slot interval 30 menit ($0 \dots 47$).
- Slot dihitung dari jam dan menit lokal:
  $$\text{slot} = \text{hour} \times 2 + (\text{minute} \ge 30 \,?\, 1 : 0)$$

### 3.4 Penggabungan Sesi 90 Detik (*Session Merging*)
Untuk mencegah eksploitasi klik berulang (*click spamming*):
- Klik pemberian makan yang terjadi dalam jendela **90 detik** pada sel yang sama atau sel tetangga berdekatan ($\Delta \text{col} \le 1, \Delta \text{row} \le 1$) digabungkan ke dalam sesi aktif yang sama.
- Penggabungan hanya memberikan kenaikan bobot marginal kecil ($+0.05$), bukan sesi baru.
- Pemberian makan yang berjarak $> 90$ detik dari sesi sebelumnya dihitung sebagai sesi independen baru ($+1.0$).

### 3.5 Ambang Batas Keyakinan (*Confidence Threshold*)
- Kebiasaan makan hanya terbentuk jika sel atau slot waktu mengakumulasi bobot $\ge 3.0$ (setara dengan minimal 3 sesi terpisah).
- Tiga klik mentah dalam rentang 10 detik menghasilkan bobot $1.0 + 0.05 + 0.05 = 1.10 < 3.0$, sehingga **tidak** dianggap sebagai kebiasaan. Kriteria menguji bobot yang dihitung, bukan menghitung klik mentah.

### 3.6 Peluruhan Eksponensial Paruh Waktu 7 Hari (*Half-Life Decay*)
Tanpa penguatan (pemberian makan berkelanjutan), memori memudar secara mulus mengikuti peluruhan eksponensial:
$$W(t) = W_0 \cdot 0.5^{\frac{\Delta t}{7 \times 86400}}$$
- Setelah 7 hari tanpa makan: bobot tersisa tepat $50\%$.
- Setelah 14 hari tanpa makan: bobot tersisa tepat $25\%$.

### 3.7 Penanganan Tengah Malam & Kebijakan Pergantian Zona Waktu
- **Jarak Sirkular Tengah Malam**: Jarak antara slot waktu dihitung secara sirkular:
  $$\text{dist}(s_1, s_2) = \min(|s_1 - s_2|, 48 - |s_1 - s_2|)$$
  Slot 47 (23:30) dan Slot 0 (00:00) memiliki jarak 1 slot, sehingga transisi tengah malam ditangani secara mulus.
- **Kebijakan Pergantian Zona Waktu**:
  1. *Waktu Sirkadian Pengguna*: Penentuan slot kebiasaan makan menggunakan *local wall-clock time* (`Calendar.current`), sehingga rutinitas makan siang atau makan malam pengguna tetap relevan di zona waktu tempat pengguna berada.
  2. *Peluruhan Fisik*: Perhitungan peluruhan waktu (half-life) strictly menggunakan timestamp absolut UTC (`Date().timeIntervalSince(lastDecayTimestamp)`), sehingga waktu fisik peluruhan berjalan kontinu dan tidak terdistorsi oleh lompatan jam Daylight Saving Time (DST) atau perpindahan zona waktu penerbangan.

---

## 4. Sistem Sapaan Harian (*Daily Greeting*)

- **Batas Hari Pukul 04:00 AM Kalender Lokal (Tahan DST)**:
  Hari efektif dihitung berbasis batas hari kalender lokal pengguna:
  - Jika jam lokal $< 4$ (pukul 00:00–03:59), waktu dianggap bagian dari hari kalender sebelumnya (`calendar.date(byAdding: .day, value: -1, to: date)`).
  - Jika jam lokal $\ge 4$ (pukul 04:00 ke atas), waktu memulai hari kalender efektif baru.
  - Pendekatan ini menggantikan pengurangan 4 jam absolut ($t - 14400\text{s}$), sehingga transisi Daylight Saving Time (DST), khususnya hari *spring-forward* (lompatan 02:00 $\to$ 03:00), tetap memulai hari efektif baru tepat pada pukul 04:00 lokal tanpa pergeseran keliru.
- **Tanpa Pengulangan (*Once-Per-Day Guarantee*)**: Sapaan hanya dipicu tepat 1 kali per hari efektif. Menutup dan membuka kembali jendela, memindahkan window antar Space, atau pergantian fokus pada hari yang sama tidak akan memicu sapaan ulang.
- **Pesan Kontekstual Berdasarkan Waktu**:
  - Pagi (04:00–11:00): *"Selamat pagi! Kolam koi menyambut hari baru bersamamu."*
  - Siang (11:00–15:00): *"Selamat siang! Nikmati ketenangan kolam di sela harimu."*
  - Sore (15:00–18:00): *"Selamat sore! Cahaya hangat menyinari ikan-ikan koi."*
  - Malam (18:00–04:00): *"Selamat malam! Kolam beristirahat dalam ketenangan."*

---

## 5. Validasi Memori Tersimpan & Ketahanan Data Rusak (*Corrupted Data Resilience*)

- Deserialisasi payload `FeedingMemoryGrid` dan `FeedingTimeHistogram` divalidasi secara ketat pada `init(from decoder: Decoder)`:
  1. **Versi Skema**: Wajib cocok dengan `schemaVersion == 1`; versi tidak didukung langsung ditolak.
  2. **Jumlah Sel & Slot**: Wajib tepat $96$ sel untuk grid ($12 \times 8$) dan $48$ slot untuk histogram ($24\text{ jam} \times 2$); jumlah tidak cocok ditolak.
  3. **Integritas Nilai Bobot (Termasuk NaN dan Infinity)**: Seluruh elemen wajib berupa angka riil terdefinisi (`isFinite && !isNaN`) dan tidak boleh negatif ($\ge 0.0$). JSONDecoder dan PropertyListDecoder dikonfigurasi dengan strategi float non-konforman (`.convertFromString`) sehingga token `Double.nan` dan `Double.infinity` (baik via JSON maupun IEEE 754 binary property lists) berhasil diparsing dan secara spesifik ditolak oleh loop validasi bobot dengan memicu `DecodingError.dataCorrupted`.
  4. **Konsistensi Metadata**: `lastSessionCellIndex` wajib berada dalam rentang valid $0 \dots 95$, `lastSessionSlot` dalam rentang $0 \dots 47$, dan `sessionCount \ge 0`.
- Diuji terhadap 9 kasus korupsi payload terpisah (`T9.7`): data biner acak, versi skema salah (v2), jumlah sel kurang (48), jumlah sel lebih (120), bobot negatif (-1.0), indeks sel di luar batas (999), sessionCount negatif (-5), bobot `Double.nan`, dan bobot `Double.infinity`.
- Jika payload rusak, store produksi (`UserDefaultsFeedingStore`) maupun in-memory (`InMemoryFeedingStore`) menangkap kegagalan decoding, mencatat peringatan secara tertib di `os.Logger`, dan mengembalikan instance default aman (96 sel bernilai nol, 48 slot bernilai nol).
- **Aplikasi tidak pernah crash atau mengalami akses array di luar batas (*out-of-bounds*)** akibat korupsi penyimpanan memori.

---

## 6. Isolasi Efek Samping Suite & Persistensi Antar-Muat Ulang (*Manager Reload Roundtrip*)

- **Isolasi Preferensi Suite**: `FeedingRoutineManager` dan `DailyGreetingManager` menyediakan penyedia store bawaan (`defaultStoreProvider`). Suite pengujian otomatis (`KoiWallpaperSimTest` dan `KoiWallpaperVerify`) mengarahkan provider ke `InMemoryFeedingStore` dan `InMemoryGreetingStore` (atau domain UserDefaults suite terisolasi). Fallback `UserDefaults(suiteName:) ?? .standard` dihilangkan dan digantikan `fatalError` eksplisit. Hal ini menjamin bahwa seluruh eksekusi tes bersifat deterministik dan **tidak pernah mengotori `UserDefaults.standard`**.
- **Siklus Hidup Pembersihan File Plist Suite (`T9.11`)**: Mengadopsi arsitektur Supervisor-Worker untuk memutus ketergantungan siklus flush asinkron `cfprefsd`. Pengujian yang membutuhkan `UserDefaults(suiteName:)` dieksekusi di dalam proses worker terisolasi (`--test-worker`). Saat worker berakhir, supervisor menangkap terminasi worker, memanggil `killall cfprefsd` untuk membuang antrean cache kotor in-memory dari proses yang telah mati, menguras dan menghapus seluruh file `.plist` fisik di `~/Library/Preferences/`, lalu menjalankan assertion `T9.11` pasca-terminasi worker. Karena supervisor tidak pernah menginisialisasi domain UserDefaults suite, proses supervisor keluar secara bersih tanpa memicu penulisan file plist kosong 42-byte. Hasil verifikasi membuktikan `remainingSuitePlists == []` secara konsisten sebelum dan sesudah proses suite selesai.
- **Persistensi Muat Ulang Manager (*Manager Reload Roundtrip*)**: Sesi makan dan catatan sapaan harian diverifikasi mampu dimuat kembali secara identik oleh manager baru yang dibuat dari store `UserDefaults` pada domain tes khusus (`T9.9` & `T9.10`). Bobot sel, slot histogram, ambang keyakinan, dan target proporsional kolam pulih utuh; sapaan harian tidak berulang pada hari efektif yang sama setelah instansiasi manager baru dari UserDefaults.

---

## 7. Efek Atmosfer & Kuota Sumber Daya

- **Efek Hujan**: Dapat dinyalakan/dimatikan melalui menu status bar (*"Efek Hujan Aktif"*) atau tombol pintas keyboard `'w'`.
- Menyalakan/mematikan hujan tidak menghapus atau mengubah entitas koi dan pelet makanan aktif.
- **Batas Kuota Riak Atmosfer**: Riak tetes hujan (`RippleType.rainDrop`) dibatasi secara ketat maksimal **16 riak aktif** (`maxRainRipples = 16`). Tetesan hujan baru tidak dialokasikan jika kuota tercapai, memastikan beban render CoreGraphics tetap ringan dan stabil di bawah batas anggaran frame 16.67 ms.

---

## 8. Hasil Verifikasi

Seluruh kriteria penerimaan Milestone M4 dan temuan audit telah diverifikasi melalui suite otomasi:
- **`KoiWallpaperVerify` Bagian 9 (T9.1–T9.11)**: 11/11 Lulus (Total suite: 49 Lulus, 0 Gagal).
- **`KoiWallpaperSimTest` (T0.1–T11.2)**: 19/19 Lulus.
