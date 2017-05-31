#!/bin/bash

#install webserver
cd
rm /etc/nginx/sites-enabled/default
rm /etc/nginx/sites-available/default
wget -O /etc/nginx/nginx.conf http://raw.github.com/y/debian7/nginx.conf
mkdir -p /home/vps/public_html
echo "<pre>Modified by MuLuu09 atau (+601131731782)</pre>" > /home/vps/public_html/index.html
echo "<?php phpinfo(); ?>" > /home/vps/public_html/info.php
wget -O /etc/nginx/conf.d/vps.conf http://raw.github.com/y/debian7/vps.conf
sed -i 's/listen = \/var\/run\/php5-fpm.sock/listen = 127.0.0.1:9000/g' /etc/php5/fpm/pool.d/www.conf
service php5-fpm restart
service nginx restart

#configure openvpn client config
cd /etc/openvpn/
wget -O /etc/openvpn/z7.sh http://raw.github.com/y/debian7/1194-client.conf

cp /etc/openvpn/z7.sh /home/vps/public_html/z7.sh
sed -i $myip2 /home/vps/public_html/z7.sh
sed -i "s/ports/55/" /home/vps/public_html/z7.sh
