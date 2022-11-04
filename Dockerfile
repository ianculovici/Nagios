# install nagios 

FROM alpine:3.15

# info
MAINTAINER ianculovici version 1.0


ENV NAGIOS_HOME=/opt/nagios \
    NAGIOS_USER=nagios \
    NAGIOS_GROUP=nagios \
    NAGIOS_CMDUSER=nagios \
    NAGIOS_CMDGROUP=nagios \
    NAGIOS_TIMEZONE=UTC \
    NAGIOS_FQDN=nagios.example.com \
    NAGIOS_ADMIN_EMAIL=nagios@example.com \
    NAGIOSADMIN_USER=nagiosadmin \
    NAGIOSADMIN_PASS=nagios \
    NAGIOS_VERSION=4.4.8 \
    NAGIOS_PLUGINS_VERSION=2.4.0 \
    NRPE_VERSION=4.0.3 \
    APACHE_LOCK_DIR=/var/run \
    APACHE_LOG_DIR=/var/log/apache2 
ENV MONITOR_KEY_DIR=/home/${NAGIOS_USER}/monitor

# update container
RUN apk update && \
    apk add gd gd-dev apache2 php7 supervisor gcc perl libltdl libintl \
            apache2-utils tzdata php7-apache2 \
            ssmtp rsyslog
#            openssh openssh-server openssl openssl-dev \

# users and groups
RUN addgroup -S ${NAGIOS_GROUP} && \
    adduser  -S ${NAGIOS_USER} -G ${NAGIOS_CMDGROUP} -g ${NAGIOS_USER} && \
    addgroup -S apache ${NAGIOS_CMDGROUP}

# get archives
# Download Nagios core, plugins and nrpe sources
RUN cd /tmp && \
    echo -n "Downloading Nagios ${NAGIOS_VERSION} source code: " && \
    wget -O nagios-core.tar.gz "https://github.com/NagiosEnterprises/nagioscore/archive/nagios-${NAGIOS_VERSION}.tar.gz" && \
    echo -n -e "OK\nDownloading Nagios plugins ${NAGIOS_PLUGINS_VERSION} source code: " && \
    wget -O nagios-plugins.tar.gz "https://github.com/nagios-plugins/nagios-plugins/archive/release-${NAGIOS_PLUGINS_VERSION}.tar.gz" && \
    echo -n -e "OK\nDownloading NRPE ${NRPE_VERSION} source code: " && \
    wget -O nrpe.tar.gz "https://github.com/NagiosEnterprises/nrpe/archive/nrpe-${NRPE_VERSION}.tar.gz" 

# install nagios
# Compile Nagios Core
RUN apk add openssl-dev procps runit make build-base automake libtool autoconf py-docutils gnutls unzip g++

RUN ls -l /tmp && cd /tmp && \
    tar zxf nagios-core.tar.gz && \
    tar zxf nagios-plugins.tar.gz && \
    tar zxf nrpe.tar.gz && \
    cd  "/tmp/nagioscore-nagios-${NAGIOS_VERSION}" && \
    echo -e "\n ===========================\n  Configure Nagios Core\n ===========================\n" && \
    ./configure \
        --prefix=${NAGIOS_HOME}                  \
        --exec-prefix=${NAGIOS_HOME}             \
        --enable-event-broker                    \
        --with-command-user=${NAGIOS_CMDUSER}    \
        --with-command-group=${NAGIOS_CMDGROUP}  \
        --with-nagios-user=${NAGIOS_USER}        \
        --with-nagios-group=${NAGIOS_GROUP}      && \
    : 'Apply patches to Nagios Core sources:' && \
    echo -n "Replacing \"<sys\/poll.h>\" with \"<poll.h>\": " && \
    sed -i 's/<sys\/poll.h>/<poll.h>/g' ./include/config.h && \
    echo -e "\n\n ===========================\n Compile Nagios Core\n ===========================\n" && \
    make all && \
    echo -e "\n\n ===========================\n  Install Nagios Core\n ===========================\n" && \
    make install && \
    make install-commandmode && \
    make install-config && \
    make install-webconf && \
    echo -n "Nagios installed size: " && \
    du -h -s ${NAGIOS_HOME}

# install plugins
# Compile Nagios Plugins
RUN apk add --no-cache build-base automake libtool autoconf py-docutils gnutls  \
                       gnutls-dev g++ make alpine-sdk build-base gcc autoconf \
                       gettext-dev linux-headers openssl-dev net-snmp net-snmp-tools \
                       libcrypto1.1 libpq musl libldap libssl1.1 libdbi freeradius-client mariadb-connector-c \
                       openssh-client bind-tools samba-client fping grep rpcbind \
                       lm-sensors net-snmp-tools \
                       file freeradius-client-dev libdbi-dev libpq linux-headers mariadb-dev \
                       mariadb-connector-c-dev perl \
                       net-snmp-dev openldap-dev openssl-dev postgresql-dev
