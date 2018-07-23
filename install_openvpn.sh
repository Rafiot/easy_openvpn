#!/bin/bash

set -e
set -x

# Inspired by https://www.digitalocean.com/community/tutorials/how-to-set-up-an-openvpn-server-on-ubuntu-18-04

if [ -z "$1" ]
  then
    echo "Hostname was expected, breaking."
    exit 1
fi

if [ -z "${VIRTUAL_ENV}" ]
  then
    echo "You have to run it from the virtual environment."
    exit 1
fi


sudo apt -y update
sudo apt -y dist-upgrade
sudo apt -y install openvpn nginx python3-pip certbot python-certbot-nginx

EASYRSA=3.0.4

echo 'Get easy-rsa v'${EASYRSA}

wget https://github.com/OpenVPN/easy-rsa/releases/download/v${EASYRSA}/EasyRSA-${EASYRSA}.tgz
tar xvf EasyRSA-${EASYRSA}.tgz

echo 'Copy default vars'
cp vars ./EasyRSA-${EASYRSA}/

pushd EasyRSA-${EASYRSA}

echo 'Initiate the public key infrastructure'

./easyrsa --batch init-pki
./easyrsa --batch build-ca nopass

./easyrsa --batch --req-cn=server gen-req server nopass
./easyrsa --batch --req-cn=server sign-req server server

./easyrsa --batch gen-dh

openvpn --genkey --secret ta.key

popd

mkdir -p client-configs/keys
chmod -R 700 client-configs

# Prepare config files

sed -i "s/SET_HOSTNAME/${1}/g" client-configs/base*.conf
sed -i "s/SET_HOSTNAME/${1}/g" etc/nginx/sites-available/easy_openvpn
sed -i "s:SOCK_PATH:`pwd`:g" etc/nginx/sites-available/easy_openvpn
sed -i "s:REPO_DIR:`pwd`:g" etc/systemd/system/easy_openvpn.service
sed -i "s:VIRTUAL_ENV:${VIRTUAL_ENV}:g" etc/systemd/system/easy_openvpn.service

####### Requires root #############

pushd EasyRSA-${EASYRSA}
echo 'Copy the PKI stuff'
sudo cp pki/private/server.key /etc/openvpn/
sudo cp pki/issued/server.crt /etc/openvpn/
sudo cp pki/ca.crt /etc/openvpn/
sudo cp ta.key /etc/openvpn/
sudo cp pki/dh.pem /etc/openvpn/
popd

##### Link config files #####

# OpenVPN
sudo ln -s server443.conf /etc/openvpn/
# sudo ln -s server53.conf /etc/openvpn/
sudo ln -s server80.conf /etc/openvpn/

# Nginx

sudo ln -s etc/nginx/sites-available/easy_openvpn /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo cp etc/systemd/system/easy_openvpn.service /etc/systemd/system/

# Networking foo

sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sudo sed -i 's/#net.ipv6.conf.all.forwarding=1/net.ipv6.conf.all.forwarding=1/g' /etc/sysctl.conf
sudo sysctl -p

# Firewall

sudo ufw allow OpenSSH

# Open VPN on 443, 80 and 53 (later)
sudo ufw allow https
sudo ufw allow http
# ufw allow 53/udp
sudo ufw default allow FORWARD

sudo cp before.rules /etc/ufw/before.rules

sudo ufw disable
sudo ufw --force enable

###### Systemd thingies ######

# OpenVPN

sudo systemctl start openvpn@server443
sudo systemctl start openvpn@server80
#sudo systemctl start openvpn@server53
sudo systemctl enable openvpn@server443
sudo systemctl enable openvpn@server80
#sudo systemctl enable openvpn@server53

# Web
sudo systemctl start easy_openvpn
sudo systemctl enable easy_openvpn
sudo service nginx restart
