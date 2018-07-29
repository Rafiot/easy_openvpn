# easy_openvpn
Just a bunch of script to setup an openvpn server. May have a flask web interface soon-ish.

# Pre-requisite

1. Have a domain at OVH (it uses the OVH API to do the letsencrypt DNS challenge)
2. Configure your DNS to point to your machine
3. Get the OVh API dev keys => https://certbot-dns-ovh.readthedocs.io/en/stable/

# Install

0. SSH to your server

```bash
git clone https://github.com/Rafiot/easy_openvpn.git
cd easy_openvpn
# Set your OVH API keys in ovh_api.conf.example (look at ovh_api.conf.example)
./install_openvpn.sh <domain.configured.earlier> <HTTP Basic Auth Password>
```

# Usage

1. Go to `https://<domain.configured.earlier>:31337`
2. Enter your HTTP Basic Auth password (user is `openvpn`)
3. Get your config file

