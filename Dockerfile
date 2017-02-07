FROM ubuntu:14.04

MAINTAINER Jérémy Jacquier-Roux <jeremy.jacquier-roux@bonitasoft.org>

# install packages
RUN apt-get update && apt-get install -y \
  mysql-client-core-5.5 \
  openjdk-7-jre-headless \
  postgresql-client \
  unzip \
  wget \
  zip \
  supervisor \
  git \
  apache2 \
  mysql-server \
  libapache2-mod-php5 \
  php5-mysql \
  pwgen \
  php-apc \
  php5-mcrypt \
  && rm -rf /var/lib/apt/lists/* \
  && echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Add image configuration and scripts
ADD start-apache2.sh /start-apache2.sh
ADD start-mysqld.sh /start-mysqld.sh
ADD run.sh /run.sh
RUN chmod 755 /*.sh
ADD supervisord-apache2.conf /etc/supervisor/conf.d/supervisord-apache2.conf
ADD supervisord-mysqld.conf /etc/supervisor/conf.d/supervisord-mysqld.conf
ADD supervisord-catalina.conf /etc/supervisor/conf.d/supervisord-catalina.conf

# Remove pre-installed database
RUN rm -rf /var/lib/mysql/*

# Add MySQL utils
ADD create_mysql_admin_user.sh /create_mysql_admin_user.sh
RUN chmod 755 /*.sh

# config to enable .htaccess
ADD apache_default /etc/apache2/sites-available/000-default.conf
RUN a2enmod rewrite

# Configure /app folder with slim app
RUN git clone https://github.com/geekinc/bonita-slim /app
RUN mkdir -p /app 
	&& rm -fr /var/www/html \
	&& ln -s /app/public /var/www/html \
	&& ln -s /app/src /var/www/src \
	&& ln -s /app/vendor /var/www/vendor \
	&& ln -s /app/config /var/www/config \
	&& ln -s /app/.env.docker /var/www/.env

#Environment variables to configure php
ENV PHP_UPLOAD_MAX_FILESIZE 10M
ENV PHP_POST_MAX_SIZE 10M
ENV HTTP_API true

# Add volumes for MySQL 
VOLUME  ["/app", "/etc/mysql", "/var/lib/mysql" ]

RUN mkdir /opt/custom-init.d/

# create user to launch Bonita BPM as non-root
RUN groupadd -r bonita -g 1000 \
  && useradd -u 1000 -r -g bonita -d /opt/bonita/ -s /sbin/nologin -c "Bonita User" bonita

# grab gosu
RUN gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4
RUN wget -q "https://github.com/tianon/gosu/releases/download/1.6/gosu-$(dpkg --print-architecture)" -O /usr/local/bin/gosu \
  && wget -q "https://github.com/tianon/gosu/releases/download/1.6/gosu-$(dpkg --print-architecture).asc" -O /usr/local/bin/gosu.asc \
  && gpg --verify /usr/local/bin/gosu.asc \
  && rm /usr/local/bin/gosu.asc \
  && chmod +x /usr/local/bin/gosu

ENV BONITA_VERSION 7.4.1
ENV TOMCAT_VERSION 7.0.67
ENV BONITA_SHA256 e299ae1b68f40699ec8607911967c614206c7e74d6ab36ea03d3f1de7e8109a3

# add Bonita BPM archive to the container
RUN mkdir /opt/files \
  && wget -q http://download.forge.ow2.org/bonita/BonitaBPMCommunity-${BONITA_VERSION}-Tomcat-${TOMCAT_VERSION}.zip -O /opt/files/BonitaBPMCommunity-${BONITA_VERSION}-Tomcat-${TOMCAT_VERSION}.zip \
  && echo "$BONITA_SHA256" /opt/files/BonitaBPMCommunity-${BONITA_VERSION}-Tomcat-${TOMCAT_VERSION}.zip | sha256sum -c -

# create Volume to store Bonita BPM files
VOLUME /opt/bonita

COPY files /opt/files
COPY templates /opt/templates

# expose ports
EXPOSE 80 3306 8080

# command to run when the container starts
CMD ["/opt/files/startup.sh"]