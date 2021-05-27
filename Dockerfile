ARG BASE_IMAGE=nvcr.io/nvidia/l4t-base:r32.4.3
FROM ${BASE_IMAGE}
ARG BUILD_SRC="/janus"
MAINTAINER Sean Pollock
RUN apt update && apt-get upgrade -y
# install dependencies
RUN apt-get install git-core libjansson-dev \
	libssl-dev \
	libtool libnice-dev automake \
	ca-certificates \
	libconfig-dev \
	# libsrtp2-dev -y \
	gengetopt \
	libcurl4-openssl-dev \
	wget \
	cmake \
	python3 \
	python3-pip \
	python3-setuptools \
	python3-wheel \
	ninja-build \
	libogg-dev \
	pkg-config \
	libmicrohttpd-dev \
	nginx \
	ssl-cert \
	nano -y
# install meson
RUN pip3 install meson
# install libnice
RUN wget https://libnice.freedesktop.org/releases/libnice-0.1.16.tar.gz \
	&& tar xfv libnice-0.1.16.tar.gz \
	&& cd libnice-0.1.16 \
	&& meson builddir \
	&& ninja -C builddir \
	&& ninja -C builddir test \
  	&& ninja -C builddir install
# install libsrtp2
RUN wget https://github.com/cisco/libsrtp/archive/v2.3.0.tar.gz && \
	tar xfv v2.3.0.tar.gz && \
	cd libsrtp-2.3.0 && \
	./configure --prefix=/usr --enable-openssl && \
	make shared_library && \
	make install
# install websockets
RUN git clone https://github.com/warmcat/libwebsockets.git /libwebsockets \
	&& mkdir /libwebsockets/build \
	&& cd /libwebsockets/build \
	&& cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr -DCMAKE_C_FLAGS="-fpic" .. \
 	&& make \
   	&& make install
# install datachannels
RUN git clone https://github.com/sctplab/usrsctp \
	&& cd usrsctp \
	&& ./bootstrap \
	&& ./configure --prefix=/usr --disable-programs --disable-inet --disable-inet6 \
	&& make && make install
# make janus-gateway
RUN git clone https://github.com/meetecho/janus-gateway.git ${BUILD_SRC} \
	&& mv /libwebsockets ${BUILD_SRC}
RUN cd ${BUILD_SRC} \
	&& ./autogen.sh \
	&& ./configure --prefix=/janus \
	--enable-http --enable-websockets --enable-data-channels --disable-rabbitmq --disable-mqt --disable-all-handlers \
 	&& make \
 	&& make install
# clean up
ADD scripts/clean.sh /clean.sh
ADD scripts/config.sh /config.sh
RUN chmod +x /clean.sh
RUN chmod +x /config.sh
RUN /clean.sh
ADD config/janus.plugin.streaming.jcfg /janus.plugin.streaming.jcfg
ADD config/janus.transport.http.jcfg /janus/etc/janus/janus.transport.http.jcfg
ADD config/default /etc/nginx/sites-available/default
RUN /config.sh
# API PORT
EXPOSE 8088
EXPOSE 8089
# Websocket PORT
EXPOSE 8188
# Webserver (for testing demos)
EXPOSE 8080
# run janus
ARG LD_LIBRARY_PATH=/usr/lib
RUN cp -a /janus/html/* /var/www/html
RUN make-ssl-cert generate-default-snakeoil
ADD scripts/run.sh /run.sh
RUN chmod +x /run.sh


