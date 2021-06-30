#!/bin/bash

if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Error: docker-compose 未安装.' >&2
  exit 1
fi

read -p "请输入域名(必填):" domain
if [ "$domain" == "" ]; then
    echo '请输入域名' >&2
    exit 1
fi

read -p "请输入v2ray uuid(必填):" uuid
if [ "$uuid" == "" ]; then
    echo '请输入v2ray uuid' >&2
    exit 1
fi

read -p "请输入v2ray path(默认 /current/user):" v2ray_path
if [ "$v2ray_path" == "" ]; then
    v2ray_path="/current/user"
fi

read -p "请输入邮箱(选填):" email

/bin/cp -f ./data/nginx-config/v2ray.conf.template ./data/nginx-config/v2ray.conf
/bin/cp -f ./data/v2ray-config/config.json.template ./data/v2ray-config/config.json

sed -i "s/{domain}/$domain/g" ./data/nginx-config/v2ray.conf
sed -i "s#{v2ray_path}#$v2ray_path#g" ./data/nginx-config/v2ray.conf
sed -i "s/{uuid}/$uuid/g" ./data/v2ray-config/config.json
sed -i "s#{v2ray_path}#$v2ray_path#g" ./data/v2ray-config/config.json

domains=($domain)
rsa_key_size=4096
data_path="./data/certbot"
staging=0 # Set to 1 if you're testing your setup to avoid hitting request limits


if [ -d "$data_path" ]; then
  read -p "$domains 证书文件已存在. 是否覆盖? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit
  fi
fi


if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  echo "### Downloading recommended TLS parameters ..."
  mkdir -p "$data_path/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$data_path/conf/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$data_path/conf/ssl-dhparams.pem"
  echo
fi

echo "### Creating dummy certificate for $domains ..."
path="/etc/letsencrypt/live/$domains"
mkdir -p "$data_path/conf/live/$domains"
docker-compose run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:1024 -days 1\
    -keyout '$path/privkey.pem' \
    -out '$path/fullchain.pem' \
    -subj '/CN=localhost'" certbot
echo


echo "### Starting nginx ..."
docker-compose up --force-recreate -d nginx
echo

echo "### Deleting dummy certificate for $domains ..."
docker-compose run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/$domains && \
  rm -Rf /etc/letsencrypt/archive/$domains && \
  rm -Rf /etc/letsencrypt/renewal/$domains.conf" certbot
echo


echo "### Requesting Let's Encrypt certificate for $domains ..."
#Join $domains to -d args
domain_args=""
for domain in "${domains[@]}"; do
  domain_args="$domain_args -d $domain"
done

# Select appropriate email arg
case "$email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email" ;;
esac

# Enable staging mode if needed
if [ $staging != "0" ]; then staging_arg="--staging"; fi

docker-compose run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $email_arg \
    $domain_args \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal" certbot
echo

echo "### Reloading nginx ..."
docker-compose exec nginx nginx -s reload
docker-compose up -d certbot
