#!/bin/bash

# Solicitar el dominio
read -p "Ingrese el nombre de dominio para su servidor (ej: reprobados.com): " MAIL_DOMAIN
MAIL_USER="alumno"
MAIL_PASS="1234"
CERT_DIR="/etc/ssl/certs/mail"

# Instalar paquetes necesarios
instalar_paquetes() {
  echo "Instalando paquetes necesarios..."
  apt update
  DEBIAN_FRONTEND=noninteractive apt install -y postfix dovecot-core dovecot-imapd mailutils mutt openssl
}

# Generar certificado SSL autofirmado
generar_certificado_ssl() {
  echo "Generando certificado SSL..."
  mkdir -p "$CERT_DIR"
  openssl req -new -x509 -days 365 -nodes \
    -out "$CERT_DIR/mailcert.pem" \
    -keyout "$CERT_DIR/mailkey.pem" \
    -subj "/C=MX/ST=Estado/L=Ciudad/O=MiServidor/CN=mail.$MAIL_DOMAIN"
}

# Configurar Postfix
configurar_postfix() {
  echo "Configurando Postfix..."
  postconf -e "myhostname = mail.$MAIL_DOMAIN"
  postconf -e "myorigin = /etc/mailname"
  postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost"
  postconf -e "inet_interfaces = all"
  postconf -e "inet_protocols = ipv4"
  postconf -e "home_mailbox = Maildir/"
  postconf -e "smtpd_tls_cert_file = $CERT_DIR/mailcert.pem"
  postconf -e "smtpd_tls_key_file = $CERT_DIR/mailkey.pem"
  postconf -e "smtpd_use_tls = yes"
  postconf -e "smtp_tls_security_level = may"
  postconf -e "smtpd_tls_session_cache_database = btree:\${data_directory}/smtpd_scache"

  echo "$MAIL_DOMAIN" > /etc/mailname
}

# Configurar Dovecot
configurar_dovecot() {
  echo "Configurando Dovecot..."
  sed -i 's|^#*\s*mail_location =.*|mail_location = maildir:~/Maildir|' /etc/dovecot/conf.d/10-mail.conf
  sed -i 's|^#*\s*ssl =.*|ssl = required|' /etc/dovecot/conf.d/10-ssl.conf
  sed -i "s|^#*\s*ssl_cert =.*|ssl_cert = <$CERT_DIR/mailcert.pem|" /etc/dovecot/conf.d/10-ssl.conf
  sed -i "s|^#*\s*ssl_key =.*|ssl_key = <$CERT_DIR/mailkey.pem|" /etc/dovecot/conf.d/10-ssl.conf
  sed -i 's|^#*\s*disable_plaintext_auth =.*|disable_plaintext_auth = no|' /etc/dovecot/conf.d/10-auth.conf

  # Crear configuración de autenticación para Postfix
  cat <<EOF > /etc/dovecot/conf.d/auth-postfix.conf.ext
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
EOF

  grep -q 'auth-postfix.conf.ext' /etc/dovecot/conf.d/10-master.conf || echo '!include auth-postfix.conf.ext' >> /etc/dovecot/conf.d/10-master.conf
}

# Crear usuario de prueba
crear_usuario() {
  echo "Creando usuario $MAIL_USER..."
  id "$MAIL_USER" &>/dev/null || useradd -m "$MAIL_USER"
  echo "$MAIL_USER:$MAIL_PASS" | chpasswd
  runuser -l "$MAIL_USER" -c 'mkdir -p ~/Maildir && chmod -R 700 ~/Maildir'
}

# Reiniciar servicios
reiniciar_servicios() {
  echo "Reiniciando servicios..."
  systemctl restart postfix dovecot
}

# Ejecutar todo
main() {
  instalar_paquetes
  generar_certificado_ssl
  configurar_postfix
  configurar_dovecot
  crear_usuario
  reiniciar_servicios

  echo ""
  echo "Servidor de correo configurado correctamente"
  echo "Dominio: mail.$MAIL_DOMAIN"
  echo "Usuario de prueba: $MAIL_USER"
  echo "Contraseña: $MAIL_PASS"
  echo "IMAP seguro (SSL): puerto 993"
  echo "SMTP con STARTTLS: puerto 587"
}

main

