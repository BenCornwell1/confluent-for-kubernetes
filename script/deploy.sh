#!/bin/bash

namespace=$1
domain=$2
filename=$3
kafkaUser=$4
kafkaPass=$5
c3User=$6
c3Pass=$7

if [ -z $namespace ] || [ -z $domain ] || [ -z $filename ] || [ -z $kafkaUser ] || [ -z $kafkaPass ] || [ -z $c3User ] || [ -z $c3Pass ]
then
    echo "Usage: deploy.sh <namespace for deployment> <cluster domain> <config yaml> <kafka username> <kafka password> <c3 username> <c3 password>"
    exit 1
fi

oc new-project $namespace
oc project $namespace
oc adm policy add-scc-to-group privileged system:serviceaccounts:$namespace

# Check if helm repo exists
if  helm repo list | grep -q "confluentinc" 
then
    echo Repo installed, skipping
else
    echo Repo not installed, installing
    helm repo add confluentinc https://packages.confluent.io/helm
    helm repo update
fi

helm upgrade --install operator confluentinc/confluent-for-kubernetes

if [ -z $(oc get secret ca-pair-sslcerts --ignore-not-found=true |grep -q ca-pair-sslcerts) ] 
then
    if [ ! -e certs/confluentCA.pem ] && [ ! -e certs/confluentCA.key ]
    then
        echo Creating CA certificate and key
        ./create-ca.sh
    fi

    echo "Creating secret for CA cert and key"
    oc create secret tls ca-pair-sslcerts \
        --cert=certs/confluentCA.pem \
        --key=certs/confluentCA.key
fi

# Set up credentials
mkdir temp

# Simple credential file for Kafka user
echo "username=$kafkaUser" > temp/kafka-plain.txt
echo "password=$kafkaPass" >> temp/kafka-plain.txt

# JSON digest file format for Kafka user
echo "{" > temp/digest.json
echo "  \"$kafkaUser\": \"$kafkaPass\"" >> temp/digest.json
echo "}" >> temp/digest.json

# Basic client auth Kafka creds
echo "$kafkaUser: $kafkaPass" > temp/kafka-basic.txt

# Admin Kafka client creds
echo "$kafkaUser: $kafkaPass,admin" > temp/kafka-roles.txt

# C3 user login
echo "$c3User: $c3Pass,Administrators" > temp/c3-user.txt

# Metric reporter
echo "username=operator" > temp/metric-cred.txt
echo "password=operator-secret" >> temp/metric-cred.txt

# Now create the secrets from these files

# Kafka and Zookeeper

# Kafka listener
oc create secret generic zookeeper-listener \
    --from-file=plain.txt=temp/kafka-basic.txt

# Zookeeper listener
oc create secret generic zookeeper-listener \
    --from-file=plain.txt=temp/digest.json

# Kafka -> Zookeeper
oc create secret generic kafka-zookeeper \
    --from-file=plain.txt=temp/kafka-plain.txt

# Components connecting to Kafka

# Connect -> Kafka
oc create secret generic connect-kafka \
    --from-file=plain.txt=temp/kafka-basic.txt

# Schema Registry -> Kafka
oc create secret generic sr-kafka \
    --from-file=plain.txt=temp/kafka-basic.txt

# KSQL -> Kafka
oc create secret generic ksql-kafka \
    --from-file=plain.txt=temp/kafka-basic.txt

# Listeners for the components

# Connect listener
oc create secret generic connect-listener \
    --from-file=plain.txt=temp/kafka-basic.txt

# KSQL Listener
oc create secret generic ksql-listener \
    --from-file=plain.txt=temp/kafka-roles.txt

# SR Listener
oc create secret generic sr-listener \
    --from-file=plain.txt=temp/kafka-roles.txt

# Control Center

# User login for C3
oc create secret generic c3-user --from-file=basic.txt=temp/c3-user.txt 

# C3 -> Connect
oc create secret generic c3-connect \
    --from-file=plain.txt=temp/kafka-basic.txt

# C3 -> KSQL
oc create secret generic c3-ksql \
    --from-file=plain.txt=temp/kafka-basic.txt

# C3 -> SR
oc create secret generic c3-sr \
    --from-file=plain.txt=temp/kafka-basic.txt

oc create secret generic metric-credentials --from-file=plain.txt=temp/metric-cred.txt

rm -rf temp

kubectl apply -f ./$filename

