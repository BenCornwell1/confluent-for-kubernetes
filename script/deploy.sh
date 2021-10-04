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

# Copy config file to new file to avoid corrupting the old one
cp $filename deployed-$filename
filename=deployed-$filename

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
if [ -d operatorTemp ]
then
    rmdir operatorTemp
fi

mkdir operatorTemp
cd operatorTemp

if [ -f newFile.yaml ]
then
    rm newFile.yaml
fi

# Split up the config file
index=0
fileContent=$(i=$index yq eval 'select(di == env(i))' ../$filename)

while [ ! -z "${fileContent// }" ]
do
    type=$(i=$index yq eval 'select(di == env(i)) | .kind' ../$filename)
    echo Making file $type.yaml
    echo "$fileContent" > $type.yaml

    ((index=index+1))
    fileContent=$(i=$index yq eval 'select(di == env(i))' ../$filename)

done

# Change the route prefix for the Kafka brokers
yq eval -i ".spec.listeners.externalAccess.route.brokerPrefix = \"kafka-$namespace-\"" Kafka.yaml
yq eval -i ".spec.listeners.externalAccess.route.bootstrapPrefix = \"kafka-$namespace\"" Kafka.yaml

# Change the route prefix for the other components
for component in ControlCenter SchemaRegistry Connect KSQLDB
do
    file="$component".yaml
    lowercaseComponent=$(echo $component | tr '[:upper:]' '[:lower:]')
    yq eval -i ".spec.dependencies.kafka.bootstrapEndpoint = \"kafka.$namespace.svc.cluster.local:9071\"" $file
done

# Cofigure component endpoints in Control Center
if [ -e ControlCenter.yaml ]
then
    if [ -e Connect.yaml ]
    then
        yq eval -i ".spec.dependencies.connect.[0].url = \"https://connect.$namespace.svc.cluster.local:8083\"" ControlCenter.yaml      
    fi

    if [ -e SchemaRegistry.yaml ]
    then
        yq eval -i ".spec.dependencies.schemaRegistry.url = \"https://schemaregistry.$namespace.svc.cluster.local:8081\"" ControlCenter.yaml
    fi

    if [ -e KsqlDB.yaml ]
    then
        yq eval -i ".spec.dependencies.ksqldb.[0].url = \"https://ksqldb.$namespace.svc.cluster.local:8088\"" ControlCenter.yaml
    fi
fi

# Add basic auth to the schema registry and the dependency in C3, but not the others as it's not yet supported
yq eval -i ".spec.authentication.type = \"basic\"" SchemaRegistry.yaml
yq eval -i ".spec.authentication.basic.secretRef = \"sr-listener\"" SchemaRegistry.yaml
yq eval -i ".spec.dependencies.schemaRegistry.authentication.type = \"basic\"" ControlCenter.yaml
yq eval -i ".spec.dependencies.schemaRegistry.authentication.basic.secretRef = \"c3-sr\"" ControlCenter.yaml

# Replace the namespace element in each file and then cat them to the temp file
index=0
for file in *.yaml
do
    echo File = $file
    yq eval -i ".metadata.namespace = \"$namespace\"" $file

    if [ ! $index -eq 0 ]
    then
        echo "---" >> newFile.yaml
    fi

    cat $file >> newFile.yaml

    ((index=index+1))
done

cp newFile.yaml ../$filename
cd ..

# Tidy up
rm -rf operatorTemp

oc apply -f ./$filename

echo Trust store created: confluent-$namespace.p12, password is password
