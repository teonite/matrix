<!--
   This section contains badges, but they do not function in private repositories.

[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]

[contributors-shield]: https://img.shields.io/github/contributors/teonite/matrix.svg?style=for-the-badge
[contributors-url]: https://github.com/teonite/matrix/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/teonite/matrix.svg?style=for-the-badge
[forks-url]: https://github.com/teonite/matrix/network/members
[stars-shield]: https://img.shields.io/github/stars/teonite/matrix.svg?style=for-the-badge
[stars-url]: https://github.com/teonite/matrix/stargazers
[issues-shield]: https://img.shields.io/github/issues/teonite/matrix.svg?style=for-the-badge
[issues-url]: https://github.com/teonite/matrix/issues
-->

<br />

<div align="center">

   <h3 align="center">Appservices integration with <a href="https://github.com/matrix-org/synapse">synapse</a></h3>

   <p align="center">
   This repository provides a simplified setup for <a href="https://github.com/vector-im/element-web">element-web</a> and <a href="https://github.com/matrix-org/synapse">synapse</a> with appservices. 
    <br />
   </p>

   <p align="right">
      <a href="https://github.com/teonite/matrix/issues/new">Request Feature</a>
      ·
      <a href="https://github.com/teonite/matrix/issues/new">Report Bug</a>
   </p>

</div>

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#about-the-repository">About the Repository</a></li>
    <li><a href="#prerequisites">Prerequisites</a></li>
    <li><a href="#getting-started">Getting Started</a></li>
    <li>
      <a href="#element-installation">Element-web Installation</a>
      <ul>
        <li><a href="#installing-element-web-separately">Installing element-web separately</a></li>
      </ul>
    </li>
    <li>
      <a href="#synapse-installation">Synapse</a>
      <ul>
        <li><a href="#updating-an-already-existing-synapse-server-with-new-appservices">Updating an already existing synapse server with new appservices</a></li>
        <li><a href="#installing-matrix-hookshot">Installing hookshot</a></li>
        <li><a href="#installing-mautrix-telegram">Installing Mautrix Telegram</a></li>
      </ul>
    </li>
    <li>
      Updating configuration of already running appservices
      <ul>
        <li><a href="#updating-running-matrix-hookshot-config">Updating running matrix-hookshot config</a></li>
        <!-- <li><a href="#updating-running-mautrix-telegram-config">Updating running mautrix-telegram config</a></li> -->
      </ul>
    </li>
  </ol>
</details>

## About the repository

