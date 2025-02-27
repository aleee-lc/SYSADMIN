sudo apt update
apt install openssh-server -y
systemctl status ssh
ufw allow OpenSSH
ufw enable
systemctl restart ssh
systemctl status ssh
