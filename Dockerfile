FROM     ubuntu:14.04

# ---------------- #
#   Installation   #
# ---------------- #

ENV     DEBIAN_FRONTEND noninteractive

ENV     SRC_DIR="/usr/local/src" \
        GRAPHITE_DIR="/opt/graphite" \
        GRAFANA_DIR="/opt/grafana" \
        NGINX_CONF_DIR="/etc/nginx" \
        STATSD_CONF_DIR="/etc/statsd" \
        SUPERVISOR_CONF_DIR="/etc/supervisor/conf.d" \
        COLLECTD_CONF_DIR="/etc/collectd"

# Install all prerequisites
RUN     apt-get -y install software-properties-common
RUN     add-apt-repository -y ppa:chris-lea/node.js
RUN     apt-get -y update
RUN     apt-get -y install python-django-tagging python-simplejson python-memcache python-ldap python-cairo python-pysqlite2 python-support \
                           python-pip gunicorn supervisor nginx-light nodejs git wget curl openjdk-7-jre build-essential python-dev

RUN     pip install Twisted==11.1.0
RUN     pip install Django==1.5
RUN     pip install pytz
RUN     npm install ini chokidar

# Checkout the stable branches of Graphite, Carbon and Whisper and install from there
RUN     mkdir /src
RUN     git clone https://github.com/graphite-project/whisper.git /src/whisper            &&\
        cd /src/whisper                                                                   &&\
        git checkout 0.9.x                                                                &&\
        python setup.py install

RUN     git clone https://github.com/graphite-project/carbon.git /src/carbon              &&\
        cd /src/carbon                                                                    &&\
        git checkout 0.9.x                                                                &&\
        python setup.py install


RUN     git clone https://github.com/graphite-project/graphite-web.git /src/graphite-web  &&\
        cd /src/graphite-web                                                              &&\
        git checkout 0.9.x                                                                &&\
        python setup.py install

# Install Collectd
RUN     apt-get -y install collectd collectd-utils

# Install StatsD
RUN     git clone https://github.com/etsy/statsd.git /src/statsd                                                                        &&\
        cd /src/statsd                                                                                                                  &&\
        git checkout v0.7.2

# Install Grafana
RUN     mkdir /src/grafana                                                                                    &&\
        mkdir /opt/grafana                                                                                    &&\
        wget https://grafanarel.s3.amazonaws.com/builds/grafana-2.1.3.linux-x64.tar.gz -O /src/grafana.tar.gz &&\
        tar -xzf /src/grafana.tar.gz -C /opt/grafana --strip-components=1                                     &&\
        rm /src/grafana.tar.gz


# ---------------- #
#   Expose Ports   #
# ---------------- #

# 80:   Grafana
# 8125: statsd
# 8126: statsd admin
# 2003: Graphite/text
# 2004: Graphite/pickle
# 9001: supervisord http interface
EXPOSE  80 8125 8126 2003 2004 9001

# ----------------- #
#   Configuration   #
# ----------------- #

# Configure Whisper, Carbon and Graphite-Web
ADD     ./graphite/initial_data.json ${GRAPHITE_DIR}/webapp/graphite/initial_data.json
ADD     ./graphite/local_settings.py ${GRAPHITE_DIR}/webapp/graphite/local_settings.py
ADD     ./graphite/carbon.conf ${GRAPHITE_DIR}/conf/carbon.conf
ADD     ./graphite/storage-schemas.conf ${GRAPHITE_DIR}/conf/storage-schemas.conf
ADD     ./graphite/storage-aggregation.conf ${GRAPHITE_DIR}/conf/storage-aggregation.conf
RUN     mkdir -p ${GRAPHITE_DIR}/storage/whisper
RUN     touch ${GRAPHITE_DIR}/storage/graphite.db ${GRAPHITE_DIR}/storage/index
RUN     chown -R www-data ${GRAPHITE_DIR}/storage
RUN     chmod 0775 ${GRAPHITE_DIR}/storage ${GRAPHITE_DIR}/storage/whisper
RUN     chmod 0664 ${GRAPHITE_DIR}/storage/graphite.db
RUN     cd ${GRAPHITE_DIR}/webapp/graphite && python manage.py syncdb --noinput

# Configure Grafana
ADD     ./grafana/custom.ini ${GRAFANA_DIR}/conf/custom.ini

# Add the default dashboards
RUN     mkdir ${SRC_DIR}/dashboards
ADD     ./grafana/dashboards/* ${SRC_DIR}/dashboards/
RUN     mkdir ${SRC_DIR}/dashboard-loader
ADD     ./grafana/dashboard-loader/dashboard-loader.js ${SRC_DIR}/dashboard-loader/

# Configure nginx and supervisord
ADD     ./nginx/nginx.conf ${NGINX_CONF_DIR}/nginx.conf
ADD     ./supervisord.conf ${SUPERVISOR_CONF_DIR}/supervisord.conf

# Configure statsd
ADD     ./statsd/config.js ${STATSD_CONF_DIR}/config.js
ADD     ./supervisord.conf ${SUPERVISOR_CONF_DIR}/supervisord.conf

# Configure collectd
ADD     ./collectd/collectd.conf ${COLLECTD_CONF_DIR}/collectd.conf

# -------- #
#   Run!   #
# -------- #

CMD     ["/usr/bin/supervisord"]
