# Deployment script for demo/PoC Confluent cluster on Openshift

Please note this is not suitable for production or any use involving data for which you are responsible.  It is not (yet) fully secured.

## Essential Pre-requisites

You will need yq version 4+

## Summary
To deploy a cluster you will need to obtain the ingress domain of your Openshift cluster.

```
> deploy.sh 
    <namespace> \
    <cluster ingress domain> \
    <config yaml file> \
    <kafka username> \
    <kafka password> \
    <control centre username> \
    <control centre password>
```

To remove a cluster:

```
> oc project <namespace>
> remove.sh
```

The script creates a PKCS12 certificate store that you can use to connect your clients to the cluster.

Remove the cluster before attempting to delete the namespace, otherwise it will get stuck in terminating phase because the finalizers on the resources won't be able to run.

The Kafka username and password are used for everything except admin access to the Control Center GUI

Once the installation is complete, open the Openshift console, navigate to the 'Networking' section on the left and select 'Routes' in the namespace you specified.  Then click on the address of the 'control center bootstrap' route, and log in with the credentials you specified in the command.  If using Chrome you may have to type 'thisisunsafe' into the page that tells you you cannot visit the site - it will let you in.

__IMPORTANT__

Don't forget to log on to the Control Center after installation and change the retention period of `_confluent-metrics` )(it's a hidden internal topic) from 3 days to 3 hours otherwise the brokers will likely run out of disk space.

__ALSO IMPORTANT__

With current version (6.2) Control Center cannot talk to Connect, or KSQLDB if they are secured with basic auth.  Therefore in this installation they are deployed without auth.  If there is going to be anything remotely important on your cluster you will need to do something else to protect it - either use MTLS (not implemented in this script), create network policies or something else.  It can however use basic auth for Schema Registry, so this is configured.

## What gets deployed

All the Confluent components will be deployed:

| Component       | Nodes | Storage |
| --------------- | ----- | ------- |
| Kafka           |     3 |    10Gb |
| Zookeeper       |     3 |    10Gb |
| Control Center  |     1 |    10Gb |
| KSQLDB          |     1 |    10Gb |
| Connect         |     1 |         |
| Schema Registry |     1 |         |

These values can be edited in the config.yaml.

## What the script does - PLEASE READ

1. Creates the project specified in the command.
2. Creates a CA and SSL certificates for the external and internal communications and creates a PKCS12 certificate store for client use
3. Creates secrets for authentication between the components, for Kafka, and for the Control Center
4. Breaks up the config YAML file into individual parts for the components
5. Configures the external routes
6. Configures the internal and external listeners and their endpoints for the various components
7. Sets up the dependencies Control Center so it can talk to the components
8. Re-combines the files into one
9. Applies the resulting YAML to the cluster