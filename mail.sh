# !/bin/bash
# correo/verificar_servicio.sh


verificar_servicio (){
    local servicio="$1"

    # Verificar si el paquete está instalado
    if dpkg -l | grep -q "^ii  $servicio"; then
        return 0 # Servicio instalado
    fi
    return 1 # No esta instalado
}




crear_user(){
    local user="$1"
    
    # Crear el usuario con su directorio home
    echo "Creando usuario $user..."
    sudo useradd -m -s /bin/bash $user

    solicitar_contra "$user"
    
    sudo usermod -m -d /var/www/html/$user $user
    sudo mkdir -p /var/www/html/$user
}





conf_dns(){
    local ip="$1"
    local dominio="$2"
    #Instalar bind9

    # Verifica antes de instalar bin9
    #if verificar_servicio "bind9"; then
    #    echo "Bind9 ya esta instalado y configurado"
    #    return
    #fi

    echo "Instalando bind9"
    sudo apt-get install bind9 bind9utils bind9-doc -y
    sudo apt-get install dnsutils -y

    #Editar named.conf.local para las zonas
    echo "Configurando zonas"
    sudo tee -a /etc/bind/named.conf.local > /dev/null <<EOF
    zone "$dominio" {
        type master;
        file "/etc/bind/db.$dominio";
    };

    zone "$(echo $ip | awk -F. '{print $3"."$2"."$1}').in-addr.arpa" {
        type master;
        file "/etc/bind/db.$(echo $ip | awk -F. '{print $3"."$2"."$1}')";
    };
EOF

#Crear zona directa
echo "Creando zona directa"
sudo tee /etc/bind/db.$dominio > /dev/null <<EOF
\$TTL    604800
@       IN      SOA     $dominio. root.$dominio. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@           IN      NS      $dominio.
servidor    IN      A       $ip
@           IN      A       $ip
www         IN      CNAME   $dominio.
EOF

#Crear zona inversa
echo "Creando zona inversa"
sudo tee /etc/bind/db.$(echo $ip | awk -F. '{print $3"."$2"."$1}') > /dev/null <<EOF
\$TTL    604800
@       IN      SOA     $dominio. root.$dominio. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      $dominio.
$(echo $ip | awk -F. '{print $4}')     IN      PTR     $dominio.
EOF

    #Editar resolv.conf para fijar la IP en el servidor DNS
    sudo sed -i "/^search /c\search $dominio" /etc/resolv.conf    #Utilizo sed -i para modificar especificamente esa linea
    sudo sed -i "/^nameserver /c\nameserver $ip" /etc/resolv.conf
    echo "Fijando la IP $ip para el servidor DNS"

    #Reiniciar bind9
    echo "Reiniciando bind9"
    sudo systemctl restart bind9
    echo "Configuración finalizada :)"
}


# correo/conf_correo.sh

