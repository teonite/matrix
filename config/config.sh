#!/bin/bash

# =====
# These configuration variables will be used when executing the makefile commands.
# ===== 

namespace="openearth" # Set this to your kubernetes deployment name, you want to have everything installed

# Element-web
element_deployment_name="element-web" # Element's deployment name
element_web_values_path="./config/element-web.yaml" # Element's values path
element_web_tls_file_path="./config/tls-secret.yaml" # Element's tls path


# Synapse
synapse_deployment_name="matrix-synapse" # Synapse's deployment name
synapse_values_path="./config/synapse.yaml"  # Synapse's values path


# Hookshot
    # registration file
    hookshot_registration_values_path="./config/hookshot/registration.yml" # Hookshot's registration file path, file name must be: registration.yml
    
    # config file
    hookshot_config_file_name="hookshot-config" # Hookshot's config file name
    hookshot_config_file_path="./config/hookshot/config.yml" # Hookshot's config file path, file name must be: config.yml
    hookshot_passkey_path="./config/hookshot/passkey.pem" # Hookshot's passkeyh, file name must be: passkey.pem ( this passkey is autogenerated )
    hookshot_githubkey_path="./config/hookshot/githubKey.pem"  # Hookshot's github key, file name must be: githubKey.pem  ( only required if hookshot github intergation is enabled )  
    
    # ingress
    hookshot_ingress_file_path="./config/hookshot/ingress.yaml" # Hookshot's ingress file

    # deployment
    hookshot_deployment_name="matrix-hookshot" # Hookshot's deployment name
    hookshot_deployment_values_file_path="./config/hookshot/values.yaml" # Hookshot's values path, file name must be: values.yaml

    # e2e volumes
    hookshot_volumes_file_path="./config/hookshot/volumes.yaml"

# Telegram
    # database, we need to connect to databse in order to create new database for telegram integration
    postgresql_admin_username="synapse" # postgresql admin username
    postgresql_admin_password="synapse" # postgresql admin password
    postgresql_telegram_database_name="mautrixtelegram" # postgresql database ( mautrix-telegram will use this database )

    postgresql_ingress_path="./config/postgresql-ingress.yaml" # postgresql's ingress file
    
    # registration file
    telegram_registration_values_path="./config/telegram/registration.yml" # mautrix-telegram's registration file path, file name must be: registration.yml
    
    # deployment
    telegram_deployment_name="mautrix-telegram" # mautrix-telegram's deployment name
    telegram_deployment_values_file_path="./config/telegram/values.yaml" # mautrix-telegram's values path, file name must be: values.yaml

# Exporting all variables so makefile can use them
export $(set -o posix; set) 