The purpose of this repository is to provide an **easy** way to **automate** the launch process using a combination of [element-web](https://github.com/vector-im/element-web), [synapse server](https://github.com/matrix-org/synapse), [matrix-hookshot](https://github.com/matrix-org/matrix-hookshot) and [mautrix-telegram](https://github.com/mautrix/telegram). This project was designed specifically to meet the needs of the [OpenEarth.Space](https://openearth.space) project.

The repository contains configurations and instructions for integrating the aforementioned application services, allowing external services to interact with the Matrix network. This enables automation of various tasks and workflows.

Using this repository, users can effortlessly configure and set up the necessary components to automate the process of running the Synapse server and all related application services.

We utilized [Defguard](https://defguard.net/) as our OpenID Connect provider. For further information on its usage and setup instructions, please refer to their [documentation](https://defguard.gitbook.io/defguard/).

<br>

## Prerequisites

Before integrating, ensure you have the following prerequisites:

- **kubectl**: Install kubectl, the command-line tool for Kubernetes clusters. Refer to the [official kubectl documentation](https://kubernetes.io/docs/tasks/tools/#kubectl) for instructions.

- **Kubernetes**: Install and configure Kubernetes using `kubectl`. Refer to the [official Kubernetes documentation](https://kubernetes.io/docs/setup/) for instructions.

- **Helm**: Install Helm for managing applications on Kubernetes clusters. Refer to the [official Helm documentation](https://helm.sh/docs/intro/install/) for instructions.

<br>

## Getting Started

To begin, you don't necessarily need to modify any variables inside the `config/config.sh` file, but in most cases, it is recommended to consider changing the namespace and cluster name.

Follow the steps below to get started:

1. Run the `make init` command to create configuration files from templates. 

2. Configure the files inside the `config/` directory.

   > **NOTE:** In the files provided in the `config/` directory, make sure to replace all instances of the **openearth.space** domain with your domain name.

3. After configuring the files, if you want a full setup, execute the following command:

   ```bash
   make install_full
   ```

   This command will install element-web and synapse server with all appservices.

<br>

If you want to install appservices to an existing Synapse server, only install Element Web, or solely install the Synapse server, please refer to the appropriate sections below:

- [element-web](#installing-element-web-separately)
- [synapse](#synapse-installation)
- [matrix-hookshot](#installing-matrix-hookshot)
- [mautrix-telegram](#installing-mautrix-telegram)

<br>

## Installing element-web separately

To install Element Web separately, follow these straightforward steps after ensuring that the namespace and cluster_name in the `config/config.sh` file align with your specific requirements:

1. Run the `make init` command to generate the element-web configuration file.

2. Edit the values inside `config/element-web.yaml`.

3. Execute the following command:

   ```bash
   make install_element_web
   ```

   This command will initiate the installation of element-web, by default element-web will create ingress on ***chat.openearth.space***.

<br>

## Synapse Installation

To operate a federating Matrix server, you must have a publicly accessible subdomain with a Kubernetes ingress (which will be automatically created). If you intend to utilize a well-known entry, you must obtain a valid certificate for the desired subdomain to serve Synapse. Furthermore, if you opt for an SRV record, you will need a valid certificate for the main domain used for your MXIDs.

<br>

If you wish not to install appservices with synapse server, follow those steps:

1. Run the `make init` command to generate the necessary configuration files.

2. Edit `/config/synapse.yaml` and ensure the removal of any undesired app services configuration file paths and volumes contained within.

3. Execute the following command:

   ```bash
   make install_synapse
   ```

   > _**NOTE:**_ Additional configuration and setup may be required based on your specific requirements.

<br>

## Updating an already existing synapse server with new appservices

   To update an existing Synapse server with new app services, you need to add the following lines to your Matrix-Synapse config map.

   1. Begin by running `make init`. Modify the files within the `/config/` directory, excluding `element-web.yaml` and `synapse.yaml`. Remember to adjust the values in `config.sh` to match your Kubernetes setup.

   2. Access the kubernetes dashboard and locate the Synapse server config map. In the `homeserver.yaml` value, incorporate the following lines:


      ```yaml
         app_service_config_files:
            - /synapse/config/hookshot/registration.yml
            - /synapse/config/telegram/registration.yml
      ```

      If you desire your app services to function in end-to-end encrypted rooms, include the subsequent lines:   
      
      ```yaml
         experimental_features:
            msc2409_to_device_messages_enabled: true
            msc3202_device_masquerading: true
            msc3202_transaction_extensions: true
      ```


   2. Open the Synapse server deployment file within the kubernetes dashboard. Locate the `volumes` section and append:

      ```yaml
         - configMap:
            defaultMode: 420
            name: registration-hookshot
         name: hookshot
         - configMap:
            defaultMode: 420
            name: registration-telegram
         name: telegram
      ```

      Find the `volumeMounts` section and include:

      ```yaml
         - mountPath: /synapse/config/hookshot
            name: hookshot
         - mountPath: /synapse/config/telegram
            name: telegram
      ```

   Ensure that no syntax errors are introduced.

   3. Execute  `make update_synapse_server`.

<br>

## Installing matrix-hookshot

   Make sure your synapse server is running before installing matrix-hookshot. If it's not running, refer to [this section](#synapse-installation) for instructions.

   To match your Kubernetes setup, modify the values in `/config/config.sh` and then run `make init`. 

1. Open `config/hookshot` folder and edit files inside as needed.

2. Execute:
   ```
   make install_hookshot
   ```

3. Access the Kubernetes dashboard and find the config map for the Synapse server. Add the following lines to the homeserver.yaml value:

      ```yaml
         app_service_config_files:
            - /synapse/config/hookshot/registration.yml
      ```

      If you desire hookshot to function in end-to-end encrypted rooms, include the subsequent lines:   
      
      ```yaml
         experimental_features:
            msc2409_to_device_messages_enabled: true
            msc3202_device_masquerading: true
            msc3202_transaction_extensions: true
      ```


4. Open the Synapse server deployment file within the kubernetes dashboard. Locate the `volumes` section and append:

      ```yaml
         - configMap:
            defaultMode: 420
            name: registration-hookshot
         name: hookshot
      ```

      Find the `volumeMounts` section and include:

      ```yaml
            - mountPath: /synapse/config/hookshot
               name: hookshot
      ```

      Ensure that no syntax errors are introduced.

Keep in mind that hookshot need some time to start responding or joining rooms

> For more detailed setup instructions, refer to the [official guide](https://matrix-org.github.io/matrix-hookshot/latest/setup.html).

</details>

<br>

## Installing mautrix-telegram


   Make sure your synapse server is running before installing matrix-hookshot. If it's not running, refer to [this section](#synapse-installation) for instructions.

   To match your Kubernetes setup, modify the values in `/config/config.sh` and then run `make init`. 

1. Open `config/telegram` folder and edit files inside as needed.

2. Execute:
   ```
   make install_telegram
   ```

3. Access the Kubernetes dashboard and find the config map for the Synapse server. Add the following lines to the homeserver.yaml value:

      ```yaml
         app_service_config_files:
            - /synapse/config/telegram/registration.yml
      ```

      If you desire mautrix-telegram to function in end-to-end encrypted rooms, include the subsequent lines:   
      
      ```yaml
         experimental_features:
            msc2409_to_device_messages_enabled: true
            msc3202_device_masquerading: true
            msc3202_transaction_extensions: true
      ```


4. Open the Synapse server deployment file within the kubernetes dashboard. Locate the `volumes` section and append:

      ```yaml
         - configMap:
            defaultMode: 420
            name: registration-telegram
         name: telegram
      ```

      Find the `volumeMounts` section and include:

      ```yaml
            - mountPath: /synapse/config/telegram
               name: telegram
      ```

      Ensure that no syntax errors are introduced.



<br>

## Updating running matrix-hookshot config

   Updating already running matrix-hookshot config is straight forward:

   1. Execute `make pull_hookshot_config`
   2. Edit files inside `/temp/` directory
   3. Execute `make update_hookshot_config`

<br>

<hr>

<p align="center">
   <a href="https://github.com/teonite/matrix/issues/new">Request Feature</a>
   ·
   <a href="https://github.com/teonite/matrix/issues/new">Report Bug</a>
</p>
<hr>
