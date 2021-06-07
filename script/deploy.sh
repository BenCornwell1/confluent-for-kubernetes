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
echo "username=$kafkaUser" > temp/kafka-cred.txt
echo "password=$kafkaPass" >> temp/kafka-cred.txt
echo "{" > temp/kafka-digest.json
echo "  \"$kafkaUser\": \"$kafkaPass\"" >> temp/kafka-digest.json
echo "}" >> temp/kafka-digest.json

oc create secret generic kafka-credentials \
    --from-file=plain.txt=temp/kafka-cred.txt \
    --from-file=digest-users.json=temp/kafka-digest.json \
    --from-file=plain-users.json=temp/kafka-digest.json \
    --from-file=digest.txt=temp/kafka-cred.txt

echo "$c3User: $c3Pass,Administrators" > temp/c3-cred.txt
oc create secret generic c3-credentials --from-file=basic.txt=temp/c3-cred.txt 

echo "username=operator" > temp/metric-cred.txt
echo "password=operator-secret" >> temp/metric-cred.txt
echo "operator: operator-secret,Administrators" > temp/metric-cred-basic.txt
oc create secret generic metric-credentials --from-file=plain.txt=temp/metric-cred.txt --from-file=basic.txt=temp/metric-cred-basic.txt

rm -rf temp

kubectl apply -f ./$filename

