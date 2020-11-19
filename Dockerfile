FROM debian:stretch-slim

ARG MAKE_J=4
ARG NGINX_VERSION=1.19.0
ARG PAGESPEED_VERSION=1.13.35.2
ARG LIBPNG_VERSION=1.6.37

ENV MAKE_J=${MAKE_J} \
	NGINX_VERSION=${NGINX_VERSION} \
	LIBPNG_VERSION=${LIBPNG_VERSION} \
	PAGESPEED_VERSION=${PAGESPEED_VERSION}

RUN apt-get update -y && \
	apt-get upgrade -y

RUN apt-get install -y \
	apt-utils \
	git nano \
	g++ \
	gcc \
	curl \
	make \
	unzip \
	bzip2 \
	gperf \
	python \
	openssl \
	libuuid1 \
	apt-utils \
	pkg-config \
	icu-devtools \
	build-essential \
	ca-certificates \
	uuid-dev \
	zlib1g-dev \
	libicu-dev \
	libssl-dev \
	apache2-dev \
	libpcre3 \
	libpcre3-dev \
	libmaxminddb-dev \
	libpng-dev \
	libaprutil1-dev \
	linux-headers-amd64 \
	libjpeg62-turbo-dev \
	libcurl4-openssl-dev

# Build libpng
RUN cd /tmp && \
	curl -L http://prdownloads.sourceforge.net/libpng/libpng-${LIBPNG_VERSION}.tar.gz | tar -zx && \
	cd /tmp/libpng-${LIBPNG_VERSION} && \
	./configure --build=$CBUILD --host=$CHOST --prefix=/usr --enable-shared --with-libpng-compat && \
	make -j${MAKE_J} install V=0

RUN cd /tmp && \
	curl -O -L https://github.com/pagespeed/ngx_pagespeed/archive/v${PAGESPEED_VERSION}-stable.zip && \
	unzip v${PAGESPEED_VERSION}-stable.zip

RUN cd /tmp/incubator-pagespeed-ngx-${PAGESPEED_VERSION}-stable/ && \
	psol_url=https://dl.google.com/dl/page-speed/psol/${PAGESPEED_VERSION}.tar.gz && \
	[ -e scripts/format_binary_url.sh ] && psol_url=$(scripts/format_binary_url.sh PSOL_BINARY_URL) && \
	echo "URL: ${psol_url}" && \
	curl -L ${psol_url} | tar -xz

# Build in additional Nginx modules
RUN cd /tmp && git clone https://github.com/FRiCKLE/ngx_cache_purge.git && \

# Build Nginx with support for PageSpeed
RUN cd /tmp && \
	curl -L http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar -zx && \
	cd /tmp/nginx-${NGINX_VERSION} && \
	LD_LIBRARY_PATH=/tmp/incubator-pagespeed-ngx-${PAGESPEED_VERSION}/usr/lib:/usr/lib ./configure \
	--prefix=/etc/nginx 
	--sbin-path=/usr/sbin/nginx 
	--modules-path=/usr/lib/nginx/modules 
	--conf-path=/etc/nginx/nginx.conf 
	--error-log-path=/var/log/nginx/error.log 
	--http-log-path=/var/log/nginx/access.log 
	--pid-path=/var/run/nginx.pid 
	--lock-path=/var/run/nginx.lock 
	--http-client-body-temp-path=/var/cache/nginx/client_temp 
	--http-proxy-temp-path=/var/cache/nginx/proxy_temp 
	--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp 
	--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp 
	--http-scgi-temp-path=/var/cache/nginx/scgi_temp 
	--user=nginx 
	--group=nginx 
	--with-compat 
	--with-file-aio 
	--with-threads 
	--with-http_addition_module 
	--with-http_auth_request_module 
	--with-http_dav_module 
	--with-http_flv_module 
	--with-http_gunzip_module 
	--with-http_gzip_static_module 
	--with-http_mp4_module 
	--with-http_random_index_module 
	--with-http_realip_module 
	--with-http_secure_link_module 
	--with-http_slice_module 
	--with-http_ssl_module 
	--with-http_stub_status_module 
	--with-http_sub_module 
	--with-http_v2_module 
	--with-mail 
	--with-mail_ssl_module 
	--with-stream 
	--with-stream_realip_module 
	--with-stream_ssl_module 
	--with-stream_ssl_preread_module 
	--with-cc-opt='-g -O2 -fdebug-prefix-map=/data/builder/debuild/nginx-1.19.3/debian/debuild-base/nginx-1.19.3=. -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC' 
	--with-ld-opt='-Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie'
	--add-module=/tmp/ngx_cache_purge \
	--add-module=/tmp/incubator-pagespeed-ngx-${PAGESPEED_VERSION}-stable && \
	make install --silent

# Clean-up
RUN apt-get remove -y git
RUN rm -rf /var/lib/apt/lists/* && rm -rf /tmp/* && \
	# Forward request and error logs to docker log collector
	ln -sf /dev/stdout /var/log/nginx/access.log && \
	ln -sf /dev/stderr /var/log/nginx/error.log && \
	# Make PageSpeed cache writable
	mkdir -p /var/cache/ngx_pagespeed && \
	chmod -R o+wr /var/cache/ngx_pagespeed

COPY ./config  /etc/nginx
COPY ./scripts /usr/local/bin/

RUN chmod +x /usr/local/bin/*

EXPOSE 80
WORKDIR /etc/nginx

STOPSIGNAL SIGTERM

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
