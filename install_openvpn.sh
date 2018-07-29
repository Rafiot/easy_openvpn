#!/bin/bash

set -e
set -x

# Inspired by https://www.digitalocean.com/community/tutorials/how-to-set-up-an-openvpn-server-on-ubuntu-18-04

if [ -z "$1" ]
  then
    echo "Hostname was expected, breaking."
    exit 1
fi

if [ -z "$2" ]
  then
    echo "HTTP Basic auth password was expected, breaking."
    exit 1
else
    echo $2 > basic_auth_pass
fi

if [ ! -f ./ovh_api.conf ]; then
    echo "OVH config file not found, breaking."
    exit 1
fi

# Prepare certbot stuff
sudo apt -y update
sudo apt -y install software-properties-common
sudo add-apt-repository -y ppa:certbot/certbot
# Install stuff
sudo apt -y update
sudo apt -y dist-upgrade
sudo apt -y install openssl openvpn nginx python3-pip python3-venv certbot python-certbot-nginx haveged apache2-utils
# Install ovh dns module
sudo pip3 install certbot-dns-ovh

# Create SSL certificate
sudo mkdir -p /etc/nginx/ovh_creds
sudo mv ovh_api.conf /etc/nginx/ovh_creds/
sudo chmod 600 /etc/nginx/ovh_creds/ovh_api.conf

sudo certbot certonly --dns-ovh --dns-ovh-credentials /etc/nginx/ovh_creds/ovh_api.conf -d ${1}

# Create Basic Auth file
sudo htpasswd -c -b /etc/nginx/.htpasswd openvpn ${2}

python3 -m venv venv
source venv/bin/activate

if [ -z "${VIRTUAL_ENV}" ]
  then
    echo "You have to run it from the virtual environment."
    exit 1
fi

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
sed -i "s:SOCK_PATH:`pwd`/easy_openvpn.sock:g" etc/nginx/sites-available/easy_openvpn
sed -i "s:REPO_DIR:`pwd`:g" etc/systemd/system/easy_openvpn.service
sed -i "s:VIRTUAL_ENV:${VIRTUAL_ENV}:g" etc/systemd/system/easy_openvpn.service

pip install -U pip
hash -r
pip install -U -r requirements.txt

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
sudo cp server443.conf /etc/openvpn/
# sudo ln -s server53.conf /etc/openvpn/
sudo cp server80.conf /etc/openvpn/

# Nginx


if [ -f /etc/nginx/sites-enabled/default ]; then
    sudo rm /etc/nginx/sites-enabled/default
fi
sudo cp etc/nginx/sites-available/easy_openvpn /etc/nginx/sites-available/
if [ ! -e /etc/nginx/sites-enabled/easy_openvpn ]; then
    sudo ln -s /etc/nginx/sites-available/easy_openvpn /etc/nginx/sites-enabled/
fi
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
sudo ufw allow 31337  # web interface
# ufw allow 53/udp
sudo ufw default allow FORWARD

sudo cp before.rules /etc/ufw/before.rules

sudo ufw disable
sudo ufw --force enable

# Perms

chown -R www-data:www-data ./
# In the default installer, the clone takes place in /root, we need to let www-data enter in the directory.
chmod go+rx ../

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
