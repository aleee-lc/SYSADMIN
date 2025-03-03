#!/bin/bash

# Función para instalar y configurar vsftpd
instalar_vsftpd() {
    echo "Instalando vsftpd..."
    apt update && apt install -y vsftpd ufw

    echo "Configurando vsftpd..."
    cat <<EOF > /etc/vsftpd.conf
listen=YES
anonymous_enable=YES
local_enable=YES
write_enable=YES
chroot_local_user=YES
allow_writeable_chroot=YES
local_umask=022
anon_root=/srv/ftp/publico
use_localtime=YES
dirmessage_enable=YES
xferlog_enable=YES

# Permitir solo lectura para usuarios anónimos
anon_world_readable_only=YES
anon_upload_enable=NO
anon_mkdir_write_enable=NO
anon_other_write_enable=NO

# Desactivar TLS para permitir conexiones simples desde FileZilla
ssl_enable=NO

# Permitir conexiones pasivas para evitar problemas con NAT/Firewall
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000

# Permitir autenticación PAM
pam_service_name=vsftpd
EOF

    systemctl restart vsftpd
    systemctl enable vsftpd
    echo "vsftpd instalado y configurado correctamente."
}

# Función para configurar autenticación PAM
configurar_pam() {
    echo "Configurando autenticación PAM para vsftpd..."
    cat <<EOF > /etc/pam.d/vsftpd
auth    required    pam_unix.so
account required    pam_unix.so
session required    pam_unix.so
EOF
}

# Función para configurar firewall UFW
configurar_ufw() {
    echo "Configurando firewall UFW..."
    ufw allow 21/tcp
    ufw allow 40000:50000/tcp
    ufw reload
    echo "Reglas de firewall aplicadas correctamente."
}

# Función para configurar carpetas y permisos
configurar_permisos() {
    echo "Configurando carpetas y permisos..."

    # Crear carpetas principales
    mkdir -p /srv/ftp/{publico,reprobados,recursadores}

    # Crear grupos
    groupadd reprobados 2>/dev/null
    groupadd recursadores 2>/dev/null

    # Asignar permisos
    chmod 755 /srv/ftp
    chmod 755 /srv/ftp/publico  # Permite solo lectura a anónimos
    chmod 770 /srv/ftp/reprobados
    chmod 770 /srv/ftp/recursadores
    chown root:root /srv/ftp
    chown root:reprobados /srv/ftp/reprobados
    chown root:recursadores /srv/ftp/recursadores
    chown nobody:nogroup /srv/ftp/publico

    echo "Permisos configurados correctamente."
}

# Función para crear un nuevo usuario con enlaces de grupo y público
crear_usuario() {
    read -p "Ingrese el nombre de usuario: " usuario
    if id "$usuario" &>/dev/null; then
        echo "El usuario ya existe."
        return
    fi

    read -p "Seleccione grupo (reprobados/recursadores): " grupo
    if [[ "$grupo" != "reprobados" && "$grupo" != "recursadores" ]]; then
        echo "Grupo inválido."
        return
    fi

    # Crear usuario con su carpeta
    useradd -m -d /srv/ftp/$usuario -s /bin/false -g $grupo $usuario
    passwd $usuario
    chmod 750 /srv/ftp/$usuario
    chown $usuario:$grupo /srv/ftp/$usuario

    # Asegurar que el usuario no está en la lista de bloqueados
    sed -i "/^$usuario$/d" /etc/ftpusers

    # Crear subcarpeta dentro del usuario
    mkdir -p /srv/ftp/$usuario/home
    chown $usuario:$grupo /srv/ftp/$usuario/home

    # Crear enlaces a su carpeta real, grupo y público
    mkdir -p /srv/ftp/$usuario/home/{mis_archivos,grupo,publico}
    mount --bind /srv/ftp/$usuario /srv/ftp/$usuario/home/mis_archivos
    mount --bind /srv/ftp/$grupo /srv/ftp/$usuario/home/grupo
    mount --bind /srv/ftp/publico /srv/ftp/$usuario/home/publico

    # Agregar a fstab para que se monten automáticamente al reiniciar
    echo "/srv/ftp/$usuario /srv/ftp/$usuario/home/mis_archivos none bind 0 0" >> /etc/fstab
    echo "/srv/ftp/$grupo /srv/ftp/$usuario/home/grupo none bind 0 0" >> /etc/fstab
    echo "/srv/ftp/publico /srv/ftp/$usuario/home/publico none bind 0 0" >> /etc/fstab

    echo "Usuario $usuario creado en el grupo $grupo con accesos configurados."
}

# Función para eliminar un usuario y desmontar enlaces
eliminar_usuario() {
    read -p "Ingrese el nombre del usuario a eliminar: " usuario
    if ! id "$usuario" &>/dev/null; then
        echo "El usuario no existe."
        return
    fi

    # Desmontar enlaces antes de eliminar la carpeta
    umount /srv/ftp/$usuario/home/mis_archivos 2>/dev/null
    umount /srv/ftp/$usuario/home/grupo 2>/dev/null
    umount /srv/ftp/$usuario/home/publico 2>/dev/null

    # Eliminar usuario
    userdel -r $usuario

    # Eliminar entradas en fstab
    sed -i "/srv\/ftp\/$usuario\/home\/mis_archivos/d" /etc/fstab
    sed -i "/srv\/ftp\/$usuario\/home\/grupo/d" /etc/fstab
    sed -i "/srv\/ftp\/$usuario\/home\/publico/d" /etc/fstab

    echo "Usuario $usuario eliminado."
}

# Función para gestionar usuarios
gestionar_usuarios() {
    while true; do
        echo -e "\n--- Gestión de Usuarios ---"
        echo "1) Crear usuario"
        echo "2) Eliminar usuario"
        echo "3) Salir"
        read -p "Seleccione una opción: " opcion

        case $opcion in
            1) crear_usuario ;;
            2) eliminar_usuario ;;
            3) break ;;
            *) echo "Opción inválida." ;;
        esac
    done
}

# Función principal
main() {
    instalar_vsftpd
    configurar_pam
    configurar_ufw
    configurar_permisos
    gestionar_usuarios
}

main
