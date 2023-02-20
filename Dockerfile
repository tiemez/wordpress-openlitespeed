FROM debian:bullseye-slim as builder
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /var/www/html
RUN apt update &&  \
    apt install -y -qq  \
    curl  \
    wget &&  \
    wget -O - https://repo.litespeed.sh | bash && \
    apt update &&  \
    apt install -y -qq \
        openssl \
        ghostscript \
        libfreetype6-dev \
        libicu-dev \
        libjpeg-dev \
        libmagickwand-dev \
        libpng-dev \
        libwebp-dev \
        libzip-dev \
        supervisor  \
        openlitespeed \
        lsphp82 \
        lsphp82-common  \
        lsphp82-curl  \
        lsphp82-mysql  \
        lsphp82-opcache \
        lsphp82-imagick
COPY --from=wordpress:6.1.1-php8.2-fpm /var/www/ /var/www/
COPY --from=wordpress:6.1.1-php8.2-fpm /usr/src/wordpress/wp-config-docker.php /usr/src/wordpress/
COPY --chmod=0755 ./wordpress/docker-entrypoint.sh /usr/local/bin/

RUN openssl req -x509 -nodes -days 365 \
    -subj  "/C=NL/ST=GELDERLAND/O=Tiemez/CN=wordpress.hs.nl" \
    -newkey rsa:2048 -keyout /usr/local/lsws/conf/cert/wordpress.hs.nl-privkey.pem \
    -out /usr/local/lsws/conf/cert/wordpress.hs.nl-fullchain.pem;
RUN set -eux; \
	version='6.1.1'; \
	sha1='80f0f829645dec07c68bcfe0a0a1e1d563992fcb'; \
	\
	curl -o wordpress.tar.gz -fL "https://wordpress.org/wordpress-$version.tar.gz"; \
	echo "$sha1 *wordpress.tar.gz" | sha1sum -c -; \
	\
# upstream tarballs include ./wordpress/ so this gives us /usr/src/wordpress
	tar -xzf wordpress.tar.gz -C /usr/src/ && \
	rm wordpress.tar.gz && \
    chown -R www-data:www-data /usr/src/wordpress && \
    mkdir wp-content && \
    for dir in /usr/src/wordpress/wp-content/*/ cache; do \
    		dir="$(basename "${dir%/}")"; \
    		mkdir "wp-content/$dir"; \
    	done; \
    	chown -R www-data:www-data wp-content; \
    	chmod -R 777 wp-content; \
    	chown -R www-data:www-data /usr/src/wordpress;

RUN ln -s /usr/local/lsws/bin/openlitespeed /usr/local/bin/openlitespeed && \
    ln -s /usr/local/lsws/lsphp82/bin/php8.2 /usr/bin/php && \
    rm -rf /var/cache/apt/archives /var/lib/apt/lists
COPY ./wordpress/.htaccess /usr/src/wordpress/.htaccess
VOLUME /var/www/html

FROM builder as runtime
COPY ./openlitespeed/httpd_config.conf /usr/local/lsws/conf/httpd_config.conf
COPY ./openlitespeed/httpd_config.conf /usr/local/lsws/conf/httpd_config.conf.org

COPY ./openlitespeed/vhost.conf /usr/local/lsws/conf/vhosts/Wordpress/vhconf.conf
COPY php/php.ini /usr/local/lsws/lsphp82/etc/php/8.2/litespeed/php.ini
COPY supervisord/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
EXPOSE 80/tcp 443/tcp 443/udp
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]