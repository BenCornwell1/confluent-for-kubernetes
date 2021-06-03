#!/bin/bash

namespace=$1

oc project $namespace

oc delete SchemaRegistry.platform.confluent.io schemaregistry
oc delete ControlCenter.platform.confluent.io controlcenter
oc delete KsqlDB.platform.confluent.io ksqldb
oc delete Connect.platform.confluent.io connect
oc delete Kafka.platform.confluent.io kafka
oc delete Zookeeper.platform.confluent.io zookeeper

oc delete secret kafka-credentials
oc delete secret c3-credentials
