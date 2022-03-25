**DO NOT COMMIT** the clear text files like here in 'raw'. This is just for a simple setup of this POC.
Only commit sealed secrets.

The reason why I cannot commit the sealed secrets here is, that you seal the secrets with the cluster you want to use them on.
Locally you'll have a different cluster than me or every time you delete and recreate the cluster. Thus, the secrets have to be re-sealed for this POC.

If you're interested in how, check out the [start script](../../start.sh) or the [bitnami sealed secrets github](https://github.com/bitnami-labs/sealed-secrets).