RUN echo -e "\n\n ===========================\n  Configure Nagios Plugins\n ===========================\n" && \
    cd  /tmp/nagios-plugins-release-${NAGIOS_PLUGINS_VERSION} && \
    ./autogen.sh && \
    ./configure  --with-nagios-user=${NAGIOS_USER}                  \
                 --with-nagios-group=${NAGIOS_USER}                 \
                 --with-openssl                                     \
                 --prefix=${NAGIOS_HOME}                            \
                 --with-ping-command="/bin/ping -n -w %d -c %d %s"  \
                 --with-ipv6                                        \
                 --with-ping6-command="/bin/gosu root /bin/ping6 -n -w %d -c %d %s"  && \
#                --with-ping-command="/bin/gosu root /bin/ping -n -w %d -c %d %s"  \
    echo "Nagios plugins configured: OK"                                       && \
    echo -n "Replacing \"<sys\/poll.h>\" with \"<poll.h>\": "                  && \
    egrep -rl "\<sys\/poll.h\>" . | xargs sed -i 's/<sys\/poll.h>/<poll.h>/g'  && \
    egrep -rl "\"sys\/poll.h\"" . | xargs sed -i 's/"sys\/poll.h"/"poll.h"/g'  && \
    echo -e "\n\n ===========================\n Compile Nagios Plugins\n ===========================\n" && \
    make && \
    echo "Nagios plugins compile successfully: OK" && \
    echo -e "\n\n ===========================\nInstall Nagios Plugins\n ===========================\n" && \
    make install && \
     echo "Nagios plugins installed successfully: OK"
# Compile NRPE
RUN echo -e "\n\n =====================\n  Configure NRPE\n =====================\n" && \
    cd  /tmp/nrpe-nrpe-${NRPE_VERSION} && \
    ./configure --enable-command-args \
                --with-nagios-user=${NAGIOS_USER} \
                --with-nagios-group=${NAGIOS_USER} \
                --with-ssl=/usr/bin/openssl \
                --with-ssl-lib=/usr/lib && \
    echo "NRPE client configured: OK" && \
    echo -e "\n\n ===========================\n  Compile NRPE\n ===========================\n" && \
    # make all && \
    make check_nrpe                                                          && \
    echo "NRPE compiled successfully: OK" && \
    echo -e "\n\n ===========================\n  Install NRPE\n ===========================\n" && \
    # make install && \
    cp src/check_nrpe ${NAGIOS_HOME}/libexec/                                && \
    echo "NRPE installed successfully: OK" && \
    echo -n "Final Nagios installed size: " && \
    du -h -s ${NAGIOS_HOME}


# Configure Apache and SSMTP
#RUN cp /usr/share/zoneinfo/${NAGIOS_TIMEZONE} /etc/localtime && echo ${NAGIOS_TIMEZONE} > /etc/timezone
#RUN apk del tzdata

RUN export DOC_ROOT="DocumentRoot $(echo $NAGIOS_HOME/share)"                                        && \
    sed -i "s,DocumentRoot.*,$DOC_ROOT," /etc/apache2/httpd.conf                                     && \
    sed -i "s|^ *ScriptAlias.*$|ScriptAlias /cgi-bin $NAGIOS_HOME/sbin|g" /etc/apache2/httpd.conf    && \
    sed -i 's/^\(.*\)#\(LoadModule cgi_module\)\(.*\)/\1\2\3/' /etc/apache2/httpd.conf               && \
    echo "ServerName ${NAGIOS_FQDN}" >> /etc/apache2/httpd.conf

