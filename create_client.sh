#!/bin/bash

set -e
set -x

if [ -z "$1" ]
  then
    echo "Client name was expected, breaking."
    exit 1
fi

EASYRSA=3.0.4

pushd EasyRSA-${EASYRSA}
./easyrsa --batch gen-req ${1} nopass
./easyrsa --batch --req-cn=${1} sign-req client ${1}
popd

KEY_DIR=./client-configs/keys/

cp EasyRSA-${EASYRSA}/pki/private/${1}.key ${KEY_DIR}
cp EasyRSA-${EASYRSA}/pki/issued/${1}.crt ${KEY_DIR}
cp EasyRSA-${EASYRSA}/ta.key ${KEY_DIR}
sudo cp /etc/openvpn/ca.crt ${KEY_DIR}


OUTPUT_DIR=./client-configs/files
BASE_CONFIG_443=./client-configs/base443.conf
BASE_CONFIG_80=./client-configs/base80.conf
BASE_CONFIG_53=./client-configs/base53.conf


cat ${BASE_CONFIG_443} \
    <(echo -e '<ca>') \
    ${KEY_DIR}/ca.crt \
    <(echo -e '</ca>\n<cert>') \
    ${KEY_DIR}/${1}.crt \
    <(echo -e '</cert>\n<key>') \
    ${KEY_DIR}/${1}.key \
    <(echo -e '</key>\n<tls-auth>') \
    ${KEY_DIR}/ta.key \
    <(echo -e '</tls-auth>') \
    > ${OUTPUT_DIR}/${1}_443.ovpn

cat ${BASE_CONFIG_80} \
    <(echo -e '<ca>') \
    ${KEY_DIR}/ca.crt \
    <(echo -e '</ca>\n<cert>') \
    ${KEY_DIR}/${1}.crt \
    <(echo -e '</cert>\n<key>') \
    ${KEY_DIR}/${1}.key \
    <(echo -e '</key>\n<tls-auth>') \
    ${KEY_DIR}/ta.key \
    <(echo -e '</tls-auth>') \
    > ${OUTPUT_DIR}/${1}_80.ovpn

cat ${BASE_CONFIG_53} \
    <(echo -e '<ca>') \
    ${KEY_DIR}/ca.crt \
    <(echo -e '</ca>\n<cert>') \
    ${KEY_DIR}/${1}.crt \
    <(echo -e '</cert>\n<key>') \
    ${KEY_DIR}/${1}.key \
    <(echo -e '</key>\n<tls-auth>') \
    ${KEY_DIR}/ta.key \
    <(echo -e '</tls-auth>') \
    > ${OUTPUT_DIR}/${1}_53.ovpn
