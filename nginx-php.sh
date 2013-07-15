#!/bin/bash
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# nginx 1.3
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

add-apt-repository ppa:chris-lea/nginx-devel
apt-get -y -q update
apt-get -y -q install nginx

mkdir -p /srv/etc/nginx/sites-available
mkdir -p /var/log/nginx

cat > "/srv/etc/nginx/sites-available/default" << "EOF"
upstream worker {
    server unix:/var/run/php-fpm.sock;
}

upstream status {
    server unix:/var/run/php-status.sock;
}

server {
    listen 80 default deferred;
    server_name _;

    root /var/www/;
    index index.php index.html;

    access_log /var/log/nginx/access.log;

    # Nginx Tweaking
    client_max_body_size 30M;
    server_tokens off;
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;

    # Allow for bigger cookies by increasing the buffers (but not their size)
    large_client_header_buffers 8 8k;
    fastcgi_buffer_size 128k;
    fastcgi_buffers 128 4k;
    fastcgi_busy_buffers_size 128k;
    fastcgi_temp_file_write_size 128k;

    # catch all, when a request matches no other rules
    location / {
        # index.php?foo=1... $is_args is ? if $args is not empty
        try_files $uri $uri/ /index.php$is_args$args;
    }

    # php-fpm status
    location = /ping {
        fastcgi_pass status;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }

    # stop flooding logs when there is no favicon
    location = /favicon.ico {
        access_log     off;
        log_not_found  off;
        try_files /favicon.ico =204;
    }

    # deny access to all .dot-files
    location ~ /\. {
        deny all;
    }

    # handle requests to PHP files
    location ~ \.php$ {
        if (!-f $request_filename) {
            return 404;
        }
        fastcgi_pass  worker;
        fastcgi_index index.php;
        fastcgi_intercept_errors off;

        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param SERVER_NAME $host;
        fastcgi_param SERVER_PORT $server_port;
    }

    # handles all 500 errors, allows for custom error files
    error_page 500 501 502 503 504 @five_oh_ex;
    location @five_oh_ex {
        access_log  /var/log/nginx/50x.log;

        if (-f "/var/www/50x.html") {
            rewrite ^ /50x.html last;
        }
    }

    location = /50x.html {
        internal;
        root /var/www/;
    }

    # handles 404 errors, allows for custom error files
    error_page 404 @four_oh_four;
    location @four_oh_four {
        if (-f "/var/www/404.html") {
            rewrite ^ /404.html last;
        }
    }

    location = /404.html {
        internal;
        root /var/www/;
    }

    # handles 405 errors, allows for custom error files
    error_page 405 =200 @four_oh_five;
    location @four_oh_five {
        if (!-f $request_filename) {
            return 404;
        }
        proxy_method GET;
        proxy_pass http://localhost:80;
    }

    # cache static files
    # note: this is ignored if more specific rule exists in custom nginx.conf
    location ~* ^.+\.(jpg|js|jpeg|png|ico|gif|txt|js|css|swf|zip|rar|avi|exe|mpg|mp3|wav|mpeg|asf|wmv)$ {
        expires 24h;
    }
}
EOF
roll.link /srv/etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

update-rc.d -f nginx defaults
service nginx restart