# Deployment script for demo/PoC Confluent cluster

Please note this is not suitable for production or any use involving data for which you are responsible.  It is not (yet) fully secured.

To deploy a cluster

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
