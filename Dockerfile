FROM alpine:latest

# Applet `httpd` tidak ada di paket busybox bawaan Alpine maupun di
# busybox-suid. Paket busybox-extras-lah yang menyediakannya, terpasang
# sebagai /usr/sbin/httpd.
RUN apk add --no-cache busybox-extras

WORKDIR /www

# Konten statis di-bake ke image: ini juga jadi sumber seed untuk named
# volume yang di-mount ke /www (Docker menyalin isi image saat volume
# pertama kali dibuat).
# COPY site/ /www/

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null 2>&1 || exit 1

CMD ["/usr/sbin/httpd", "-f", "-p", "80", "-h", "/www"]