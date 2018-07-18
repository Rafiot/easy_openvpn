#!/bin/bash

set -e
set -x

EASYRSA=3.0.4

pushd EasyRSA-${EASYRSA}
./easyrsa gen-req client1 nopass
./easyrsa import-req pki/reqs/client1.req client1
./easyrsa sign-req client client1
popd


cp EasyRSA-${EASYRSA}/pki/private/client1.key client-configs/keys/
cp EasyRSA-${EASYRSA}/pki/issued/client.crt client-configs/keys/
cp EasyRSA-${EASYRSA}/ta.key client-configs/keys/
sudo cp /etc/openvpn/ca.crt client-configs/keys/



