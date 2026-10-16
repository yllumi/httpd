# Static Web Server — Alpine + BusyBox httpd

Image Docker super ringan (± 8,5 MB) untuk menyajikan **halaman web HTML statis**, dibangun dari `alpine:latest` dengan **BusyBox httpd** sebagai web server.

- Docker Hub: <https://hub.docker.com/r/yllumi/httpd>
- GitHub: <https://github.com/yllumi/httpd>

## Ringkasan

| Komponen | Nilai |
| --- | --- |
| Base image | `alpine:latest` |
| Web server | BusyBox `httpd` di `/usr/sbin/httpd` (paket `busybox-extras`) |
| Document root | `/www` |
| Port di container | `80` |
| Port di host (compose) | `8081` |
| Shell | `sh` / `ash` (bawaan BusyBox) |
| Ukuran image | ± 8,5 MB |
| Konten bawaan | Halaman contoh `happy cooking!` dari `www/index.html` |

> **Penting:** image sudah berisi halaman contoh, jadi bisa langsung dipakai tanpa menyiapkan apa pun. Document root `/www` tetap di-mount ke named volume, dan Docker hanya mengisi volume itu dari image **saat volume masih kosong**. Kalau Anda punya volume lama dengan isi berbeda, jalankan `docker compose down -v` agar konten ter-seed ulang dari image.

## Menjalankan

### Docker Compose (disarankan)

```bash
docker compose up -d --build
```

Halaman bisa dibuka di <http://localhost:8081>.

### Docker run

Cara paling singkat, langsung memakai konten dari image:

```bash
docker run -d --name static-web-server -p 8081:80 yllumi/httpd:latest
```

Tambahkan named volume kalau ingin document root-nya writable dan isinya bertahan. Volume yang masih kosong akan di-seed dari konten image:

```bash
docker run -d \
  --name static-web-server \
  -p 8081:80 \
  -v www_data:/www \
  yllumi/httpd:latest
```

### Build image sendiri

```bash
docker build -t yllumi/httpd:latest .
```

## Mengganti konten

Sumber konten ada di folder `www/` pada repo ini, dan folder itu di-bake ke image lewat `COPY www/ /www/` di Dockerfile. Ada tiga cara menggantinya.

### 1. Ubah `www/index.html`, lalu build ulang

```bash
docker compose build
docker compose down -v && docker compose up -d
```

