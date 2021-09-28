namespace=$1
filename=$2

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