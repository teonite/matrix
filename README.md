# Integrate [matrix-hookshoot](https://github.com/matrix-org/matrix-hookshot) to [matrix-org/synapse](https://github.com/matrix-org/synapse) with [vector-im/element-web](https://github.com/vector-im/element-web)

## Prerequisites

Before proceeding with the integration, ensure you have the following prerequisites set up:

- **Kubernetes**: Make sure you have Kubernetes installed and configured on your system to be able to communicate using `kubectl`. If you haven't installed Kubernetes yet, follow the [official Kubernetes documentation](https://kubernetes.io/docs/setup/) for installation instructions.

- **kubectl**: Ensure that you have `kubectl` installed on your system. `kubectl` is a command-line tool for interacting with Kubernetes clusters. If you haven't installed `kubectl` yet, refer to the [official Kubernetes documentation](https://kubernetes.io/docs/tasks/tools/) for installation instructions.

- **Helm**: Ensure that you have Helm installed on your system. Helm is required for managing applications on Kubernetes clusters. If you haven't installed Helm yet, refer to the [official Helm documentation](https://helm.sh/docs/intro/install/) for installation instructions.

<hr />

## Note
Please customize the default domain in this guide, `openearth.space`, to match your specific requirements.

## Table of Contents

- [Element installation](#element-installation)
  - [Element TLS setup](#element-tls-setup)
- [Synapse installation](#synapse-installation)
  - [ Blank installation with hookshot ](#blank-installation-with-hookshot)
  - [ Adding hookshot to already existing synapse ](#adding-hookshot-to-already-existing-synapse)
- [Hookshot](#hookshot)
  - [Basic installation](#basic-installation)
  - [Update existing hookshot](#update-hootshots-config-on-kubernetes)
  - [Configuration](#hookshot-configuration):
    - [Registration config map](#hookshot-registration-config-map)
    - [Config map](#hookshot-config-map)
    - [values.yaml configuration](#change-valuesyaml)
   -  [Hookshot ingress](#hookshot-ingress)

<hr />

## Element Installation

For element installation follow theses steps:

1. Open `element-web` folder and run
   ```bash
   cp ./values.yaml.example ./values.yaml
   ```
2. Open and fill fields inside `values.yaml`  depending on your needs.

   Make sure `defaultServer.url` uses correct protocol.

   > If you need TLS (HTTPS) support for your ingress, follow [these steps](#element-tls-setup)

3. Run:

   ```bash
   helm install element-web . --values=values.yaml
   ```

### Element TLS Setup

In order to add tls to your **element web** you have to follow theses steps:

1.  Open `tls-setup` folder, and run:
    ```bash
    cp ./tls-secret.yaml.example ./tls-secret.yaml
    ```
2.  Edit tls-secret.yaml
3.  To apply secret to kubernates run:
    ```bash
    kubectl apply -f tls-secret.yaml
    ```
4.  Open `element-web/values.yaml` and in ingress's hosts section fill tls like this:
    ```yaml
    tls:
        - secretName: element-tls-secret # This must match secretName from tls-secret.yaml
        hosts:
            -  chat.openearth.space  # This url must match actual domain or subdoamin url
    ```
5.  Upgrade deployment by running in `element-web` folder:
`bash
        helm upgrade 
        element-web . --values=values.yaml
    `
<hr />

## Synapse Installation

To run a federating Matrix server, you need to have a publicly accessible subdomain that Kubernetes has an ingress on.
You will also require some federation guides, either in the form of a .well-known/matrix/server server or as an SRV record in DNS.
When using a well-known entry, you will need to have a valid cert for whatever subdomain you wish to serve Synapse on.
When using an SRV record, you will additionally need a valid cert for the main domain that you're using for your MXIDs.

### Blank installation with hookshot 

> Before synapse installation make sure you already created [hookshot registration config map](#hookshot-registration-config-map).

To integrate [matrix-hookshoot](https://github.com/matrix-org/matrix-hookshot) to [matrix-org/synapse](https://github.com/matrix-org/synapse) from scratch, follow these steps:

1. Go to the `/matrix-synapse` folder and execute the following command:

   ```bash
   cp ./values.yaml.example ./values.yaml
   ```

2. Modify the values in the `values.yaml` file according to your requirements. Make sure to leave the following configurations:

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

   > Don't forget to change **serverName** 
   You may also need to configure `ingress` inside `values.yaml`.

3. In `/matrix-synapse` folder run:

   `bash
   helm dependency build
   helm install matrix-synapse . --values=values.yaml
 `

   Please ensure that you have the necessary access and permissions to perform the installation process.

   Keep in mind synapse server initialization make take some time.

### Adding hookshot to already existing synapse

> Before proceeding with the Synapse update, please ensure that you have already created the [hookshot registration config map](#hookshot-registration-config-map).

To update an already running Synapse server in Kubernetes, follow these steps:

1. Retrieve the current `values.yaml` file from the running Synapse deployment in Kubernetes: ```bash
   kubectl get configmap matrix-synapse -o yaml > values.yaml
   ```
   This command fetches the values.yaml file stored as a ConfigMap in Kubernetes and saves it locally.
   ```
2. Open the `values.yaml` file and add the following configurations:

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

3. Apply the updated values.yaml file to the Kubernetes cluster:
   ```bash
   kubectl apply -f values.yaml
   ```
4. Upgrade the Synapse deployment to apply the configuration changes:
   ```bas
   helm upgrade matrix-synapse . --values=values.yaml
   ```
5. Verify the status of the update by checking the rollout status of the deployment:
`bash
    kubectl rollout status deployment matrix-synapse
    `
Please ensure that you have the necessary access and permissions to perform the update process.
<hr>

## Hookshot

### Basic installation

1. If you haven't already, create a [Hookshot registration file](#hookshot-registration-config-map).
2. Create the [Hookshot config map](#hookshot-config-map).
3. [Modify values in `values.yaml`](#change-valuesyaml).
4. Configure [Hookshot ingress](#hookshot-ingress) if needed.
5. Run the following command in the `matrix-hookshot/chart/` directory:
   ```bash
   helm install matrix-hookshot . --values=values.yaml
   ```

Keep in mind that hookshot need some time to start responding or joining rooms

> For more detailed setup instructions, refer to the [official guide](https://matrix-org.github.io/matrix-hookshot/latest/setup.html).

<hr>

## Hookshot Configuration

### Hookshot Registration Config Map

To create a Hookshot registration, follow these steps:

1. Open the `matrix-hookshot/config/` directory and execute the following command:

   ```bash
       cp ./registration.yml.example registration.yml
   ```

2. Edit the `registration.yml` file. If you have any questions, consult the [official configuration guide](https://matrix-org.github.io/matrix-hookshot/latest/setup.html#configuration).
   > Remember to ensure that the `url` value matches the selected Hookshot URL in the `config.yaml` file (default port: 9002).

To create a registration map for the Synapse server, run the following command:

```bash
kubectl create configmap registration-hookshot --from-file=registration.yml
```

### Hookshot config map

To set up Hookshot config map, follow these steps:

0. If you haven't already done so, create the [registration file](#hookshot-registration-config-map).

1. Open `matrix-hookshot/config/` folder and execute the following command::

   ```bash
       cp ./config.yml.example config.yml
   ```

2. Edit `config.yml` file.
   Make sure `url` and `mediaURL` uses correct protocol.

   > The url in the configuration must match the Synapse server URL.

3. Generate a passkey by running the following command:
   ```bash
   openssl genpkey -out passkey.pem -outform PEM -algorithm RSA -pkeyopt rsa_keygen_bits:4096
   ```

4. (Optional) If you have enabled **GitHub** integration in the `config.yml` file, create a `githubKey.pem` file and paste your generated GitHub passkey there. If something is unclear read [this](https://matrix-org.github.io/matrix-hookshot/latest/setup/github.html#bridge-configuration).

5. Run the following command:
   ```bash
   kubectl create configmap hookshot-custom-config --from-file=config.yml --from-file=registration.yml --from-file=passkey.pem --from-file=githubKey.pem
   ```
   > Delete `--from-file=githubKey.pem` if you haven't enabled github in `config.yaml`

### Change values.yaml

To configure matrix-hookshot to work on Kubernetes, you need to modify the values. Follow these steps: 

0. If you haven't already created the [hookshot's config map](#hookshot-config-map), do it now.

1. Open `matrix-hookshot/chart` directory, and execute:
   ```bash
   cp ./values.yaml.example ./values.yaml
   ```

2. Open `values.yaml` and locate the `existingConfigMap` value inside the `values.yaml` file and set it to the name of the created hookshot config map.Delete raw config value in `values.yaml`

   Example:

   ```diff
   hookshot:
   +  existingConfigMap: hookshot-custom-config
   -   # -- Raw Hookshot configuration. Gets templated into a YAML file and then loaded unless an existingConfigMap is specified.
   -  config:
   -    bridge:
   -      # Basic homeserver configuration
   -      #
   -      domain: example.com
   -      url: http://localhost:8008
   -      ...
   -      ...
   -    sender_localpart: hookshot
   -   url: "http://example.com"
   -    rate_limited: false
   -  passkey: ""
   ```

### Hookshot ingress

1. Open `/matrix-hookshot/ingress` folder, and execute:
   ```bash
   cp ./ingress.yaml.example ./ingress.yaml
   ```
2. Change values inside file.

3. Execute:
   ```
   kubectl apply -f ingress.yaml
   ```


### Update hootshot's config on kubernetes

If you already have hookshot working fine on kubernetes and want to updated config, registration file, passkey or githubKey, follow these steps:

1. Create an empty folder to store the extracted files.

2. In created folder retrieve the hookshot config map using the following command:

```bash
kubectl get configmap hookshot-custom-config -o json > hookshot-config.json
```

3. Separate the contents of the config map into matching files by executing the following script:

```bash
cat hookshot-config.json | jq -r '.data | keys[]' | while read -r key; do
  cat hookshot-config.json | jq -r --arg key "$key" '.data[$key]' > "./$key"
done
```

4. Edit files as you want

5. To updated config map run:
   ```bash
   kubectl create configmap hookshot-custom-config --from-file=config.yml --from-file=registration.yml --from-file=passkey.pem --from-file=githubKey.pem -o yaml --dry-run=client | kubectl replace -f -
   ```
6. Rerun hookshot's deployment, by using the following command:

   ```bash
   kubectl rollout restart deployment <deployment-name>
   ```
