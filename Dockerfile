FROM debian:latest
MAINTAINER Luc Appelman "lucapppelman@gmail.com"

# inspired by the official nginx docker container
# https://github.com/nginxinc/docker-nginx/blob/master/Dockerfile

RUN apt-get update
RUN apt-get install -y build-essential \
    curl \
    libpcre3 \
    libpcre3-dev \
    libxml2-dev \
    libxslt1-dev \
    tar \
    unzip \
    zlib1g-dev 
RUN rm -rf /var/lib/apt/lists/*

RUN NPS_VERSION=1.13.35.2-stable \
    PCRE_VERSION=8.44 \
    NGINX_VERSION=1.19.3 \
    ZLIB_VERSION=1.2.11 \
    OPENSSL_VERSION=1_1_1g \
    CACHE_PURGE_VERSION=2.3 \
    NGINX_LOG_PATH=/var/log/nginx \
    NGINX_USER=www-data \
    NGINX_GROUP=www-data \
    TMP_DIR=$(mktemp -d) &&\
    curl -Ls https://github.com/apache/incubator-pagespeed-ngx/archive/v${NPS_VERSION}.tar.gz | tar -xvzf - \
        -C ${TMP_DIR} && \
    NPS_DIR=$(find ${TMP_DIR} -name "*pagespeed-ngx-${NPS_VERSION}" -type d) \
    PSOL_URL=$(${NPS_DIR}/scripts/format_binary_url.sh ${NPS_DIR}/PSOL_BINARY_URL) && \
    curl -Ls $PSOL_URL | tar -xvzf - \
        -C ${NPS_DIR} --exclude=lib/Debug && \
	ls -la $NPS_DIR && \
    curl -Ls https://github.com/nginx/nginx/archive/release-${NGINX_VERSION}.tar.gz | tar -xzf - \
        -C ${TMP_DIR} &&\
    curl -Ls https://ftp.pcre.org/pub/pcre/pcre-${PCRE_VERSION}.tar.gz | tar -xzf - \
        -C ${TMP_DIR} &&\
    curl -Ls https://github.com/madler/zlib/archive/v1.2.8.tar.gz | tar -xzf - \
        -C ${TMP_DIR} &&\
    curl -Ls https://github.com/openssl/openssl/archive/OpenSSL_${OPENSSL_VERSION}.tar.gz | tar -xvf - \
        -C ${TMP_DIR} &&\
    curl -Ls https://github.com/FRiCKLE/ngx_cache_purge/archive/${CACHE_PURGE_VERSION}.tar.gz | tar -xzf - \
        -C ${TMP_DIR} &&\
    cd ${TMP_DIR}/nginx-release-${NGINX_VERSION} &&\
    ./auto/configure \
        --add-module=${NPS_DIR} \
	--add-module=${TMP_DIR}/ngx_cache_purge-${CACHE_PURGE_VERSION} \
        --prefix=/etc/nginx \
	--sbin-path=/usr/sbin/nginx \
	--modules-path=/usr/lib/nginx/modules \
	--conf-path=/etc/nginx/nginx.conf \
	--error-log-path=/var/log/nginx/error.log \
	--http-log-path=/var/log/nginx/access.log \
	--pid-path=/var/run/nginx.pid \
	--lock-path=/var/run/nginx.lock \
	--group=${NGINX_GROUP} \
        --user=${NGINX_USER} \
        --with-cc-opt='-D_FORTIFY_SOURCE=2 -pie -fPIE -fstack-protector -Wformat -Wformat-security -fstack-protector -g -O1' \
        --with-ld-opt='-Wl,-z,now -Wl,-z,relro' \
        --with-compat \
	--with-file-aio \
	--with-threads \
	--with-http_addition_module \
	--with-http_auth_request_module \
	--with-http_dav_module \
	--with-http_flv_module \
	--with-http_gunzip_module \
	--with-http_gzip_static_module \
	--with-http_mp4_module \
	--with-http_random_index_module \
	--with-http_realip_module \
	--with-http_secure_link_module \
	--with-http_slice_module \
	--with-http_ssl_module \
	--with-http_stub_status_module \
	--with-http_sub_module \
	--with-http_v2_module \
	--with-mail \
	--with-mail_ssl_module \
	--with-stream \
	--with-stream_realip_module \
	--with-stream_ssl_module \
	--with-stream_ssl_preread_module \
        --with-http_ssl_module --with-openssl=${TMP_DIR}/openssl-OpenSSL_${OPENSSL_VERSION} \
        --with-pcre=${TMP_DIR}/pcre-${PCRE_VERSION} \
        --with-zlib=${TMP_DIR}/zlib-${ZLIB_VERSION} &&\
    make &&\
    make install &&\
    cd / && rm -rf ${TMP_DIR}

# Clean-up && Make PageSpeed cache writable
RUN rm -rf /var/lib/apt/lists/* && rm -rf ${TMP_DIR}/* && \
	mkdir -p /tmp/ngx_pagespeed && \
	chmod -R o+wr /tmp/ngx_pagespeed

# COPY ./config  /etc/nginx

EXPOSE 80 443
WORKDIR /etc/nginx

STOPSIGNAL SIGTERM

RUN ln -sf /dev/stdout /var/log/nginx/access.log && ln -sf /dev/stderr /var/log/nginx/error.log

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
