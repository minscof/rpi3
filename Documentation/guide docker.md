

sudo curl -s https://get.docker.com | bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh


sudo usermod -aG docker hermes

se déconnecter puis se reconnecter pour prendre en compte cet ajout de droit ( ou su -s hermes)

docker version


docker run hello-world

----------------
install docker compose (prérequis Mosquitto -> abandonné au profit d aedes)
sudo apt-get install libffi-dev libssl-dev python3-dev python3 python3-pip -y
sudo pip3 install docker-compose
---------------
create a common network for all containers
docker network create domotic_net

------------------
Installation de nodered  

les données permanentes  (configuration) de nodered sont gérées par un volume (plutot que directement sur le filesystem, conseil de docker)  

pour pouvoir connecter nodered à homebridge, au plugin wemo, au serveur mosquitto externe, on est obligé de passer en network_mode: host  pour que tous ces composants puissent écouter leurs ports réesau  

par défaut docker stocke les volumes /var/lib/docker/volumes  

docker volume create --name node_red_data  

docker volume ls  
pour faire un backup :  
docker cp  mynodered:/data  /your/backup/directory  

docker run -it -p 1880:1880 -p 1883:1883 -v node_red_data:/data --name nodered nodered/node-red  

detach the terminal with Ctrl-p Ctrl-q - the container will keep running in the background.  

docker start mynodered  
docker stop mynodered  


---------------
via docker compose  

créer le fichier /home/hermes/nodered/docker-compose.yaml

################################################################################
# Node-RED Stack or Compose
################################################################################
# docker stack deploy node-red --compose-file docker-compose-node-red.yml
# docker-compose -f docker-compose-node-red.yml -p myNoderedProject up
################################################################################
version: "3.7"

services:
  node-red:
    container_name: nodered
    restart: always
    image: nodered/node-red:latest
    environment:
      - TZ=Europe/Paris
  - network_mode: host
    #ports:
    #  - "1880:1880"
    #  - "1883:1883"
    #  - "1884:1884"
    #networks:
    #  - node_red_net
    volumes:
      - node_red_data:/data

volumes:
  node_red_data:

networks:
  node_red_net:



docker-compose up -d  
docker compose start  
docker compose stop  
docker compose down : remove container 


-------------

une fois nodered installé, ajouter nodered-contrib-aedes pour le serveur mqtt
puis créer simplement un flow mqtt avec le node aedes et configurer le noeud
définir le port 1884 pour les websocket sur mqtt : cela permet d utiliser un navigateur pour dialoguer avec le serveur mqtt

voir ce tuto : https://raspberry-valley.azurewebsites.net/Node-RED-on-Docker/

attention par défaut la persistence n'est pas activé (mémoire), avec mosquitto, la persistence était activée : à étudier l'impact.


----------------------------------------



voir le tuto : https://www.zigbee2mqtt.io/guide/installation/02_docker.html

voir aussi : https://sensorsiot.github.io/IOTstack/Containers/Zigbee2MQTT/

quelques différences

utilisation d'un volume docker pour les données persistantes plutôt qu'un répertoire externe nommé data dans le tuto

docker volume create --name zigbee2mqtt_data

se placer dans le répertoire où le fichier à copier se trouve
docker run --rm -v $PWD:/source -v zigbee2mqtt_data:/dest -w /source alpine cp configuration.yaml /dest


Here's a one-liner that copies myfile.txt from current directory to my_volume:
docker run --rm -v $PWD:/source -v my_volume:/dest -w /source alpine cp myfile.txt /dest


pour lire le contenu d'un volume
docker run --rm -i -v=my_volume:/tmp/myvolume busybox find /tmp/myvolume

docker run --rm -i -v=zigbee2mqtt_data:/tmp/myvolume alpine find /tmp/myvolume



docker logs zigbee2mqtt


------------------
Homebridge  

voir la doc de homebridge : https://github.com/homebridge/homebridge/wiki/Install-Homebridge-on-Docker  


créer un volume docker  
docker volume create --name homebridge_data  


docker-compose up 


depuis le 17 mai 2022, homebridge tourne obligatoirement en root, mais on ne sait pas pourquoi...
https://github.com/oznu/docker-homebridge/issues/440

version: '3'
services:
  homebridge:
    container_name: homebridge
    image: oznu/homebridge:latest
    restart: always
    network_mode: host
    #ports:
    #  - 8581:8581
    #networks:
    #  - domotic_net
    volumes:
      - homebridge_data:/homebridge
    logging:
      driver: json-file
      options:
        max-size: "10mb"
        max-file: "1"

volumes:
  homebridge_data:
    external: true

networks:
  domotic_net:
    external: true

