FROM alpine:latest

# Applet `httpd` tidak ada di paket busybox bawaan Alpine maupun di
# busybox-suid. Paket busybox-extras-lah yang menyediakannya, terpasang
# sebagai /usr/sbin/httpd.
RUN apk add --no-cache busybox-extras

WORKDIR /www

# Halaman contoh di-bake ke image supaya `docker run yllumi/httpd` langsung
# menampilkan halaman, tanpa perlu mengisi volume lebih dulu. Konten ini juga
# menjadi isi awal named volume www_data saat volume dibuat pertama kali
# (Docker mengisi volume yang masih kosong dengan isi image).
COPY www/ /www/

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null 2>&1 || exit 1

CMD ["/usr/sbin/httpd", "-f", "-p", "80", "-h", "/www"]