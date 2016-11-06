FROM alpine:3.4
MAINTAINER Andrew Dunham <andrew@du.nham.ca>

# Install runit, nginx, php, PEAR, and php-fpm
RUN echo '@community http://dl-cdn.alpinelinux.org/alpine/edge/community' >> /etc/apk/repositories && \
    apk add --update                \
        ca-certificates             \
        curl                        \
        nginx                       \
        php5-common                  \
        php5-iconv                   \
        php5-ctype                   \
        php5-fpm                     \
        php5-json                    \
        php5-mcrypt                  \
        php5-openssl                 \
        php5-pear                    \
        php5-phar                    \
        runit@community          && \
    curl -sS https://getcomposer.org/installer | \
    php -- --install-dir=/usr/local/bin --filename=composer

# Copy config files
ADD nginx.conf /tmp/

# Configure system:
#   - Add 'php' user and group to run as
# Configure nginx:
#   - Copy config file into place
# Configure php:
#   - Don't fix path info
# Configure php-fpm:
#   - Listen on a unix socket
#   - Fix permissions on socket
#   - No limits on allowed clients
#   - Do not catch worker outputs
#   - No error logging
#   - Do not daemonize
# Configure runit:
#   - Create service directories for everything
RUN echo "** Configuring system" && \
    addgroup -g 1001 php && \
    adduser                 \
        -D                  \
        -u 1001             \
        -G php              \
        -s /bin/sh          \
        php              && \
    echo "** Configuring nginx" && \
    mv /tmp/nginx.conf /etc/nginx/nginx.conf && \
    echo "** Configuring PHP" && \
    sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php5/php.ini && \
    echo "** Configuring PHP-FPM" && \
    sed -e 's|^listen\s*=.*$|listen = /var/run/php-fpm.sock|g'     \
            -e 's/;listen.mode = 0660/listen.mode = 0666/g' \
            -e '/allowed_clients/d'                             \
            -e 's/user\s*=\s*nobody/user = php/'            \
            -e 's/group\s*=\s*nobody/group = php/'          \
            -e '/catch_workers_output/s/^;//'               \
            -e '/error_log/d'                               \
            -e 's/;daemonize\s*=\s*yes/daemonize = no/g'    \
            -i /etc/php5/php-fpm.conf && \
    echo "** Configuring runit" && \
    mkdir -p /etc/service && \
    echo "** Done"

# Copy service files in place
ADD sv /etc/sv/
ADD ["runsvdir-start", "runit-wrapper", "/sbin/"]

# Symlink to enable services
RUN echo '** Enabling services' && \
    ln -s /etc/sv/nginx /etc/service/nginx && \
    ln -s /etc/sv/php-fpm /etc/service/php-fpm

EXPOSE 80
CMD ["/sbin/runit-wrapper"]
