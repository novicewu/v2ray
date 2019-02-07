#!/bin/bash
# Install Nginx
apt-get update
apt-get install nginx -y
mkdir -p /etc/nginx/ssl
openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048

echo && read -e -p "请输入域名: " web1
echo && read -e -p "请输入要反向代理的网址: " web2

echo -e "server
    {
        listen 80;
        #listen [::]:80;
        server_name $web1 ;
        return 301 https://$web1\$request_uri;
	}
server
    {
        listen 443 ssl http2;
        #listen [::]:443 ssl http2;
        server_name $web1 ;
        ssl on;
        ssl_certificate /etc/nginx/ssl/$web1/fullchain.cer;
        ssl_certificate_key /etc/nginx/ssl/$web1/privkey.key;
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
	proxy_pass https://$web2/;
    sub_filter '$web2' '$web1';
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
    }" >/etc/nginx/sites-enabled/apia.ga.conf

# Iinstall acme.sh

apt-get install socat -y
apt-get install curl -y
curl https://get.acme.sh | sh
cd /root/.acme.sh

# Apply for Cert
./acme.sh  --issue  -d $web1  --alpn

# Install Certificate
mkdir -p /etc/nginx/ssl/$web1
./acme.sh --install-cert -d $web1 \
--key-file       /etc/nginx/ssl/$web1/privkey.key  \
--fullchain-file /etc/nginx/ssl/$web1/fullchain.cer \
--reloadcmd     "service nginx force-reload"

# Install V2ray

bash <(curl -L -s https://install.direct/go.sh)
uuid=$(cat /proc/sys/kernel/random/uuid)

echo -e "{
    \"log\": {
                \"access\": \"/var/log/v2ray/access.log\",
                \"error\": \"/var/log/v2ray/error.log\",
        \"loglevel\": \"info\"
    },
    \"inbound\": {
        \"port\": 10000,
        \"protocol\": \"vmess\",
        \"allocate\": {
            \"strategy\": \"always\"
        },
        \"settings\": {
            \"clients\": [{
                \"id\": \"$uuid\",
                \"level\": 1,
                \"alterId\": 64,
            }]
        },
        \"streamSettings\": {
            \"network\": \"ws\",
            }
        \"sniffing\": {
                \"enabled\": true,
                \"destOverride\": [
                        \"http\",
                        \"tls\"
                ]
        }

    },
    \"outbound\": {
        \"protocol\": \"freedom\",
        \"settings\": {}
    },
    \"outboundDetour\": [{
        \"protocol\": \"blackhole\",
        \"settings\": {},
        \"tag\": \"blocked\"
    }],
    \"routing\": {
        \"strategy\": \"rules\",
        \"settings\": {
            \"rules\": [{
                \"type\": \"field\",
                \"ip\": [\"geoip:private\"],
                \"outboundTag\": \"blocked\"
            }]
        }
    }
}" >/etc/v2ray/config.json

