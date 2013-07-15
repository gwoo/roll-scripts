#!/bin/bash

cd /srv/src

#CHECK VERSION
PHPV=""
if [ ! -z `command -v php > /dev/null 2>&1` ]; then
	PHPV=`php -v | grep $PHP_VERSION`
fi

mkdir -p /var/www
cat > /var/www/index.php << "EOF"
<?php phpinfo();?>
EOF

#START PHP INSTALL
if [ -z $PHPV ]; then
roll.get $PHP_MIRROR "php-${PHP_VERSION}" tar.bz2

mkdir -p /srv/etc/php.conf.d
roll.link /srv/etc/php.conf.d /etc
apt-get -y -q install sendmail libxml2-dev libcurl4-openssl-dev libmcrypt-dev libbz2-dev
apt-get -y -q install libjpeg-dev libpng-dev

#Configure PHP
cd "/srv/src/php-${PHP_VERSION}"
roll.mute "./configure \
--prefix=/usr \
--with-config-file-path=/etc \
--with-config-file-scan-dir=/etc/php.conf.d \
--enable-fpm \
--with-fpm-user=www-data \
--with-pear \
--with-mcrypt \
--enable-mbstring \
--enable-mbregex \
--with-gd \
--with-jpeg-dir=/usr/lib \
--enable-gd-native-ttf \
--enable-exif \
--with-mysql=mysqlnd \
--with-pdo-mysql=mysqlnd \
--with-mysqli=mysqlnd \
--with-libxml-dir=/usr/lib \
--enable-zip \
--with-zlib \
--with-bz2 \
--enable-sockets \
--with-curl \
--with-openssl \
--enable-ftp
"
roll.mute "make -w install"

# php.ini
cat > "/srv/etc/php.ini" << "EOF"
[PHP]
date.timezone = UTC
engine = On
short_open_tag = Off
asp_tags = Off
precision = 14
y2k_compliance = On
output_buffering = 4096
zlib.output_compression = Off
implicit_flush = Off
unserialize_callback_func =
serialize_precision = 100
allow_call_time_pass_reference = Off
safe_mode = Off
safe_mode_gid = Off
safe_mode_include_dir =
safe_mode_exec_dir =
safe_mode_allowed_env_vars =
PHP_safe_mode_protected_env_vars = LD_LIBRARY_PATH
disable_functions =
disable_classes =
expose_php = Off
max_execution_time = 30
max_input_time = 60
max_input_vars = 1000
memory_limit = 128M
error_reporting = E_ALL &~ E_DEPRECATED
display_errors = Off
display_startup_errors = Off
log_errors = On
log_errors_max_len = 1024
ignore_repeated_errors = Off
ignore_repeated_source = Off
report_memleaks = On
track_errors = Off
html_errors = Off
error_log = syslog
variables_order = "GPCS"
request_order = "GP"
register_globals = Off
register_long_arrays = Off
register_argc_argv = Off
auto_globals_jit = On
post_max_size = 50M
magic_quotes_gpc = Off
magic_quotes_runtime = Off
magic_quotes_sybase = Off
auto_prepend_file =
auto_append_file =
default_mimetype = "text/html"
include_path = ".:/php/include:/usr/lib/php"
doc_root =
user_dir =
enable_dl = Off
cgi.fix_pathinfo = 0
file_uploads = On
upload_tmp_dir = /tmp/storage
upload_max_filesize = 50M
max_file_uploads = 20
allow_url_fopen = On
allow_url_include = Off
default_socket_timeout = 60
pdo_mysql.cache_size = 2000
pdo_mysql.default_socket=
define_syslog_variables  = Off
SMTP = localhost
smtp_port = 25
mail.add_x_header = On
mysql.allow_local_infile = On
mysql.allow_persistent = On
mysql.cache_size = 2000
mysql.max_persistent = -1
mysql.max_links = -1
mysql.default_port =
mysql.default_socket =
mysql.default_host =
mysql.default_user =
mysql.default_password =
mysql.connect_timeout = 60
mysql.trace_mode = Off
mysqli.max_persistent = -1
mysqli.allow_persistent = On
mysqli.max_links = -1
mysqli.cache_size = 2000
mysqli.default_port = 3306
mysqli.default_socket =
mysqli.default_host =
mysqli.default_user =
mysqli.default_pw =
mysqli.reconnect = Off
mysqlnd.collect_statistics = On
mysqlnd.collect_memory_statistics = Off
bcmath.scale = 0
session.save_handler = files
session.use_cookies = 1
session.use_only_cookies = 1
session.name = PHPSESSID
session.auto_start = 0
session.cookie_lifetime = 0
session.cookie_path = /
session.cookie_domain =
session.cookie_httponly =
session.serialize_handler = php
session.gc_probability = 1
session.gc_divisor = 1000
session.gc_maxlifetime = 1440
session.bug_compat_42 = Off
session.bug_compat_warn = Off
session.referer_check =
session.entropy_length = 0
session.cache_limiter = nocache
session.cache_expire = 180
session.use_trans_sid = 0
session.hash_function = 0
session.hash_bits_per_character = 5
url_rewriter.tags = "a=href,area=href,frame=src,input=src,form=fakeentry"
extension = "apc.so"
EOF
roll.link /srv/etc/php.ini /etc/php.ini

