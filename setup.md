# Panduan Inisialisasi Ulang Topologi GNS3 (Bagian Arul — K-29)

Panduan ini digunakan setiap kali proyek GNS3 baru dinyalakan kembali (*cold start*) agar seluruh konfigurasi router, firewall, NAT, dan layanan MAGI hingga **Soal 11 / 12** aktif kembali tanpa merusak progres yang sudah persisten.

> **Catatan Umum:**
> - File `/root/*.sh` dan konfigurasi `/etc/network/interfaces` tetap tersimpan di disk container.
> - Yang **hilang saat GNS3 dimatikan** hanyalah state di RAM: IP/route sementara pada router, `ip_forward`, aturan `iptables`, dan proses background listener `nc`.
> - Jika lupa nama file script Soal 2/3 di salah satu router, cek dulu dengan `ls /root`.

---

## Tahap 1 — Inisialisasi 6 Router Bagian Arul (Wajib Dijalankan Ulang)

Jalankan berurutan dari router paling atas (**Gendou**) ke bawah agar NAT dan routing aktif terlebih dahulu.

### 1. Router `Gendou` (Soal 2 – 5 Sekaligus)
```bash
bash /root/gendo.sh
```
*Memasang ulang `eth0` (DHCP NAT1), `eth1`–`eth8` statis, `ip_forward=1`, 21 static routes + ringkasan CIDR, DNS `8.8.8.8`, NAT `MASQUERADE`, serta firewall default deny (`INPUT` & `FORWARD DROP`).*

### 2. Router Cabang Kanan & Bawah (`Fuyutsuki`, `Maya`, `Toji`, `Shigeru`, `Makoto`)
Jalankan script **Soal 2** lalu **Soal 3** di masing-masing konsol router (sesuaikan nama file jika kamu menyimpannya sebagai `fuyutsuki.sh` / `soal3_fuyutsuki.sh`, dll.):

| Urutan | Router | Perintah Inisialisasi | Verifikasi Cepat (`ip route`) |
| :-: | :--- | :--- | :--- |
| 1 | **Fuyutsuki** | `bash /root/soal2.sh && bash /root/soal3.sh` | `default via 10.78.4.133`, `10.78.3.192/27 via 10.78.4.162`, `10.78.4.72/29 via 10.78.4.166` |
| 2 | **Maya** | `bash /root/soal2.sh && bash /root/soal3.sh` | `default via 10.78.4.161` |
| 3 | **Toji** | `bash /root/soal2.sh && bash /root/soal3.sh` | `default via 10.78.4.165` |
| 4 | **Shigeru** | `bash /root/soal2.sh && bash /root/soal3.sh` | `default via 10.78.4.129`, `10.78.4.88/29 via 10.78.4.170` |
| 5 | **Makoto** | `bash /root/soal2.sh && bash /root/soal3.sh` | `default via 10.78.4.169` |

*(Jika ada router yang ternyata hanya kehilangan `default route`, cukup jalankan `bash /root/soal3.sh` saja.)*

---

## Tahap 2 — Verifikasi 11 Container Non-Router (Soal 6 — Permanen)

Ke-11 container berikut **sudah permanen** melalui `/etc/network/interfaces` dan `ifupdown`, sehingga **tidak perlu menjalankan `soal6.sh` lagi**:

- **Switch-Medic:** `Pen-Pen` (`10.78.3.194`), `Medic-Bay` (`10.78.3.195`)
- **Switch-Terminal:** `Magi-Casper` (`10.78.4.58`), `Magi-Balthasar` (`10.78.4.59`), `Magi-Melchior` (`10.78.4.60`)
- **Switch-Dogma:** `Lilith` (`10.78.4.74`), `Adam` (`10.78.4.75`)
- **Switch-Monolith:** `Zeruel` (`10.78.4.82`), `Armisael` (`10.78.4.83`)
- **Switch-Radar:** `Radar-Array` (`10.78.4.90`)
- **Switch-Cmd:** `Tokyo3-Core` (`10.78.4.106`)

Cukup pastikan IP langsung muncul saat membuka konsol dengan:
```bash
ip -br a && ip route
```
> **Fallback:** Hanya jika ada container yang `eth0`-nya kosong setelah start, jalankan `bash /root/soal6.sh` pada container tersebut saja.

---

## Tahap 3 — Nyalakan Ulang Cluster MAGI & Firewall Casper (Soal 7, 11, 12)

Listener `nc` dan aturan `iptables` di node host tidak tersimpan setelah shutdown, jadi wajib dinyalakan ulang di 3 node MAGI:

### 1. `Magi-Balthasar` (TCP 5000 & 5001)
```bash
bash /root/balthasar.sh
```

### 2. `Magi-Melchior` (TCP 5000)
```bash
bash /root/melchior.sh
```

### 3. `Magi-Casper` (TCP 5000 + Firewall)
Pilih sesuai progres terakhirmu:
- **Jika hari ini baru mau mulai mengerjakan Soal 12** (pulihkan dulu kondisi Soal 7 + 11):
  ```bash
  bash /root/casperV2.sh
  ```
  *Setelah itu langsung lanjutkan alur Soal 12: `./break_fw.sh` → `bash /root/soal12_casper.sh diag` → `bash /root/soal12_casper.sh` → `bash /root/soal12_casper.sh test`.*
- **Jika Soal 12 sudah selesai dan `/root/casper.sh` sudah di-update ke versi final (Soal 7 + 11 + 12):**
  ```bash
  bash /root/casper.sh
  ```

---

## Tahap 4 — Sanity Check Cepat (1 Menit)

Pastikan seluruh jaringan wilayah Arul sudah kembali normal sebelum lanjut ke soal berikutnya:

1. **Di `Gendou`:**
   ```bash
   iptables -S
   iptables -t nat -S
   ping -c 2 8.8.8.8
   ```
   *Pastikan policy `INPUT`/`FORWARD DROP`, rule `MASQUERADE` ada, dan ping `8.8.8.8` berhasil.*

2. **Di `Armisael` (`10.78.4.83`):**
   ```bash
   ping -c 2 10.78.4.74   # ke Lilith (uji antar-cabang Shigeru <-> Fuyutsuki <-> Toji)
   ping -c 2 8.8.8.8      # ke internet (uji NAT & firewall Gendo)
   ```

3. **Di `Lilith` (`10.78.4.74`):**
   ```bash
   ping -c 2 -W 2 10.78.4.58
   echo "cek hidup setelah restart" | nc -w 3 10.78.4.58 5000
   ```
   *Ping ke Casper harus **100% packet loss** tanpa pesan `Destination Net Unreachable`, sedangkan pesan `nc` masuk saat dicek di `Magi-Casper` lewat `bash /root/casper.sh log`.*

---

## Checklist Status Lanjutan

- [x] **Soal 2 – 7, 9, 11:** Pulih penuh dengan menjalankan Tahap 1 – 3 di atas.
- [ ] **Soal 12 (`Magi-Casper`):** Aman dikerjakan/diverifikasi hari ini; tinggal menyusulkan tes `nc` dari `Unit-00` setelah Julian siap.
- [ ] **Soal 10 (`Misato` + `Gendou`):** Tahan dulu sampai Julian selesai Soal 3 & 6 di cabang `Misato` (`Unit-01`/`02`/`00`) dan `Kaji` (`Spy`).