
# Install Nginx
apt-get update
apt-get install nginx -y
mkdir -p /etc/nginx/ssl
openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048
nano /etc/nginx/sites-enabled/apia.ga.conf

server
    {
        listen 80;
        #listen [::]:80;
        server_name apia.ga ;
        return 301 https://apia.ga$request_uri;
	}
server
    {
        listen 443 ssl http2;
        #listen [::]:443 ssl http2;
        server_name apia.ga ;
        ssl on;
        ssl_certificate /etc/nginx/ssl/apia.ga/fullchain.cer;
        ssl_certificate_key /etc/nginx/ssl/apia.ga/privkey.key;
        ssl_session_timeout 5m;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        ssl_prefer_server_ciphers on;
        ssl_ciphers "EECDH+CHACHA20:EECDH+CHACHA20-draft:EECDH+AES128:RSA+AES128:EECDH+AES256:RSA+AES256:EECDH+3DES:RSA+3DES:!MD5";
        ssl_session_cache builtin:1000 shared:SSL:10m;
        # openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048
        ssl_dhparam /etc/nginx/ssl/dhparam.pem;
	access_log off;
	location / {
	proxy_set_header X-Real-IP $remote_addr;
	proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
	proxy_pass https://acca.ga/;
  sub_filter 'acca.ga' 'apia.ga';
	location /phpmyadmin/ {
          proxy_redirect off;
          #proxy_pass http://127.0.0.1:10000;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
          proxy_set_header Host $http_host;
          proxy_intercept_errors on;
          if ($http_upgrade = "websocket" ){
             proxy_pass http://127.0.0.1:10000;
          }
        }
        }
    }

Install acme.sh
apt-get install socat -y
apt-get install curl -y
curl  https://get.acme.sh | sh
cd /root/.acme.sh

Apply for Cert
acme.sh  --issue  -d apia.ga  --alpn

mkdir -p /etc/nginx/ssl/apia.ga

acme.sh --install-cert -d apia.ga \
--key-file       /etc/nginx/ssl/apia.ga/privkey.key  \
--fullchain-file /etc/nginx/ssl/apia.ga/fullchain.cer \
--reloadcmd     "service nginx force-reload"

Install V2ray

bash <(curl -L -s https://install.direct/go.sh)
nano /etc/v2ray/config.json

{
    "log": {
                "access": "/var/log/v2ray/access.log",
                "error": "/var/log/v2ray/error.log",
        "loglevel": "info"
    },
    "inbound": {
        "port": 10000,
        "protocol": "vmess",
        "allocate": {
            "strategy": "always"
        },
        "settings": {
            "clients": [{
                "id": "3418aa46-e233-48fc-8468-b3ec7e98bb52",
                "level": 1,
                "alterId": 64,
            }]
        },
        "streamSettings": {
            "network": "ws",
            }
        "sniffing": {
                "enabled": true,
                "destOverride": [
                        "http",
                        "tls"
                ]
        }

    },
    "outbound": {
        "protocol": "freedom",
        "settings": {}
    },
    "outboundDetour": [{
        "protocol": "blackhole",
        "settings": {},
        "tag": "blocked"
    }],
    "routing": {
        "strategy": "rules",
        "settings": {
            "rules": [{
                "type": "field",
                "ip": ["geoip:private"],
                "outboundTag": "blocked"
            }]
        }
    }
}

Replace the ID with below Website
https://www.uuidgenerator.net/