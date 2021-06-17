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

./create-secrets.sh $namespace $kafkaUser $kafkaPass $c3User $c3Pass

kubectl apply -f ./$filename

