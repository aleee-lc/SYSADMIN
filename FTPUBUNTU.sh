#!/bin/bash

# Función para instalar y configurar vsftpd
instalar_vsftpd() {
    echo "Instalando vsftpd..."
    apt update && apt install -y vsftpd
    
    echo "Configurando vsftpd..."
    cat <<EOF > /etc/vsftpd.conf
listen=YES
anonymous_enable=YES
local_enable=YES
write_enable=YES
anon_upload_enable=NO
anon_mkdir_write_enable=NO
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
allow_writeable_chroot=YES
local_root=/srv/ftp
user_sub_token=\$USER
local_umask=022
anon_root=/srv/ftp/publico

# Desactivar TLS para permitir conexiones simples desde FileZilla
ssl_enable=NO

# Configuración pasiva para evitar problemas con NAT y Firewalls
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000
EOF

    systemctl restart vsftpd
    systemctl enable vsftpd
    echo "vsftpd instalado y configurado correctamente."
}

# Función para configurar las carpetas y permisos
configurar_permisos() {
    echo "Configurando carpetas y permisos..."
    
    # Crear carpetas principales
    mkdir -p /srv/ftp/{publico,reprobados,recursadores}

    # Crear grupos
    groupadd reprobados 2>/dev/null
    groupadd recursadores 2>/dev/null

    # Asignar permisos
    chmod 755 /srv/ftp
    chmod 777 /srv/ftp/publico
    chmod 770 /srv/ftp/reprobados
    chmod 770 /srv/ftp/recursadores
    chown root:root /srv/ftp
    chown root:reprobados /srv/ftp/reprobados
    chown root:recursadores /srv/ftp/recursadores
    chown nobody:nogroup /srv/ftp/publico

    echo "Permisos configurados correctamente."
}

# Función para crear un nuevo usuario
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

    useradd -m -d /srv/ftp/$usuario -s /usr/sbin/nologin -g $grupo $usuario
    passwd $usuario
    chmod 750 /srv/ftp/$usuario
    chown $usuario:$grupo /srv/ftp/$usuario

    echo "Usuario $usuario creado en el grupo $grupo."
}

# Función para modificar un usuario
modificar_usuario() {
    read -p "Ingrese el nombre del usuario a modificar: " usuario
    if ! id "$usuario" &>/dev/null; then
        echo "El usuario no existe."
        return
    fi

    read -p "Nuevo grupo (reprobados/recursadores): " grupo
    if [[ "$grupo" != "reprobados" && "$grupo" != "recursadores" ]]; then
        echo "Grupo inválido."
        return
    fi

    usermod -g $grupo $usuario
    echo "Usuario $usuario cambiado al grupo $grupo."
}

# Función para eliminar un usuario
eliminar_usuario() {
    read -p "Ingrese el nombre del usuario a eliminar: " usuario
    if ! id "$usuario" &>/dev/null; then
        echo "El usuario no existe."
        return
    fi

    userdel -r $usuario
    echo "Usuario $usuario eliminado."
}

# Función para gestionar usuarios
gestionar_usuarios() {
    while true; do
        echo -e "\n--- Gestión de Usuarios ---"
        echo "1) Crear usuario"
        echo "2) Modificar usuario"
        echo "3) Eliminar usuario"
        echo "4) Salir"
        read -p "Seleccione una opción: " opcion

        case $opcion in
            1) crear_usuario ;;
            2) modificar_usuario ;;
            3) eliminar_usuario ;;
            4) break ;;
            *) echo "Opción inválida." ;;
        esac
    done
}

# Función principal
main() {
    instalar_vsftpd
    configurar_permisos
    gestionar_usuarios
}

main
