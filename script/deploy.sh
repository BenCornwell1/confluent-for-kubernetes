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

# Create and configure namespace
oc new-project $namespace
oc project $namespace
oc adm policy add-scc-to-group privileged system:serviceaccounts:$namespace

# Check if helm repo exists, if not add it
if  helm repo list | grep -q "confluentinc" 
then
    echo Repo installed, skipping
else
    echo Repo not installed, installing
    helm repo add confluentinc https://packages.confluent.io/helm
    helm repo update
fi

# Install the operator
helm upgrade --install operator confluentinc/confluent-for-kubernetes

# Create a CA
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

# Create a PKCS12 key store for the CA
keytool -keystore confluent-$namespace.p12 -storetype PKCS12 -import -file ./certs/confluentCA.pem -storepass password -noprompt

# Run the create-secrets script
./create-secrets.sh $namespace $kafkaUser $kafkaPass $c3User $c3Pass

# Edit the namespaces and route prefixes in the configuration yaml.  
# First it splits the file into its component parts, edits each one 
# then recombines them.

# Organise temp dir and files
if [ ! -d operatorTemp ]
then
    mkdir operatorTemp
fi

if [ -f operatorTemp/newFile.yaml ]
then
    rm operatorTemp/newFile.yaml
fi

# Split up the config file
index=0
fileContent=$(i=$index yq eval 'select(di == env(i))' $filename)

while [ ! -z "${fileContent// }" ]
do
    type=$(i=$index yq eval 'select(di == env(i)) | .kind' $filename)
    echo "$fileContent" > operatorTemp/$type.yaml

    ((index=index+1))
    fileContent=$(i=$index yq eval 'select(di == env(i))' $filename)

done

# Change the route prefix for the Kafka brokers
yq eval -i ".spec.listeners.externalAccess.route.brokerPrefix = \"kafka-$namespace-\"" operatorTemp/Kafka.yaml
yq eval -i ".spec.listeners.externalAccess.route.bootstrapPrefix = \"kafka-$namespace\"" operatorTemp/Kafka.yaml

# Change the route prefix for the other components
for file in "operatorTemp/ControlCenter.yaml operatorTemp/SchemaRegistry.yaml operatorTemp/Connect.yaml operatorTemp/KSQLDB.yaml"
do
    lowercaseFile="$file" | tr '[:upper:]' '[:lower:]'
    yq eval -i ".spec.listeners.externalAccess.route.brokerPrefix = \"${lowercaseFile%.*}-$namespace-\"" operatorTemp/$file
done

# Replace the namespace element in each file and then cat them to the temp file
index=0
for file in operatorTemp/*.yaml
do
    yq eval -i ".metadata.namespace = \"$namespace\"" $file

    if [ ! $index -eq 0 ]
    then
        echo "---" >> operatorTemp/newFile.yaml
    fi
    ((index=index+1))
done

# Rename the original config file and then copy the original one to a backup
if [ -f $filename.backup ]
then
    rm $filename.backup
fi

mv $filename $filename.backup
cp operatorTemp/newFile.yaml ./$filename

# Tidy up
# rm -rf operatorTemp

# kubectl apply -f ./$filename

echo Trust store created: confluent-$namespace.p12, password is password
