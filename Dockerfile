FROM alpine:latest

# Applet `httpd` tidak ada di paket busybox bawaan Alpine maupun di
# busybox-suid. Paket busybox-extras-lah yang menyediakannya, terpasang
# sebagai /usr/sbin/httpd.
RUN apk add --no-cache busybox-extras

WORKDIR /www

# Image sengaja TIDAK berisi file web apa pun: konten disimpan di named
# volume yang di-mount ke /www (lihat docker-compose.yml), sehingga image
# bisa dipakai ulang untuk situs apa saja.
# Kalau ingin konten ikut ke-bake ke image, buat folder site/ berisi
# index.html lalu aktifkan baris COPY di bawah saat build.
# COPY site/ /www/

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null 2>&1 || exit 1

CMD ["/usr/sbin/httpd", "-f", "-p", "80", "-h", "/www"]