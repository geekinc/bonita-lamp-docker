#!/bin/bash
# ensure to set the proper owner of data volume
if [ `stat -c %U /opt/bonita/` != 'bonita' ]
then
	chown -R bonita:bonita /opt/bonita/
fi
# ensure to apply the proper configuration
if [ ! -f /opt/${BONITA_VERSION}-configured ]
then
	gosu bonita /opt/files/config.sh \
      && touch /opt/${BONITA_VERSION}-configured || exit 1
fi
if [ -d /opt/custom-init.d/ ]
then
	for f in /opt/custom-init.d/*.sh
	do
		[ -f "$f" ] && . "$f"
	done
fi

VOLUME_HOME="/var/lib/mysql"

sed -ri -e "s/^upload_max_filesize.*/upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE}/" \
    -e "s/^post_max_size.*/post_max_size = ${PHP_POST_MAX_SIZE}/" /etc/php5/apache2/php.ini
if [[ ! -d $VOLUME_HOME/mysql ]]; then
    echo "=> An empty or uninitialized MySQL volume is detected in $VOLUME_HOME"
    echo "=> Installing MySQL ..."
    mysql_install_db > /dev/null 2>&1
    echo "=> Done!"  
    /create_mysql_admin_user.sh
else
    echo "=> Using an existing volume of MySQL"
fi

exec supervisord -n

# launch tomcat
# exec gosu bonita /opt/bonita/BonitaBPMCommunity-${BONITA_VERSION}-Tomcat-${TOMCAT_VERSION}/server/bin/catalina.sh run
