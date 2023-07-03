# Appservices integration with [matrix-org/synapse](https://github.com/matrix-org/synapse) 

## Prerequisites

Before proceeding with the integration, ensure you have the following prerequisites set up:

- **Kubernetes**: Make sure you have Kubernetes installed and configured on your system to be able to communicate using `kubectl`. If you haven't installed Kubernetes yet, follow the [official Kubernetes documentation](https://kubernetes.io/docs/setup/) for installation instructions.

- **kubectl**: Ensure that you have `kubectl` installed on your system. `kubectl` is a command-line tool for interacting with Kubernetes clusters. If you haven't installed `kubectl` yet, refer to the [official Kubernetes documentation](https://kubernetes.io/docs/tasks/tools/) for installation instructions.

- **Helm**: Ensure that you have Helm installed on your system. Helm is required for managing applications on Kubernetes clusters. If you haven't installed Helm yet, refer to the [official Helm documentation](https://helm.sh/docs/intro/install/) for installation instructions.

<hr />

## Note

Please customize the default domain in this guide, `openearth.space`, to match your specific requirements.

Remember, appservices will **not** work properly in end-to-end encrypted rooms.

You can specify namespaces and other values in `config/config.sh`.

## Table of Contents
- [Element installation](#element-installation)
  - [Element TLS setup](#element-tls-setup)
- [Synapse installation](#synapse-installation)
  - [ Blank installation with hookshot ](#blank-installation-with-hookshot)
  - [ Adding hookshot to already existing synapse ](#adding-hookshot-to-already-existing-synapse)
- [Hookshot](#hookshot)
  - [Basic installation](#basic-installation)
  - [Update existing hookshot](#update-hootshots-config-on-kubernetes)

<hr />

## Element Installation

For element installation edit `/config/element-web.yaml ` and run:

```
make install_element_web
```

<hr />

### Element TLS Setup

In order to add tls to your **element web** you have to follow theses steps:

1.  Edit `/config/tls-secret.yaml`

2.  In `config/element-web.yaml` ingress's hosts section fill tls like this:
    ```yaml
    tls:
        - secretName: element-tls-secret # This must match secretName from tls-secret.yaml
        hosts:
            -  chat.openearth.space  # This url must match actual domain or subdoamin url
    ```

3.  Execute:

   ```
   make tls_update
   ```

<hr />

## Synapse Installation

To run a federating Matrix server, you need to have a publicly accessible subdomain that Kubernetes has an ingress on.
You will also require some federation guides, either in the form of a .well-known/matrix/server server or as an SRV record in DNS.
When using a well-known entry, you will need to have a valid cert for whatever subdomain you wish to serve Synapse on.
When using an SRV record, you will additionally need a valid cert for the main domain that you're using for your MXIDs.

### Blank installation with hookshot

To integrate [matrix-hookshoot](https://github.com/matrix-org/matrix-hookshot) to [matrix-org/synapse](https://github.com/matrix-org/synapse) from scratch, follow these steps:

1. Edit `/config/synapse.yaml` as you want, but make sure to leave the following configurations:

   ```yaml
   extraConfig:
     app_service_config_files:
       - /synapse/config/appservices/registration.yml
   ```

   and

   ```yaml
   extraVolumes:
      - name: appservices
      configMap:
         name: registration-hookshot
   extraVolumeMounts:
      - name: appservices
      mountPath: /synapse/config/appservices

   ```

2. Execute:

   ```
   make install_synapse_blank
   ```

   Please ensure that you have the necessary access and permissions to perform the installation process.

   Keep in mind synapse server initialization make take some time.

<hr />

### Adding hookshot to already existing synapse

> Before proceeding with the Synapse update, please ensure that you have already created the hookshot registration by running :  `make check_hookshot_registration_file`

To update an already running Synapse server in Kubernetes, follow these steps:

1. Retrieve the current `configmap` and `deployment` file from the running Synapse deployment in Kubernetes:

   ```bash
      kubectl get configmap matrix-synapse -n default -o yaml > configMap.yaml
      kubectl get deployment  matrix-synapse  -n default  -o yaml > deployment.yaml
   ```
   > Change default to match namespace where synapse server is.
   > Change 1st matrix-synapse to match your configmap for synapse server and 2nd matrix-synapse to synapse server deployment name.

2. Open the `configMap.yaml` file and add the following lines in homeserver.yaml:

   ```yaml
   app_service_config_files:
     - /synapse/config/hookshot/registration.yml
   ```

3. Open `deployment.yaml`
   Find `volumes` value and add:

   ```yaml
      - configMap:
          defaultMode: 420
          name: registration-hookshot
        name: hookshot
   ```

   Find `volumeMounts` value and add:

   ```yaml
        - mountPath: /synapse/config/hookshot
          name: hookshot
   ```

   Remember to not cause any syntax errors

4. Apply updated files to the Kubernetes cluster by running:
   ```bash
      kubectl apply -f configMap.yaml --force
      kubectl apply -f deployment.yaml --force
   ```
5. Verify the status of the update by checking the rollout status of the deployment:

   ```bash
    kubectl rollout restart deployment matrix-synapse -n default
   ```
   > Change default to match namespace where synapse server is.

Please ensure that you have the necessary access and permissions to perform the update process.

<hr>

## Hookshot

### Basic installation

1. Open `config/hookshot` folder and edit files inside as needed.

2. Execute:
   ```
   make install_hookshot
   ```

Keep in mind that hookshot need some time to start responding or joining rooms

> For more detailed setup instructions, refer to the [official guide](https://matrix-org.github.io/matrix-hookshot/latest/setup.html).

<hr>

### Update hootshot's config on kubernetes

If you already have hookshot working fine on kubernetes and want to updated config, registration file, passkey or githubKey, follow these steps:

1. Create an empty folder to store the extracted files.

2. In created folder retrieve the hookshot config map using the following command:

   ```bash
   kubectl get configmap hookshot-config -o json > hookshot-config.json
   ```
   > Where `hookshot-config` is config map used by hookshot
3. Separate the contents of the config map into matching files by executing the following script:

   ```bash
   cat hookshot-config.json | jq -r '.data | keys[]' | while read -r key; do
   cat hookshot-config.json | jq -r --arg key "$key" '.data[$key]' > "./$key"
   done
   ```

4. Edit files as you want

5. To updated config map run:
   ```bash
   kubectl create configmap hookshot-config --from-file=config.yml --from-file=registration.yml --from-file=passkey.pem --from-file=githubKey.pem -o yaml --dry-run=client | kubectl replace -f -
   ```
   > Delete `--from-file=githubKey.pem` if you haven't enabled github in config file.
6. Rerun hookshot's deployment, by using the following command:

   ```bash
   kubectl rollout restart deployment matrix-hookshot
   ```