RUN sed -i 's,/bin/mail,/usr/bin/mail,' ${NAGIOS_HOME}/etc/objects/commands.cfg  && \
    sed -i 's,/usr/usr,/usr,'           ${NAGIOS_HOME}/etc/objects/commands.cfg  && \
                                                                                    \
    : '# Modify Nagios mail commands in order to work with SSMTP'                && \
    sed -i 's/^.*command_line.*Host Alert.*$//g' /opt/nagios/etc/objects/commands.cfg    && \
    sed -i 's/^.*command_line.*Service Alert.*$//g' /opt/nagios/etc/objects/commands.cfg && \
    sed -i '/notify-host-by-email/a command_line /usr/bin/printf "%b" "Subject: $NOTIFICATIONTYPE$ Host Alert: $HOSTNAME$ is $HOSTSTATE$\\nFrom: System Monitor <'"${NAGIOS_ADMIN_EMAIL}"'>\\n\\n***** Nagios *****\\n\\nNotification Type: $NOTIFICATIONTYPE$\\nHost: $HOSTNAME$\\nState: $HOSTSTATE$\\nAddress: $HOSTADDRESS$\\nInfo: $HOSTOUTPUT$\\n\\nDate/Time: $LONGDATETIME$\\n" | /usr/sbin/sendmail -v $CONTACTEMAIL$' ${NAGIOS_HOME}/etc/objects/commands.cfg  && \
    sed -i '/notify-service-by-email/a command_line /usr/bin/printf "%b" "Subject: $NOTIFICATIONTYPE$ Service Alert: $HOSTALIAS$/$SERVICEDESC$ is $SERVICESTATE$\\nFrom: System Monitor <'"${NAGIOS_ADMIN_EMAIL}"'>\\n\\n***** Nagios *****\\n\\nNotification Type: $NOTIFICATIONTYPE$\\n\\nService: $SERVICEDESC$\\nHost: $HOSTALIAS$\\nAddress: $HOSTADDRESS$\\nState: $SERVICESTATE$\\n\\nDate/Time: $LONGDATETIME$\\n\\nAdditional Info:\\n\\n$SERVICEOUTPUT$\\n" | /usr/sbin/sendmail -v $CONTACTEMAIL$' ${NAGIOS_HOME}/etc/objects/commands.cfg

RUN sed -i "s/nagios@localhost/${NAGIOS_ADMIN_EMAIL}/g" ${NAGIOS_HOME}/etc/objects/contacts.cfg
RUN awk '/service_description             SSH/{for(x=NR-3;x<=NR+3;x++)d[x];}{a[NR]=$0}END{for(i=1;i<=NR;i++)if(!(i in d))print a[i]}' ${NAGIOS_HOME}/etc/objects/localhost.cfg > /tmp/new_local_cfg.tmp && mv /tmp/new_local_cfg.tmp ${NAGIOS_HOME}/etc/objects/localhost.cfg

RUN chown -R ${NAGIOS_USER}.${NAGIOS_GROUP} ${NAGIOS_HOME}    && \
    chmod g+rwx ${NAGIOS_HOME}/var/rw			      && \
    chmod g+s ${NAGIOS_HOME}/var/rw

RUN mkdir ${NAGIOS_HOME}/etc/groups                           && \
    echo "cfg_dir=${NAGIOS_HOME}/etc/groups" >> ${NAGIOS_HOME}/etc/nagios.cfg

# Backup original configuration

ADD overlay /
RUN mkdir -p /orig/apache2                        && \
    cp -pr /etc/apache2/*  /orig/apache2          && \
    cp -pr ${NAGIOS_HOME}/etc  /orig              && \
    cp -pr ${NAGIOS_HOME}/var  /orig

RUN dos2unix /etc/ssmtp/ssmtp.conf                && \
    chgrp ${NAGIOS_GROUP} /etc/ssmtp/ssmtp.conf   && \
    chmod 640 /etc/ssmtp/ssmtp.conf               && \
    : '# Add mail symbolic links to ssmtp'        && \
    ln -s $(which ssmtp) /bin/mail                && \
    ln -s $(which ssmtp) /usr/sbin/mail
RUN cp -pr /etc/ssmtp /orig

# setup CUSTOM monitoring
RUN mkdir -p ${MONITOR_KEY_DIR}                                   && \
    ssh-keygen -t rsa -b 4096 -N "" -C "Nagios-Monitor-Server"       \
            -f ${MONITOR_KEY_DIR}/monitor_key                     && \
    chmod 700 ${MONITOR_KEY_DIR}                                  && \
    chmod 600 ${MONITOR_KEY_DIR}/*                                && \
    chown -R ${NAGIOS_USER}.${NAGIOS_GROUP} ${MONITOR_KEY_DIR}    && \
    mkdir /orig/ssh                                               && \
    cp -pr ${MONITOR_KEY_DIR}/* /orig/ssh

#Ports and Volumes
WORKDIR ${NAGIOS_HOME}

EXPOSE 80

VOLUME "${NAGIOS_HOME}/var" "${NAGIOS_HOME}/etc" "/var/log/apache2" "/opt/Custom-Nagios-Plugins" "${MONITOR_KEY_DIR}"

# create initial config
RUN ${NAGIOS_HOME}/bin/nagios -v ${NAGIOS_HOME}/etc/nagios.cfg

# start up nagios, apache
CMD ["/usr/bin/supervisord"]