`down -v` diperlukan agar volume diisi ulang dari image, lihat [Mengapa perlu `down -v`](#mengapa-perlu-down--v).

### 2. Bind mount folder dari host (paling nyaman untuk development)

Aktifkan baris alternatif di `docker-compose.yml`:

```yaml
    volumes:
      - ./www:/www:ro
```

lalu jalankan `docker compose up -d`. Folder `www/` di project langsung jadi document root, jadi setiap perubahan file terlihat di browser tanpa build ulang.

### 3. Salin file langsung ke volume (tanpa build ulang)

```bash
docker compose cp ./www/index.html web:/www/
```

### Mengapa perlu `down -v`?

Docker mengisi named volume dari image hanya ketika volume masih **kosong**. Kalau volume `www_data` sudah berisi file dari build sebelumnya, file di volume itulah yang disajikan dan perubahan di image tidak menimpanya. Menghapus volume memaksa Docker mengisi ulang dari image:

```bash
docker compose down -v && docker compose up -d --build
```

Perlu diingat: `down -v` ikut menghapus file yang Anda tambahkan sendiri ke volume, jadi backup dulu bila isinya penting (lihat [Backup dan restore volume](#backup-dan-restore-volume)).

## Masuk ke shell container

```bash
docker compose exec -it web sh
```

Flag `-it` diperlukan agar sesi interaktif (prompt, riwayat perintah, dan line editing) berjalan normal. Tanpa `-it`, perintah tetap jalan tetapi tanpa prompt interaktif.

Image ini hanya menyertakan shell bawaan BusyBox (`sh`/`ash`) supaya ukurannya tetap kecil, jadi `bash` tidak tersedia. Kalau tetap memerlukan `bash`, tambahkan paketnya di Dockerfile lalu build ulang:

```dockerfile
RUN apk add --no-cache busybox-extras bash
```

Setelah itu `docker compose exec -it web bash` bisa dipakai. Perlu rebuild image karena `bash` adalah paket, bukan file di volume.

## Port dan volume

| Nama | Nilai default | Keterangan |
| --- | --- | --- |
| Port host | `8081` | ubah di `docker-compose.yml` bila bentrok |
| Port container | `80` | tetap |
| Volume | `www_data` (di host: `httpd_www_data`) | ter-mount ke `/www` |

Data di volume **tidak** ikut terhapus ketika:

- `docker compose restart`
- `docker compose down`
- image di-rebuild / container di-recreate

Data volume **akan hilang** jika menjalankan `docker compose down -v`, `docker volume rm httpd_www_data`, atau `docker volume prune`. Pastikan sudah backup bila isinya penting.

## Backup dan restore volume

Backup:

```bash
docker run --rm \
  -v httpd_www_data:/www \
  -v "$PWD":/backup \
  alpine tar czf /backup/www_data-backup.tar.gz -C /www .
```

Restore:

```bash
docker run --rm \
  -v httpd_www_data:/www \
  -v "$PWD":/backup \
  alpine tar xzf /backup/www_data-backup.tar.gz -C /www
```

## Menambah file lain (CSS, gambar, dll)

Taruh saja file tambahan di dalam `www/`, karena seluruh isi folder itu ikut ke image:

```
www/
├── index.html
├── style.css
└── gambar.jpg
```

Pada mode bind mount, file tersebut langsung tersedia. Pada mode named volume, build ulang lalu jalankan `docker compose down -v && docker compose up -d --build` agar volume ter-seed ulang.

## Troubleshooting

**Halaman 404 / container `unhealthy`**
Document root `/www` kosong, biasanya karena volume dibuat saat image masih kosong. Paksa Docker mengisi ulang volume dari image:

```bash
docker compose down -v && docker compose up -d --build
docker compose ps
docker compose exec web ls -la /www
```

**Error `exec: "/bin/httpd": no such file or directory`**
Applet `httpd` tidak ada di paket `busybox` bawaan Alpine maupun di `busybox-suid`. Applet ini hanya tersedia lewat paket `busybox-extras`, dan binary-nya ada di `/usr/sbin/httpd` (bukan `/bin/httpd`).

**Error `Bind for 0.0.0.0:8081 failed: port is already allocated`**
Port di host sudah dipakai proses lain. Cek dengan `ss -ltnp | grep 8081` lalu ganti port host di `docker-compose.yml`, misalnya menjadi `"8090:80"`.

**Perubahan `index.html` tidak muncul di browser**
Dua penyebab yang paling sering:

- Named volume sudah terisi konten lama, sehingga image baru tidak menimpanya. Jalankan `docker compose down -v && docker compose up -d --build`, atau pakai bind mount `./www:/www` selama development.
- Cache browser. Lakukan hard refresh (Ctrl+Shift+R) untuk melewatinya.

## Struktur proyek

```
.
├── Dockerfile           # image: Alpine + busybox-extras (httpd) + COPY www/
├── docker-compose.yml   # service web, port 8081, named volume www_data
├── www/
│   └── index.html       # halaman statis, di-bake ke image
└── README.md
```

## Catatan teknis

- Server dijalankan di foreground (`httpd -f`) sebagai proses utama (PID 1) container, dengan `-h /www` sebagai document root.
- BusyBox httpd sudah menangani MIME type umum seperti `text/html`, `text/css`, `text/javascript`, dan `image/*`.
- Untuk file yang tidak ada, server membalas `404`.
- Halaman contoh memuat gambar dari URL eksternal (`https://image.web.id/...`), jadi tampilannya bergantung pada host tersebut. Simpan gambarnya di dalam `www/` bila ingin sepenuhnya mandiri.
