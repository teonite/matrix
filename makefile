include ./config/config.sh

BLUE := \033[1;34m # Blue colour
CE := \033[0m # Colour end

default:
	@printf 'Please choose target - for assistance type: `make help`\n'

help:
	@printf "Usage: make${BLUE}[target]${CE}\n\n"
	@printf "Start by running ${BLUE}make init${CE} - this command will pull submodules and copy templates to actual files.\n"
	
	@printf "\nE L E M E N T - W E B \n"
	@printf "If you have already run ${BLUE}make init${CE}, please configure the element-web.yaml file in the config/ folder.\n"
	@printf "After configuration, run the command ${BLUE}make install_element_web${CE} to install element-web.\n\n"
	
	@printf "\nS Y N A P S E \n"
	@printf "After configuring files inside the config folder, run ${BLUE}make install_synapse_blank${CE} for Synapse installation with Hookshot and Mautrix-Telegram.\n"
# add update

	@printf "\nH O O K S H O T \n"
	@printf "After configuring files inside the config/hookshot folder, run ${BLUE}make install_hookshot${CE} for Hookshot installation.\n"
# add update

	@printf "\nM A U T R I X - T E L E G R A M \n"
	@printf "After configuring files inside the config/telegram folder, run ${BLUE}make install_telegram${CE} for mautrix-telegram installation.\n"
# add update

	@printf "\nF U L L \n"
	@printf "If you want to install everything in the fastest way, run ${BLUE}make init${CE}, configure files inside config folder and then execute ${BLUE}make install_full${CE}\n"
	@printf "\n"


# ===================
# Basic functionalities
# ===================

# make init 
# Pulling submodules and copy templates
init:
	@echo "Pulling GitHub submodules..."
	@git submodule sync --recursive
	@git submodule update --init --recursive

	@echo "Copying .yaml templates to .yaml if files do not exist..."
	@find config -type f -name '*.template' -exec sh -c 'target="$${0%.*}"; [ ! -f "$${target}" ] && cp "$${0}" "$${target}" && echo "Created $${target}"' {} \;

	@echo "Checking dependencies..."
	@make check_dependencies
	@echo "🔀 Dependencies instaled"

	@echo "Checking namespace..."
	@make check_namespace
	@echo "🌐 Namespace ready"
	
	@echo "Trying seting cluster"
	@kubectl config use-context ${cluster_name}
	@echo "🌐 Kubectl default cluster updated"

	@make generate_tokens

	@echo "🎉 Everything is set! Now edit .yaml and .yml files in config/ folder 🎉"

# make check_namespace 
# Checking if namespace exist, if not creates one
check_namespace:
	@kubectl get namespace ${namespace} > /dev/null 2>&1 || (echo "Namespace '${namespace}' does not exist, creating...";  kubectl create namespace ${namespace})

# make check_dependencies
# Checking dependencies
check_dependencies:
	@which helm > /dev/null 2>&1 || { echo "Helm command not found. Please install Helm and make sure it's in your system's PATH."; exit 1; }
	@which kubectl > /dev/null 2>&1 || { echo "Kubectl command not found. Please install Helm and make sure it's in your system's PATH."; exit 1; }
	@kubectl cluster-info > /dev/null 2>&1 || { echo "Cannot connect to Kubernetes cluster. Please make sure you have the necessary configuration and connectivity."; exit 1; }

# make check_registration_files
# Check all required registration files 
check_registration_files:
	make check_hookshot_registration_file
	make check_telegram_registration_file
	echo "📝 All registration files exists!"

# full deployments restart
restart_deployments:
	@kubectl rollout restart deployment $(synapse_deployment_name) -n $(namespace)
	@echo "😴 Waiting for Synapse to start"
	@success_count=0; \
	while true; do \
		status=$$(kubectl get deployment $(synapse_deployment_name) -n $(namespace) -o jsonpath='{.status.conditions[?(@.type=="Available")].status}'); \
		if [[ "$$status" == "True" ]]; then \
			((success_count++)); \
			if ((success_count >= 3)); then \
				echo "😁 Synapse is available"; \
				break; \
			fi; \
		else \
			success_count=0; \
		fi; \
		sleep 5; \
	done
	
	
	@make create_telegram_database
	@kubectl rollout restart deployment -n ${namespace} ${hookshot_deployment_name}
	@kubectl rollout restart deployment -n ${namespace} ${telegram_deployment_name}

# Generates as and hs tokens
generate_tokens:
	@hookshot_as_token=$$(openssl rand -hex  32 );\
    sed -i '' "s/as_token:.*/as_token: $$hookshot_as_token/" ./config/hookshot/registration.yml;\
	hookshot_hs_token=$$(openssl rand -hex  32 );\
    sed -i '' "s/hs_token:.*/hs_token: $$hookshot_hs_token/" ./config/hookshot/registration.yml;\
	telegram_as_token=$$(openssl rand -hex  32 );\
    sed -i '' "s/as_token:.*/as_token: $$telegram_as_token/" ./config/telegram/registration.yml;\
	telegram_hs_token=$$(openssl rand -hex  32 );\
    sed -i '' "s/hs_token:.*/hs_token: $$telegram_hs_token/" ./config/telegram/registration.yml
	@echo "🔐 as_tokens and hs_tokens generated!"


# ===================
# element-web 
# ===================

# make install_element_web
# Installs element-web
install_element_web: check_dependencies check_namespace
	@test -f ${element_web_values_path} || (echo "❌ File '${element_web_values_path}' does not exist."; exit 1)
	$(eval RELEASE_EXIST := $(shell helm list -q -n ${namespace} | grep -Fx ${element_deployment_name}))
	$(if $(RELEASE_EXIST), \
		$(info Helm release name ${element_deployment_name} already exists.), \
		cp ${element_web_values_path} ./ananace/charts/element-web/values.yaml && \
		cd ./ananace/charts/element-web &&  helm install ${element_deployment_name} . --values=values.yaml -n ${namespace} \
	)

# ===================
# Synapse
# ===================

# make install_synapse_ublank
# Installs synapse server with hookshot and mautrix-telegram
install_synapse_blank: check_dependencies check_namespace create_hookshot_registration_file install_hookshot create_telegram_registration_file install_telegram 
	@test -f ${synapse_values_path} || (echo "❌ File '${synapse_values_path}' does not exist."; exit 1)
	@cp ${synapse_values_path} ./ananace/charts/matrix-synapse/values.yaml
	$(eval RELEASE_EXIST := $(shell kubectl get services -n ${namespace} -o json | jq -r '.items[] | select(.metadata.name | contains("postgresql")).metadata.name'))
	@if [ -z "$(RELEASE_EXIST)" ]; then \
		cd ./ananace/charts/matrix-synapse && helm dependency update; \
	fi

	$(eval RELEASE_EXIST_SYNAPSE := $(shell kubectl get deployments -n ${namespace}  -o json | jq -r '.items[] | select(.metadata.name | contains(${synapse_deployment_name})).metadata.name'))
	@if [ -z "$(RELEASE_EXIST_SYNAPSE)" ]; then \
		cd ./ananace/charts/matrix-synapse/ && helm install ${synapse_deployment_name} . --values=values.yaml -n ${namespace}; \
	fi
	@make restart_deployments

# Updating synapse server to work with new appservices
update_synapse_server: check_dependencies check_namespace create_hookshot_registration_file install_hookshot create_telegram_registration_file install_telegram 
	@make restart_deployments

# ===================
# Hookshot
# ===================

# make create_hookshot_registration_file
# Hookshot registration file
create_hookshot_registration_file: check_namespace
	@test -f ${hookshot_registration_values_path} || (echo "❌ File '${hookshot_registration_values_path}' does not exist."; exit 1)
	@kubectl get configmap registration-hookshot -n ${namespace} >/dev/null 2>&1 && \
	  (echo "registration-hookshot already exists."; exit 0) || \
	  (test -f ${hookshot_registration_values_path} && \
	   (echo "Creating registration-hookshot"; kubectl create configmap registration-hookshot  --from-file=${hookshot_registration_values_path} --dry-run=client -n ${namespace} -o yaml  | kubectl apply -f -)) || \
	  (echo "File '${hookshot_registration_values_path}' does not exist."; exit 1)

# make check_hookshot_registration_file
# Checking hookshot registration file
check_hookshot_registration_file: check_namespace
	@kubectl get namespace ${namespace} > /dev/null 2>&1 || (echo "Namespace '${namespace}' does not exist.";)
	@kubectl get configmap -n ${namespace} registration-hookshot >/dev/null 2>&1 && \
	  (echo "📝 registration-hookshot already exists."; exit) || \
	  (echo "❌ registration-hookshot do NOT exist. Edit ${hookshot_registration_values_path} and run: make create_hookshot_registration_file"; exit 1;)

# make create_hookshot_config_file
# Hookshot config file
create_hookshot_config_file: check_namespace create_hookshot_registration_file
	@kubectl get configmap -n ${namespace} ${hookshot_config_file_name} >/dev/null 2>&1 && \
	  (echo "📝 Hookshot config already exists."; exit 0) || \
	  { \
	  	test -f ${hookshot_config_file_path} || (echo "❌ File '${hookshot_config_file_path}' does not exist."; exit 1); \
	  	test -f ${hookshot_passkey_path} || openssl genpkey -out ${hookshot_passkey_path} -outform PEM -algorithm RSA -pkeyopt rsa_keygen_bits:4096; \
	  	test -f ${hookshot_githubkey_path} && \
	  	  kubectl create configmap ${hookshot_config_file_name} -n ${namespace} --from-file=${hookshot_config_file_path} --from-file=${hookshot_registration_values_path} --from-file=${hookshot_passkey_path} --from-file=${hookshot_githubkey_path} || \
	  	  kubectl create configmap ${hookshot_config_file_name} -n ${namespace} --from-file=${hookshot_config_file_path} --from-file=${hookshot_registration_values_path} --from-file=${hookshot_passkey_path}; \
	  }

# make create_hookshot_ingress
# Hookhost ingress
create_hookshot_ingress: check_namespace
	@test -f ${hookshot_ingress_file_path} && \
		(kubectl apply -f ${hookshot_ingress_file_path})|| \
		(echo "❌ File '${hookshot_ingress_file_path}' does not exist."; exit 1)


# pull hookshot deployment
update_hookshot_deployment: check_dependencies check_namespace
	@kubectl get deployment -n ${namespace} ${hookshot_deployment_name} -o yaml | \
		awk '/volumes:/ { print; print"      - name: e2e-keys\n        persistentVolumeClaim:\n          claimName: hookshot-e2e-keys-claim"; next }1' | \
		awk '/volumeMounts:/ { print; print "        - mountPath: /data/e2e\n          name: e2e-keys"; next }1' | \
		kubectl apply -f - --force
	@echo "✨Deployment updated\n"

# Create volumes for hookshot e2e keys
create_hookshot_volumes: check_dependencies check_namespace
	@test -f ${hookshot_volumes_file_path} || (echo "❌ File '${hookshot_volumes_file_path}' does not exist."; exit 1); \
	kubectl apply -f ${hookshot_volumes_file_path}
	@echo "📝 hookshot volumes created"

# Redis for hookshot installation
install_hookshot_redis: check_dependencies check_namespace
	@helm ls --namespace $(namespace) -q | grep -q "^hookshot-redis$$" || \
		(helm install hookshot-redis oci://registry-1.docker.io/bitnamicharts/redis --set auth.enabled=false -n $(namespace) && echo "📝 Redis installed") && \
		(echo "📝 Readi already installed")

# make install_hookshot
# Hookshot installation
install_hookshot: check_dependencies check_namespace create_hookshot_ingress create_hookshot_config_file install_hookshot_redis create_hookshot_volumes
	@sed -i.bak 's/^appVersion:.*/appVersion: "latest"/' ./matrix-hookshot/helm/hookshot/Chart.yaml && rm ./matrix-hookshot/helm/hookshot/Chart.yaml.bak
	$(eval RELEASE_EXIST := $(shell helm list -q -n ${namespace} | grep -Fx ${hookshot_deployment_name}))
	$(if $(RELEASE_EXIST), \
		$(info Helm release name ${hookshot_deployment_name} already exists.), \
		cp ${hookshot_deployment_values_file_path} ./matrix-hookshot/helm/hookshot/values.yaml && \
		cd ./matrix-hookshot/helm/hookshot && helm install ${hookshot_deployment_name} . --values=values.yaml  -n ${namespace} \
	)
	@make update_hookshot_deployment
	@kubectl rollout restart deployment -n ${namespace} ${hookshot_deployment_name}


# pull hookshot config
pull_hookshot_config:
	@mkdir -p ./temp
	@kubectl get configmap ${hookshot_config_file_name} -n ${namespace} -o json > ./temp/temp.json
	@cat ./temp/temp.json | jq -r '.data | keys[]' | while read -r key; do \
		cat ./temp/temp.json | jq -r --arg key "$$key" '.data[$$key]' > "./temp/$$key"; \
	done
	@rm ./temp/temp.json
	@echo "😁 Now edit hookshot's config file inside temp/ folder. After this run make update_hookshot_config"

# Push updated config
update_hookshot_config: check_dependencies check_namespace
	@if [ -f ./temp/githubKey.pem ]; then \
		kubectl create configmap ${hookshot_config_file_name} -n ${namespace} --from-file=./temp/config.yml  \
		--from-file=./temp/registration.yml --from-file=./temp/passkey.pem --from-file=./temp/githubKey.pem | kubectl replace -f -;  \
	else \
		kubectl create configmap ${hookshot_config_file_name} -n ${namespace} --from-file=./temp/config.yml \
		--from-file=./temp/registration.yml | kubectl replace -f -;  \
	fi
	@make update_hookshot_registration
	@kubectl rollout restart deployment ${hookshot_deployment_name} -n ${namespace}
	@echo "🚀 Updated hookshot config"

update_hookshot_registration:
	@test -f ./temp/registration.yml || (echo "❌ File './temp/registration.yml' does not exist."; exit 1)
	@echo "Creating registration-hookshot"
	@kubectl create configmap registration-hookshot  --from-file=./temp/registration.yml --dry-run=client -n ${namespace} -o yaml  | kubectl apply -f -
	@kubectl rollout restart deployment $(synapse_deployment_name) -n $(namespace)
	@echo "🎉 Hookshot registration file updated!"


# ===================
# mautrix-telegram
# ===================

# make create_telegram_database
# mautrix-telegram database create
create_telegram_database: check_dependencies check_namespace
	@POSTGRES_POD=$$(kubectl get pods -n $(namespace) -o json | jq -r '.items[] | select(.metadata.name | contains("postgresql")).metadata.name'); \
	if [ -z "$$POSTGRES_POD" ]; then \
		echo "❌ Cannot create database. PostgreSQL pod not found. Follow steps in README.md/#mautrix-telegram-database"; \
	else \
		if kubectl -n $(namespace) exec -it $$POSTGRES_POD -- bash -c 'PGPASSWORD=$(postgresql_admin_password) psql -U $(postgresql_admin_username) --command="CREATE DATABASE $(postgresql_telegram_database_name);"'; then \
			echo "💿 Created database!"; \
		else \
			if [ $$? -eq 1 ]; then \
				echo "⚠️ Database already exists. Continuing..."; \
			else \
				echo "❌ Error creating database"; \
				exit 1; \
			fi \
		fi \
	fi


# make create_telegram_registration_file
# mautrix-telegram registration file
create_telegram_registration_file: check_namespace
	@kubectl get configmap registration-telegram -n ${namespace} >/dev/null 2>&1 && \
	  (echo "📝 registration-telegram already exists."; exit 0) || \
	  (test -f ${telegram_registration_values_path} && \
	   (echo "Creating registration-telegram"; kubectl create configmap registration-telegram  --from-file=${telegram_registration_values_path} --dry-run=client -n ${namespace} -o yaml  | kubectl apply -f -)) || \
	  (echo "❌ File '${telegram_registration_values_path}' does not exist."; exit 1)

# make check_telegram_registration_file
# Checking mautrix-telegram registration file
check_telegram_registration_file: 
	@kubectl get namespace ${namespace} > /dev/null 2>&1 || (echo "Namespace '${namespace}' does not exist.";)
	@kubectl get configmap -n ${namespace} registration-telegram >/dev/null 2>&1 && \
	  (echo "📝 registration-telegram already exists."; exit) || \
	  (echo "❌ registration-telegram do NOT exist. Edit ${telegram_registration_values_path} and run: make create_telegram_registration_file"; exit 1;)

# make install_telegram
# Installing mautrix-telegram
install_telegram: check_dependencies check_namespace create_telegram_registration_file
	$(eval RELEASE_EXIST := $(shell helm list -q -n ${namespace} | grep -Fx ${telegram_deployment_name}))
	$(if $(RELEASE_EXIST), \
		$(info Helm release name ${telegram_deployment_name} already exists.), \
		cp ${telegram_deployment_values_file_path} ./mautrix-telegram/values.yaml &&  \
		cd ./mautrix-telegram && helm install ${telegram_deployment_name} . --values=values.yaml  -n ${namespace} \
	)



## ULTIMATE INSTALLATION 
install_full:
	@make install_element_web
	@make install_synapse_blank

