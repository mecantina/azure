#!/bin/bash

LOG=/home/wordpressadmin/install-wp.log
echo "$(date '+%Y-%m-%d %H:%M:%S') Starting WordPress installation script..." > $LOG

echo "$(date '+%Y-%m-%d %H:%M:%S')   Updating system..." >> $LOG
sudo apt-get -y update
echo "$(date '+%Y-%m-%d %H:%M:%S')   Installing packages..." >> $LOG
sudo apt-get -y install apache2 \
                 ghostscript \
                 libapache2-mod-php \
                 mysql-server \
                 mysql-client \
                 php \
                 php-bcmath \
                 php-curl \
                 php-imagick \
                 php-intl \
                 php-json \
                 php-mbstring \
                 php-mysql \
                 php-xml \
                 php-zip

echo "$(date '+%Y-%m-%d %H:%M:%S')   Enabling mysql..." >> $LOG
sudo service mysql enable
echo "$(date '+%Y-%m-%d %H:%M:%S')   Starting mysql..." >> $LOG
sudo service mysql start

if [ ! -f /srv/www/wordpress/index.php ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S')   Fetching Wordpress..." >> $LOG
    sudo mkdir -p /srv/www
    sudo chown www-data: /srv/www
    curl https://wordpress.org/latest.tar.gz | sudo -u www-data tar zx -C /srv/www
fi

# Create the Apache virtual host configuration file for WordPress
if [ ! -f /etc/apache2/sites-available/wordpress.conf ]; then
echo "$(date '+%Y-%m-%d %H:%M:%S')   Configuring Wordpress..." >> $LOG 
    sudo tee /etc/apache2/sites-available/wordpress.conf > /dev/null <<'EOF'
<VirtualHost *:80>
    DocumentRoot /srv/www/wordpress
    <Directory /srv/www/wordpress>
        Options FollowSymLinks
        AllowOverride Limit Options FileInfo
        DirectoryIndex index.php
        Require all granted
    </Directory>
    <Directory /srv/www/wordpress/wp-content>
        Options FollowSymLinks
        Require all granted
    </Directory>
</VirtualHost>
EOF


    # Enable the WordPress site
    sudo a2ensite wordpress

    # Enable URL rewriting 
    sudo a2enmod rewrite

    # Disable the default Apache site (optional)
    sudo a2dissite 000-default

    # Reload Apache to apply the changes
    sudo systemctl reload apache2
fi

# Create a random password for the MySQL root user 
if [ ! -f /home/wordpressadmin/.mysql_wp_password ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S')   Configuring MySQL..." >> $LOG
    touch /home/wordpressadmin/.mysql_wp_password
    chmod 600 /home/wordpressadmin/.mysql_wp_password

    MYSQL_WP_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 12)
    echo $MYSQL_WP_PASSWORD >/home/wordpressadmin/.mysql_wp_password

    # Set up MySQL database and user for WordPress
    ls /usr/bin/mysql -alth >> $LOG 2>&1
    sudo /usr/bin/mysql -u root -e "CREATE DATABASE wordpress;" >> $LOG 2>&1
    sudo /usr/bin/mysql -u root -e "CREATE USER 'wordpress'@'localhost' IDENTIFIED BY '$MYSQL_WP_PASSWORD';" >> $LOG 2>&1
    sudo /usr/bin/mysql -u root -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost';" >> $LOG 2>&1
    sudo /usr/bin/mysql -u root -e "FLUSH PRIVILEGES;" >> $LOG 2>&1
fi

# Configure WordPress to connect to the MySQL database
if [ ! -f /srv/www/wordpress/wp-config.php ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S')   Configuring WordPress MySQL connection..." >> $LOG
    sudo -u www-data cp /srv/www/wordpress/wp-config-sample.php /srv/www/wordpress/wp-config.php

    sudo -u www-data sed -i 's/database_name_here/wordpress/' /srv/www/wordpress/wp-config.php
    sudo -u www-data sed -i 's/username_here/wordpress/' /srv/www/wordpress/wp-config.php
    sudo -u www-data sed -i "s|password_here|$MYSQL_WP_PASSWORD|" /srv/www/wordpress/wp-config.php

fi

# Install WordPress CLI if not already installed
if [ ! -f /usr/local/bin/wp ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S')   Installing WP-CLI..." >> $LOG
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    sudo mv wp-cli.phar /usr/local/bin/wp
fi

# Create a random password for the WordPress admin user
if [ ! -f /home/wordpressadmin/.wp_admin_password ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S')   Configuring WordPress admin user..." >> $LOG
    touch /home/wordpressadmin/.wp_admin_password
    chmod 600 /home/wordpressadmin/.wp_admin_password

    WP_ADMIN_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 12)
    echo $WP_ADMIN_PASSWORD >/home/wordpressadmin/.wp_admin_password
fi

# Give the wordpressadmin user ownership of the MySQL and WordPress password files
sudo chown wordpressadmin:wordpressadmin /home/wordpressadmin/.mysql_wp_password
sudo chown wordpressadmin:wordpressadmin /home/wordpressadmin/.wp_admin_password

#wp core install --url=/ --title="Green Market Business" --admin_user=admin --admin_password="$WP_ADMIN_PASSWORD" --admin_email=hakon.klausen@aenergi.no --path=/srv/www/wordpress