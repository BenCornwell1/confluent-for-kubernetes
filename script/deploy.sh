#!/bin/bash

namespace=$1
export domain=$2
export filename=$3

if [ -z $namespace ] || [ -z $domain ] || [ -z $filename ]
then
    echo "Usage: deploy.sh <namespace for deployment> <cluster domain> <config yaml>"
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

# Update URLs for dependencies for C3
# cacerts=$(cat confluentCA.pem) xComponent=$component yq eval -i '.[env(xComponent)].tls.cacerts = strenv(cacerts)' ../$filename

# Extract all the files from the yaml in case we need to edit any of them
mkdir tempfiles
cd tempfiles
index=0
fileContent="x"

while [ ! -z fileContent ]
do    
    fileContent=yq eval 'select(di == $index)' $filename
    ((index=index+1))
done

echo "Updating URLs for dependencies for C3"

components="schemaregistry ksqldb connect"
for $component in components
do  
    url=yq eval ''


kubectl apply -f ./$filename