conf_correo(){
    dominio="paulook.com"
    ip="192.168.1.10"
    # Actualiza la lista de paquetes 
    sudo apt update 
    sudo apt-get install apache2 -y
    
    sudo apt install software-properties-common -y
    sudo add-apt-repository ppa:ondrej/php -y
    sudo apt update
    sudo apt install php7.4 libapache2-mod-php7.4 php-mysql -y

    # Evitar la pantalla interactiva de configuración
    echo "postfix postfix/main_mailer_type select Internet Site" | sudo debconf-set-selections
    echo "postfix postfix/mailname string $dominio" | sudo debconf-set-selections

    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y postfix

    sudo apt install dovecot-imapd dovecot-pop3d -y
    sudo systemctl restart dovecot
    sudo apt install bsd-mailx -y

    # Modifica la configuración de redes permitidas en Postfix
    sudo sed -i "s/^mynetworks = .*/mynetworks = 127.0.0.0\/8 [::ffff:127.0.0.0]\/104 [::1]\/128 $(echo $ip | awk -F. '{print $1"."$2"."$3}').0\/24/" /etc/postfix/main.cf
    # Configura la entrega de correo en formato Maildir en Postfix
    echo "home_mailbox = Maildir/" | sudo tee -a /etc/postfix/main.cf
    echo "mailbox_command =" | sudo tee -a /etc/postfix/main.cf
    echo "smtpd_tls_auth_only = yes" >> /etc/postfix/main.cf
    # Habilitar la escucha en el puerto 587 (submission) para envío de correos con autenticación
    echo "submission inet n       -       n       -       -       smtpd" >> /etc/postfix/master.cf

    # Recarga y reinicia el servicio Postfix
    sudo systemctl reload postfix
    sudo systemctl restart postfix

    # Habilita la autenticación en texto plano en Dovecot
    sudo sed -i 's/^#disable_plaintext_auth = yes/disable_plaintext_auth = no/' /etc/dovecot/conf.d/10-auth.conf

    # Configura el formato de almacenamiento de correo en Dovecot
    sudo sed -i 's/^#   mail_location = maildir:~\/Maildir/    mail_location = maildir:~\/Maildir/' /etc/dovecot/conf.d/10-mail.conf
    sudo sed -i 's/^mail_location = mbox:~\/mail:INBOX=\/var\/mail\/%u/#mail_location = mbox:~\/mail:INBOX=\/var\/mail\/%u/' /etc/dovecot/conf.d/10-mail.conf

    # Reinicia el servicio Dovecot
    sudo systemctl restart dovecot

    # Agrega registros de correo y reinicia BIND9
    echo "$dominio  IN  MX  10  correo.$dominio." | sudo tee -a /etc/bind/db.$dominio
    echo "pop3 IN  CNAME   servidor" | sudo tee -a /etc/bind/db.$dominio
    echo "smtp IN  CNAME   servidor" | sudo tee -a /etc/bind/db.$dominio
    sudo systemctl restart bind9

    #Abrir puertos
    sudo ufw allow 25/tcp
    sudo ufw allow 110/tcp
    sudo ufw allow 143/tcp
    sudo ufw allow 587/tcp
    sudo ufw allow 53/tcp
    sudo ufw allow 53/udp
    sudo ufw allow 80/tcp
    sudo ufw reload


    sudo apt install unzip -y

    # Establecer rutas para los directorios de datos y archivos adjuntos
    data_directory="/var/www/html/squirrelmail/data/"
    attach_directory="/var/www/html/squirrelmail/attach/"

    # Ruta de instalación de SquirrelMail
    install_dir="/var/www/html/squirrelmail"

    cd /var/www/html/
    wget https://sourceforge.net/projects/squirrelmail/files/stable/1.4.22/squirrelmail-webmail-1.4.22.zip
    unzip squirrelmail-webmail-1.4.22.zip
    sudo mv squirrelmail-webmail-1.4.22 squirrelmail
    sudo chown -R www-data:www-data "$install_dir/"
    sudo chmod 755 -R "$install_dir/"

    # Modificar conf.pl para usar tu dominio y las rutas especificadas
    sudo sed -i "s/^\$domain.*/\$domain = '$dominio';/" $install_dir/config/config_default.php
    sudo sed -i "s|^\$data_dir.*| \$data_dir = '$data_directory';|" $install_dir/config/config_default.php
    sudo sed -i "s|^\$attachment_dir.*| \$attachment_dir = '$attach_directory';|" $install_dir/config/config_default.php
    sudo sed -i "s/^\$allow_server_sort.*/\$allow_server_sort = true;/" $install_dir/config/config_default.php

    echo -e "s\n\nq" | perl $install_dir/config/conf.pl

    # Reiniciar Apache para aplicar cambios
    sudo systemctl reload apache2
    sudo systemctl restart apache2

    echo "Instalación de SquirrelMail completada con configuración personalizada."
}

# funciones/bash/entrada/solicitar_user.sh


solicitar_user(){
    while true; do
        read username
        [[ -z "$username" ]] && return

        if validar_user "$username"; then
            if validar_user_existente "$username"; then
                echo "$username"
                return
            else 
                 echo "Error: El usuario '$username' ya existe en el sistema." >&2
            fi
        else
            echo "Error: El nombre de usuario no tiene un formato válido" >&2
        fi   
    done
}

# funciones/bash/validacion/validar_user.sh

validar_user(){
    local user="$1"
    if [[ ! "$user" =~ ^[a-zA-Z0-9_]{3,16}$ ]]; then 
        return 1
    fi
    return 0
}

validar_user_existente(){
    if id "$1" &>/dev/null; then
        return 1
    fi
    return 0
}




# Verificar si el script se ejecuta como root
if [[ $EUID -ne 0 ]]; then
    echo "Este script debe ejecutarse como root"
    exit 1
fi

echo " === SERVIDOR DE CORREO === "
sudo apt update
# Configurar servidor DNS 
echo "Configurando servidor DNS en paulook.com...."
ip_fija="192.168.171.132"
dominio="alecloud.com"

conf_dns "$ip_fija" "$dominio"

# Establecemos el nombre de host del sistema, es decir, nuestro servidor DN
sudo hostnamectl set-hostname "$dominio"

# Verifica antes de instalar Apache
if ! verificar_servicio "apache2"; then
    conf_correo
else
    echo "Servicio de correo ya configurado."
fi


# Muestra el nombre de correo configurado en el sistema
cat /etc/mailname

while true; do
    echo "=== MENU PRINCIPAL ==="
    echo "1. Crear usuario"
    echo "2. Salir"
    read -p "Elija la opción que desea realizar (1-2): " opc

    if [ "$opc" -eq 1 ]; then
        echo "Ingresa el nombre de usuario:"
        user=$(solicitar_user)
        crear_user "$user" 
    elif [ "$opc" -eq 2 ]; then
        echo "Saliendo..."
        exit 0
    else
        echo "Opción no válida. Intente de nuevo."
    fi
done


