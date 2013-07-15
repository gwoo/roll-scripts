#!/bin/bash
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Couchbase Server
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
cd /srv/src

roll.install libssl0.9.8

roll.download http://packages.couchbase.com/releases/2.0.1 ${COUCHBASE_SERVER} deb
wget -q -O- http://packages.couchbase.com/ubuntu/couchbase.key --no-check-certificate | apt-key add -

dpkg -i ${COUCHBASE_SERVER}.deb

ln -s /opt/couchbase/bin/* /usr/local/bin

couchbase-cli cluster-init -c 127.0.0.1:8091 \
  --cluster-init-username=${COUCHBASE_USERNAME} \
  --cluster-init-password=${COUCHBASE_PASSWORD} \
  --cluster-init-ramsize=${COUCHBASE_RAM}

couchbase-cli bucket-create -c 127.0.0.1:8091 \
  --bucket=${COUCHBASE_BUCKET} \
  --bucket-type=couchbase \
  --bucket-ramsize=${COUCHBASE_RAM} \
  --bucket-replica=0 \
  --user=${COUCHBASE_USERNAME} \
  --password=${COUCHBASE_PASSWORD}

update-rc.d -f couchbase-server defaults
service couchbase-server restart
echo "Couchbase Installed"
echo "Login with username:${COUCHBASE_USERNAME} and password:${COUCHBASE_PASSWORD}"