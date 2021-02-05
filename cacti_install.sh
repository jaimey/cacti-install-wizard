#!/bin/bash

function install_cacti () {
	## ----------------- Questions

	echo ""
	clear
	echo "Welcome to Cacti install!"
	echo ""	

	## Timezone
	echo ""
	echo "Enter your time zone"
	until [[ "$timezone" =~ ^[a-zA-Z/]+$ ]]; do
		read -rp "Default (America/Bogota): " -e -i America/Bogota timezone
	done

	# Thold
	echo ""
	echo "Would you like to install Thold"
	echo "   1) Yes"
	echo "   2) No"	
	until [[ "$thold" =~ ^[1-2]$ ]]; do
		read -rp "Select an option [1-2]: " -e -i 1 thold
	done

	## ----------------- Installation

	apt-get update
	apt-get install -y iputils-ping git cron
	apt-get install -y apache2 libapache2-mod-php rrdtool mariadb-server snmp snmpd php php-curl php-mysql libapache2-mod-php php-snmp php-xml php-mbstring php-json php-common php-gd php-gmp php-zip php-ldap 
	service apache2 start
	service mysql start

	php_version="$(php -v | head -n 1 | cut -d " "  -f 2 | cut -f1-2 -d".")" 	###Find installed version of PHP

	echo "Setting Timezone"
	echo "date.timezone =" "$timezone" >> /etc/php/"$php_version"/cli/php.ini 
	echo "date.timezone =" "$timezone" >> /etc/php/"$php_version"/apache2/php.ini

	echo "Adding recomended PHP settings"
	sed -e 's/max_execution_time = 30/max_execution_time = 60/' -i /etc/php/"$php_version"/apache2/php.ini
	sed -e 's/memory_limit = 128M/memory_limit = 512M/' -i /etc/php/"$php_version"/apache2/php.ini

	echo "Downloading the Cacti software"
	git clone -b master https://github.com/Cacti/cacti.git
	mv cacti /var/www/html
	cp /var/www/html/cacti/include/config.php.dist /var/www/html/cacti/include/config.php

	echo "Assigning permissions"
	chown -R www-data:www-data /var/www/html/cacti
	chown -R www-data:www-data /var/www/html/cacti/resource/snmp_queries/
	chown -R www-data:www-data /var/www/html/cacti/resource/script_server/
	chown -R www-data:www-data /var/www/html/cacti/resource/script_queries/
	chown -R www-data:www-data /var/www/html/cacti/scripts/
	chown -R www-data:www-data /var/www/html/cacti/cache/boost/
	chown -R www-data:www-data /var/www/html/cacti/cache/mibcache/
	chown -R www-data:www-data /var/www/html/cacti/cache/realtime/
	chown -R www-data:www-data /var/www/html/cacti/cache/spikekill/

	echo "Creating log file"
	touch /var/www/html/cacti/log/cacti.log
	chmod 664 /var/www/html/cacti/log/cacti.log
	chown -R www-data:www-data  /var/www/html/cacti/log/

	# Database
	echo "Mysql Configuration"
{
	echo "[mysqld]"
	echo "max_heap_table_size = 128M"
	echo "tmp_table_size = 128M"
	echo "join_buffer_size = 256M"
	echo "innodb_buffer_pool_size = 2048M"
	echo "innodb_buffer_pool_instances = 21"
	echo "innodb_io_capacity_max = 10000"
	echo "innodb_io_capacity = 5000"
	echo "innodb_write_io_threads = 16"
	echo "innodb_read_io_threads = 32"
  	echo "innodb_flush_log_at_timeout = 3"
	echo "innodb_file_format = Barracuda"
	echo "innodb_large_prefix = 1"
} >> /etc/mysql/my.cnf

	sed -e 's/collation-server      = utf8mb4_general_ci/collation-server      = utf8mb4_unicode_ci/' -i /etc/mysql/mariadb.conf.d/50-server.cnf

	dbpassword="$(openssl rand -base64 32)"
mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE cacti;
MYSQL_SCRIPT

mysql -u root <<MYSQL_SCRIPT
GRANT ALL PRIVILEGES ON cacti.* TO 'cactiuser'@'localhost' IDENTIFIED BY '$dbpassword';
GRANT SELECT ON mysql.time_zone_name TO cactiuser@localhost;
ALTER DATABASE cacti CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
FLUSH PRIVILEGES;
MYSQL_SCRIPT

	echo "Import the default cacti database"
	mysql -u root  cacti < /var/www/html/cacti/cacti.sql
	mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root mysql

	sed -ie "s/database_password = 'cactiuser'/database_password = '$dbpassword'/"  /var/www/html/cacti/include/config.php

	if [[  $thold == "1"  ]]
	  then
		git clone https://github.com/Cacti/plugin_thold.git thold
		chown -R www-data:www-data thold
		mv thold /var/www/html/cacti/plugins
	fi

	echo "Creating cron entry"
	touch /etc/cron.d/cacti
	echo "*/5 * * * * www-data php /var/www/html/cacti/poller.php > /dev/null 2>&1" > /etc/cron.d/cacti

	echo "Restarting Mysqldb and Apache server service"
	service mysql restart
	service apache2 restart
	service cron restart
}


function cacti_upgrade () {
	echo ""
	echo "Stopping cron service"
	systemctl stop cron
	echo ""

	echo "Backup the old Cacti database"
	mysqldump -u root cacti > /tmp/cacti_db_backup.sql

	echo "Backup the old Cacti directory"
	mv /var/www/html/cacti /tmp

	echo "Downloading the new version"
	git clone -b master https://github.com/Cacti/cacti.git
	mv cacti /var/www/html/

	echo "Copying the config.php file from the old Cacti directory."
	cp /tmp/cacti/include/config.php /var/www/html/cacti/include/config.php

	echo "Copying the *.rrd files from the old Cacti directory."
	cp /tmp/cacti/rra/* /var/www/html/cacti/rra/

	# Copy any relevant custom scripts from the old Cacti directory
	echo "Copying the scripts files from the old Cacti directory."
	cp -u cacti_old/scripts/* cacti/scripts/

	echo "Copying the plugin files from the old Cacti directory."
	cp -R /tmp/cacti/plugins/* /var/www/html/cacti/plugins/

	# Copy any relevant custom resource XML files from the old Cacti directory
	echo "Copying the resource files from the old Cacti directory."
	cp -u -R /tmp/cacti/resource/* /var/www/html/cacti/resource/
	echo ""

	chown -R www-data:www-data /var/www/html/cacti/

	systemctl start cron

}

function manageMenu () {
	clear
	echo "Welcome to Cacti install!"
	echo ""
	echo "It looks like Cacti is already installed."
	echo ""
	echo "What do you want to do?"
	echo "   1) Upgrade"
	echo "   2) Exit"
	until [[ "$MENU_OPTION" =~ ^[1-2]$ ]]; do
		read -rp "Select an option [1-2]: " MENU_OPTION
	done

	case $MENU_OPTION in
		1)
			cacti_upgrade
		;;
		2)
			exit 0
		;;
	esac
}

function CheckIsRoot () {
	if [ "$EUID" -ne 0 ]; then
		echo "Sorry, you need to run this as root"
		exit 1
	fi
}

function CheckIsInstalled () {
	if [[ -e /var/www/html/cacti/include/config.php ]]; then
	        manageMenu
	else
	        install_cacti
	fi
}

CheckIsRoot
CheckIsInstalled