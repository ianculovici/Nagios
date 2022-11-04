#!/bin/sh

set -eu

if [ -z "$(ls -A ${NAGIOS_HOME}/etc)" ]; then
    echo "Started with empty ETC, copying example data in-place"
    cp -Rp /orig/etc/* ${NAGIOS_HOME}/etc/
fi

if [ -z "$(ls -A ${NAGIOS_HOME}/var)" ]; then
    echo "Started with empty VAR, copying example data in-place"
    cp -Rp /orig/var/* ${NAGIOS_HOME}/var/
fi

if [ "$(echo $(ls -A ${NAGIOS_HOME}/var))" = "nagios.log supervisord.log" ]; then
    echo "Started with empty VAR, copying example data in-place"
    cp -Rp /orig/var/* ${NAGIOS_HOME}/var/
    chown -R ${NAGIOS_USER}.${NAGIOS_GROUP} "${NAGIOS_HOME}/var"
fi

if [ -z "$(ls -A /etc/ssmtp)" ]; then
    echo "Started with empty SSMTP, copying example data in-place"
    cp -Rp /orig/ssmtp/* /etc/ssmtp/
fi

if [ ! -f "${NAGIOS_HOME}/etc/htpasswd.users" ] ; then
    htpasswd -c -b -s "${NAGIOS_HOME}/etc/htpasswd.users" "${NAGIOSADMIN_USER}" "${NAGIOSADMIN_PASS}"
    chown -R ${NAGIOS_USER}.${NAGIOS_GROUP} "${NAGIOS_HOME}/etc/htpasswd.users"
fi

if [ -z "$(ls -A ${MONITOR_KEY_DIR})" ]; then
    echo "Started with empty SSH, copying example data in-place"
    cp -Rp /orig/ssh/* ${MONITOR_KEY_DIR}/
fi

if [ "${NAGIOS_TIMEZONE}" != "" ] ; then
    cp /usr/share/zoneinfo/${NAGIOS_TIMEZONE} /etc/localtime && echo ${NAGIOS_TIMEZONE} > /etc/timezone
fi
