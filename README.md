# Argo CD environment handling POC

This repository contains a concept suggestion for handling environments with GitOps
process and Argo CD.

Contents:

- [Local setup](#local-setup)
- [Concept](#concept)
- [References](#references)

## Local setup

In this section you can find how to test out this concept yourself on your local
machine.
In order for this to work smoothly, I recommend you to fork this repository. The start script will push to the repository as the sealed secrets example won't work otherwise for your local Kubernetes cluster. Check out [what you need to do after forking](#for-forked-repositories).

**Tools you'll need**

- kubectl (https://kubernetes.io/docs/tasks/tools/)
- helm (https://helm.sh/docs/intro/install/)
- docker (https://docs.docker.com/engine/install/)
- k3d (https://k3d.io/v5.3.0/#installation)

Once you've installed all those tools, run

```shell
./start.sh
```

This will set up a local kubernetes cluster, install Argo CD on it and set up the
Argo CD applications [for "dev"](infra/app.yaml)
and [for "prod"](infra/app.yaml).

Next, enter

```shell
kubectl port-forward service/argocd-server -n argocd 18080:443
```

to start port-forwarding to your Argo UI.

In your browser open `http://localhost:18080`. The credentials are `admin`
and `1234`.

:warning: **NEVER** run this setup on any public or exposed environment without
changing the setup of credentials!

When you're done and want to clean up, simply run

```shell
k3d cluster delete argo-cd-poc
```

to remove the whole local cluster.

### For forked repositories:

If you've forked this repository, did some changes to the code and now want to see
the changes in your local Argo CD, you'll have to change the following files:

- [infra/helm/values.yaml](infra/helm/values.yaml) => `apps.a.repoUrl`
  and `apps.b.repoUrl`
- [infra/app.yaml](infra/app.yaml) => `spec.source.repoURL`
- [infra/prod-app.yaml](infra/prod-app.yaml) => `spec.source.repoURL`

Change the repoUrls to your own git-repository.

## Concept

### Background

I noticed that the repository handling the _desired state_ for the application is
getting to big in my usual setup. The usual setup is to store all the deployment
related files inside one repository. This was my first take on GitOps with Argo CD.

### New way

In order to keep the _desired state_ repository (here the directory "infra")
minimal, keep the Helm Chart definitions with your application code.

#### How it works

For better understanding of the following section, please assume that [app-A](app-A)
, [app-B](app-B) and [infra](infra) are on separate repositories. For simplicity, I
used the same source code for _app-A_ and _app-B_ which is why
the [application source code](common-src) is outside those directories. Assume, that
the source code would normally be inside _app-A_ and _app-B_.

##### The application repositories

The application repositories contain their own Helm Chart definitions (or whatever
technology you use for deployment) next to the source code. Inside the Helm Chart,
only the default values are defined (values.yaml). There are no environment specific
values anywhere.

Example outline:
<pre>
|
+-- src
|   +-- ...
+-- helm
|   +-- templates
|   +-- Chart.yaml
|   +-- values.yaml
|
</pre>

##### The desired state repository

The desired state repository now actually only defines the _state_ of the deployment
that you want.

Inside this repository you have a Helm Chart (or what ever you like to deploy with).
The Helm Chart templates contain the Application files for your inner applications.
They reference Helm Charts on application repositories. Inside the Application files,
you can define that Helm should overwrite some values in the referenced Helm Chart.

Assuming your _(repo of app) helm/values.yaml_ looks something like this:

```yaml
app:
  tag: latest
  env:
    port: 8080
```

You can overwrite that from within your Application file _(repo of state)
helm/templates/app.yaml_:

```yaml
# ...
spec:
  source:
    helm:
      values: |
        app:
          env:
            port: 80
```

Now your application will be deployed by Argo CD with the port 80 instead of 8080.

Unfortunately, you cannot use the `spec.source.helm.valueFiles` as those are relative
to the path defined in `spec.source.path`. As we are on a completely different
repository than the path, we cannot use it. To make this hurdle a bit smaller, we can
do the following setup.

_(state repo) templates/app.yaml_

```yaml
# ...
spec:
  source:
    path: app/helm
    repoURL: { { .Values.app.repoUrl } }
    targetRevision: HEAD
    { { - with .Values.overrideValues } }
    helm:
      values: |{{ toYaml . | nindent 8 }}
    { { - end } }
  destination:
# ...
```

_(state repo) values-prod.yaml_

```yaml
app:
  repoUrl: http://some-example.git
  overrideValues:
    app:
      env:
        port: 80
```

This way it becomes a bit easier to handle the overwritten values as they're bundled
up inside the environment specific values file.

Example outline:
<pre>
|
+-- helm
|   +-- templates
|   |   +-- frontend.yaml
|   |   +-- backend.yaml
|   |   +-- what-ever-app-your-application-consists-of.yaml
|   +-- Chart.yaml
|   +-- values.yaml
|   +-- values-dev.yaml
|   +-- values-staging.yaml
|   +-- values-prod.yaml
+-- dev.yaml
+-- staging.yaml
+-- prod.yaml
|
</pre>

#### PROs

- The developer can easily change deployment configurations (e.g. new environment
  variables) without having to leave the application repository.
- The _desired state_ repository actually only contains information about the
  configuration and not the internal needs of a deployment.

#### CONs

- The only way I found to overwrite the values of inner apps (app-a/app-b) is via the
  Argo Application block file `spec.source.helm.values`. This might get confusing if
  the number of values to change is really large.

## References

| Title                                                                                 | Link                         |
|:--------------------------------------------------------------------------------------|:-----------------------------|
| Argo CD - Applying GitOps Principles To Manage A Production Environment In Kubernetes | https://youtu.be/vpWQeoaiRM4 |