################
## php-fpm conf
################
cat > "/srv/etc/php-fpm.conf" << "EOF"
[global]
pid = /var/run/php-fpm.pid
error_log = /var/log/php-error.log
log_level = error
daemonize = yes

[www]
listen = /var/run/php-fpm.sock
user = www-data
group = www-data

pm = static
pm.max_children = 10
pm.max_requests = 500

request_slowlog_timeout = 30
slowlog = /var/log/php-slow.log

[php-status]
listen = /var/run/php-status.sock
user = www-data

pm = static
pm.max_children = 1
pm.max_requests = 10000

ping.path = /ping
ping.response = "pong"
EOF
roll.link /srv/etc/php-fpm.conf /etc/php-fpm.conf

##############
# init script
##############
cat > "/etc/init.d/php-fpm" << "EOF"
#! /bin/sh

### BEGIN INIT INFO
# Provides:          php-fpm
# Required-Start:    $all
# Required-Stop:     $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts php-fpm
# Description:       starts the PHP FastCGI Process Manager daemon
### END INIT INFO

mkdir -p /var/run

php_fpm_BIN=/usr/sbin/php-fpm
php_fpm_CONF=/etc/php-fpm.conf
php_fpm_PID=/var/run/php-fpm.pid


php_opts="--fpm-config $php_fpm_CONF"


wait_for_pid () {
	try=0

	while test $try -lt 35 ; do

		case "$1" in
			'created')
			if [ -f "$2" ] ; then
				try=''
				break
			fi
			;;

			'removed')
			if [ ! -f "$2" ] ; then
				try=''
				break
			fi
			;;
		esac

		echo -n .
		try=`expr $try + 1`
		sleep 1

	done

}

case "$1" in
	start)
		echo -n "Starting php-fpm "

		$php_fpm_BIN $php_opts

		if [ "$?" != 0 ] ; then
			echo " failed"
			exit 1
		fi

		wait_for_pid created $php_fpm_PID

		if [ -n "$try" ] ; then
			echo " failed"
			exit 1
		else
			echo " done"
		fi
	;;

	stop)
		echo -n "Gracefully shutting down php-fpm "

		if [ ! -r $php_fpm_PID ] ; then
			echo "warning, no pid file found - php-fpm is not running ?"
			exit 1
		fi

		kill -QUIT `cat $php_fpm_PID`

		wait_for_pid removed $php_fpm_PID

		if [ -n "$try" ] ; then
			echo " failed. Use force-exit"
			exit 1
		else
			echo " done"
		fi
	;;

	force-quit)
		echo -n "Terminating php-fpm "

		if [ ! -r $php_fpm_PID ] ; then
			echo "warning, no pid file found - php-fpm is not running ?"
			exit 1
		fi

		kill -TERM `cat $php_fpm_PID`

		wait_for_pid removed $php_fpm_PID

		if [ -n "$try" ] ; then
			echo " failed"
			exit 1
		else
			echo " done"
		fi
	;;

	restart)
		$0 stop
		$0 start
	;;

	reload)

		echo -n "Reload service php-fpm "

		if [ ! -r $php_fpm_PID ] ; then
			echo "warning, no pid file found - php-fpm is not running ?"
			exit 1
		fi

		kill -USR2 `cat $php_fpm_PID`

		echo " done"
	;;

	*)
		echo "Usage: $0 {start|stop|force-quit|restart|reload}"
		exit 1
	;;

esac
EOF
chmod a+x /etc/init.d/php-fpm

update-rc.d -f php-fpm defaults
touch /var/run/php-fpm.pid
touch /var/log/php-error.log
chmod 777 /var/log/php-error.log
touch /var/log/php-slow.log
chmod 777 /var/log/php-slow.log

# Install Extensions
pecl channel-update pecl.php.net
## APC
printf "\n" | pecl -q install apc-beta
cat > /srv/etc/php.conf.d/apc.ini << "EOF"
extension = "apc.so"
EOF
fi
#END PHP INSTALL

php -v

update-rc.d -f php-fpm defaults
service php-fpm restart