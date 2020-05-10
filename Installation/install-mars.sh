sudo adduser jeedom
#installation de clés SSH : ex pour gérer à distance (user jeedom, ip = 192.168.0.15)
ssh-keygen -t rsa
(enter pour ne pas créer de passphrase)

#Editez ensuite le fichier sudoers :   visudo
  #puis modifier le fichier comme suit :
  # User privilege specification
  #  root ALL=(ALL:ALL) ALL
  #   pluginblea ALL=(ALL) NOPASSWD: ALL
  # Allow members of group sudo to execute any command
  #   %sudo ALL=(ALL) NOPASSWD: ALL

  # add the ssh public key
  #su - ${username} -c "umask 022 ; mkdir .ssh ; echo $SSH_PUBLIC_KEY >> .ssh/authorised_keys"

sur le serveur jeedom
cd /home/www-data/.ssh
ssh-copy-id -i sshkey.pub jeedom@192.168.0.15