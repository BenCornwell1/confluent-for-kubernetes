#!/bin/bash

namespace=$1
filename=$2

cp $filename deployed-$filename
filename=deployed-$filename

if [ -f operatorTemp/newFile.yaml ]
then
    rm operatorTemp/newFile.yaml
fi
cd operatorTemp

index=0
fileContent=$(i=$index yq eval 'select(di == env(i))' ../$filename)

while [ ! -z "${fileContent// }" ]
do
    type=$(i=$index yq eval 'select(di == env(i)) | .kind' ../$filename)
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
    yq eval -i ".spec.dependencies.kafka.bootstrapEndpoint = \"${lowercaseComponent%}.$namespace.svc.cluster.local:9071\"" $file
done

if [ -e ControlCenter.yaml ]
then
    if [ -e Connect.yaml ]
    then
        yq eval -i ".spec.dependencies.connect.[0].url = \"http://connect.$namespace.cluster.svc.local:8083\"" ControlCenter.yaml      
    fi

    if [ -e SchemaRegistry.yaml ]
    then
        yq eval -i ".spec.dependencies.schemaRegistry.url = \"http://schemaregistry.$namespace.cluster.svc.local:8081\"" ControlCenter.yaml
    fi

    if [ -e KsqlDB.yaml ]
    then
        yq eval -i ".spec.dependencies.ksqldb.[0].url = \"http://ksqldb.$namespace.cluster.svc.local:8081\"" ControlCenter.yaml
    fi
fi

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

cd ..

mv operatorTemp/newFile.yaml .