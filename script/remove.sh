#!/bin/bash

namespace=$1

if [ -z $namespace ]
then
    echo "Usage: remove.sh <confluent namespace>"
    exit 1
fi

oc project $namespace

oc delete SchemaRegistry.platform.confluent.io schemaregistry
oc delete ControlCenter.platform.confluent.io controlcenter
oc delete KsqlDB.platform.confluent.io ksqldb
oc delete Connect.platform.confluent.io connect
oc delete Kafka.platform.confluent.io kafka
oc delete Zookeeper.platform.confluent.io zookeeper

helm delete operator

secrets="zookeeper-listener \
    kafka-listener \
    kafka-zookeeper \
    connect-kafka \
    sr-kafka \
    ksql-kafka \
    connect-listener \
    ksql-listener \
    sr-listener \
    c3-user \
    c3-connect \
    c3-ksql \
    c3-sr \
    metric-credentials \
    ca-pair-sslcerts \
    kafka-tls \
    connect-tls \
    replicator-tls \
    schemaregistry-tls \
    ksqldb-tls \
    controlcenter-tls \
    zookeeper-tls"

for secret in $secrets
do
    oc delete secret $secret
done

rm confluent-$namespace.p12
