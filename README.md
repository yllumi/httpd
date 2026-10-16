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

> **Penting:** image ini sengaja **tidak berisi file web apa pun**. Document root `/www` di-mount ke named volume, jadi Anda yang mengisi kontennya. Selama `/www` masih kosong, server membalas **404** dan status container akan `unhealthy`. Lihat [Menambahkan konten](#menambahkan-konten).

## Menjalankan

### Docker Compose (disarankan)

```bash
docker compose up -d --build
```

Halaman bisa dibuka di <http://localhost:8081>.

### Docker run

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

## Menambahkan konten

Konten **tidak** disimpan di image, melainkan di named volume yang ter-mount ke `/www`. Ada tiga cara mengisinya.

### 1. Tulis langsung dari dalam container

```bash
docker compose exec web sh
```

```bash
cat > /www/index.html <<'HTML'
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="utf-8">
  <title>Halo</title>
</head>
<body>
  <h1>Halo dari BusyBox httpd</h1>
</body>
</html>
HTML
exit
```

### 2. Salin folder dari host dengan `docker compose cp`

```bash
docker compose cp ./htdocs/. web:/www/
```

### 3. Bind mount folder dari host (edit langsung, cocok untuk development)

Aktifkan baris alternatif di `docker-compose.yml`:

```yaml
    volumes:
      - ./htdocs:/www:ro
```

lalu buat `htdocs/index.html` dan jalankan `docker compose up -d`. Dengan cara ini perubahan file di host langsung terlihat di browser tanpa build ulang.

Setelah ada `index.html`, status container berubah dari `unhealthy` menjadi `healthy` — healthcheck-nya memang memverifikasi bahwa halaman utama benar-benar bisa dilayani.

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

## Ingin konten ikut ke-bake ke image?

Di `Dockerfile` ada baris `COPY` yang sengaja di-comment. Siapkan folder `site/` berisi `index.html`:

```
site/
└── index.html
```

lalu aktifkan baris berikut dan build ulang:

```dockerfile
COPY site/ /www/
```

Perlu diingat: Docker hanya mengisi volume dari image ketika volume masih **kosong**. Jika volume sudah terisi, konten dari image tidak akan menimpanya.

## Troubleshooting

**Halaman 404 / container `unhealthy`**
Document root `/www` masih kosong. Tambahkan `index.html` seperti pada bagian [Menambahkan konten](#menambahkan-konten). Status container bisa dicek dengan:

```bash
docker compose ps
docker compose exec web ls -la /www
```

**Error `exec: "/bin/httpd": no such file or directory`**
Applet `httpd` tidak ada di paket `busybox` bawaan Alpine maupun di `busybox-suid`. Applet ini hanya tersedia lewat paket `busybox-extras`, dan binary-nya ada di `/usr/sbin/httpd` (bukan `/bin/httpd`).

**Error `Bind for 0.0.0.0:8081 failed: port is already allocated`**
Port di host sudah dipakai proses lain. Cek dengan `ss -ltnp | grep 8081` lalu ganti port host di `docker-compose.yml`, misalnya menjadi `"8090:80"`.

**Perubahan `index.html` tidak muncul di browser**
Pastikan Anda mengedit file yang benar:

- Kalau memakai named volume, file ada di dalam volume (`/www` di dalam container), bukan di folder project.
- Lakukan hard refresh di browser (Ctrl+Shift+R) untuk melewati cache.

## Struktur proyek

```
.
├── Dockerfile           # image: Alpine + busybox-extras (httpd)
├── docker-compose.yml   # service web, port 8081, named volume www_data
└── README.md
```

## Catatan teknis

- Server dijalankan di foreground (`httpd -f`) sebagai proses utama (PID 1) container, dengan `-h /www` sebagai document root.
- BusyBox httpd sudah menangani MIME type umum seperti `text/html`, `text/css`, `text/javascript`, dan `image/*`.
- Untuk file yang tidak ada, server membalas `404`.
