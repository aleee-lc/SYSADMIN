#!/bin/bash

# Variables globales
CERT_DIR="/etc/ssl/certs/mail"
WWW_DIR="/var/www/html/squirrelmail"

# Validar dominio
validar_dominio() {
  if [[ ! "$1" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo "Dominio no valido. Ejemplo valido: reprobados.com"
    return 1
  fi
  return 0
}

# Solicitar dominio con validacion
solicitar_dominio() {
  while true; do
    read -p "Ingrese el nombre de dominio para su servidor (ej: reprobados.com): " MAIL_DOMAIN
    validar_dominio "$MAIL_DOMAIN" && break
  done
}

# Solicitar puertos personalizados
solicitar_puertos() {
  read -p "Desea usar puertos por defecto? (s/n): " usar_default
  if [[ "$usar_default" =~ ^[sS]$ ]]; then
    PORT_SMTP=587
    PORT_POP3=110
    PORT_IMAP=993
  else
    read -p "Puerto SMTP (recomendado 587): " PORT_SMTP
    read -p "Puerto POP3 (recomendado 110): " PORT_POP3
    read -p "Puerto IMAP (recomendado 993): " PORT_IMAP
  fi
}

# Instalar paquetes necesarios
instalar_paquetes() {
  echo "Instalando paquetes necesarios..."
  apt update
  DEBIAN_FRONTEND=noninteractive apt install -y postfix dovecot-core dovecot-imapd dovecot-pop3d mailutils mutt apache2 php php-mbstring unzip wget ufw
}

# Generar certificado SSL
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
  sed -i 's|^#*\s*protocols =.*|protocols = imap pop3|' /etc/dovecot/dovecot.conf

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

# Crear usuario
gestionar_usuarios() {
  while true; do
    echo "1) Crear usuario"
    echo "2) Eliminar usuario"
    echo "3) Salir"
    read -p "Seleccione una opcion: " opcion
    case $opcion in
      1)
        read -p "Nombre de usuario: " user
        read -s -p "Contraseña: " pass
        echo
        id "$user" &>/dev/null || useradd -m "$user"
        echo "$user:$pass" | chpasswd
        runuser -l "$user" -c 'mkdir -p ~/Maildir && chmod -R 700 ~/Maildir'
        echo "Usuario $user creado"
        ;;
      2)
        read -p "Nombre de usuario a eliminar: " user
        userdel -r "$user"
        echo "Usuario $user eliminado"
        ;;
      3)
        break
        ;;
      *)
        echo "Opcion no valida"
        ;;
    esac
  done
}

# Instalar SquirrelMail
instalar_squirrelmail() {
  echo "Instalando SquirrelMail..."
  mkdir -p "$WWW_DIR"
  cd "$WWW_DIR"
  wget https://sourceforge.net/projects/squirrelmail/files/latest/download -O squirrelmail.zip
  unzip squirrelmail.zip
  mv squirrelmail-*/* .
  rm -rf squirrelmail-*

  cat <<EOF > /etc/apache2/sites-available/squirrelmail.conf
Alias /squirrelmail $WWW_DIR
<Directory $WWW_DIR>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
EOF

  a2ensite squirrelmail
  systemctl reload apache2
}

# Configurar firewall
configurar_firewall() {
  echo "Configurando UFW para permitir puertos..."
  ufw allow "$PORT_SMTP"
  ufw allow "$PORT_POP3"
  ufw allow "$PORT_IMAP"
  ufw allow 80
  ufw --force enable
}

# Reiniciar servicios
reiniciar_servicios() {
  echo "Reiniciando servicios..."
  systemctl restart postfix dovecot apache2
}

# Ejecutar instalacion completa
main() {
  solicitar_dominio
  solicitar_puertos
  instalar_paquetes
  generar_certificado_ssl
  configurar_postfix
  configurar_dovecot
  instalar_squirrelmail
  configurar_firewall
  reiniciar_servicios
  gestionar_usuarios

  echo ""
  echo "Servidor de correo configurado."
  echo "Dominio: mail.$MAIL_DOMAIN"
  echo "SMTP: puerto $PORT_SMTP"
  echo "POP3: puerto $PORT_POP3"
  echo "IMAP: puerto $PORT_IMAP"
  echo "Webmail: http://ip-servidor/squirrelmail"
}

main
