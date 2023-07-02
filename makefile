include ./config/config.sh

# Checking dependencies
check_dependencies:
	@which helm > /dev/null 2>&1 || { echo "Helm command not found. Please install Helm and make sure it's in your system's PATH."; exit 1; }
	@which kubectl > /dev/null 2>&1 || { echo "Kubectl command not found. Please install Helm and make sure it's in your system's PATH."; exit 1; }
	@kubectl cluster-info > /dev/null 2>&1 || { echo "Cannot connect to Kubernetes cluster. Please make sure you have the necessary configuration and connectivity."; exit 1; }
 
# Check element-web namespace, and generate if do not exist
element_web_namsepace:
		@kubectl get namespace ${element_web_namespace} > /dev/null 2>&1 || (echo "Namespace '${element_web_namespace}' does not exist, creating...";  kubectl create namespace ${element_web_namespace})

# Element-web installation
install_element_web: check_dependencies element_web_namsepace
	cp ${element_web_values_path} ./ananace/charts/element-web/values.yaml
	cd ./ananace/charts/element-web &&  helm install ${element_deployment_name} . --values=values.yaml -n ${element_web_namespace}

# Element-web tls update
tls_update: check_dependencies element_web_namsepace
	kubectl apply -f ${element_web_tls_file_path} -n ${element_web_namespace}
	cp ${element_web_values_path} ./ananace/charts/element-web/values.yaml
	cd ./ananace/charts/element-web && helm upgrade ${element_deployment_name} . --values=values.yaml  -n ${element_web_namespace}

# Check synapse namespace, and generate if do not exist
synapse_namsepace:
		@kubectl get namespace ${synapse_namespace} > /dev/null 2>&1 || (echo "Namespace '${synapse_namespace}' does not exist, creating...";  kubectl create namespace ${synapse_namespace})

# Synapse installation
install_synapse_blank: check_dependencies create_hookshot_registration_file create_telegram_registration_file install_telegram 
	cp ${synapse_values_path} ./ananace/charts/matrix-synapse/values.yaml
	@cd ./ananace/charts/matrix-synapse && \
	if [ ! -f "charts/postgresql/Chart.yaml" ] || [ ! -f "charts/redis/Chart.yaml" ]; then \
		helm dependency update; \
	fi
	cd ./ananace/charts/matrix-synapse/ && helm install ${synapse_deployment_name} . --values=values.yaml  -n ${synapse_namespace}
	kubectl rollout status deployment ${synapse_deployment_name} -n ${synapse_namespace}

# Check all required registration files
check_registration_files:
	make check_hookshot_registration_file
	make check_telegram_registration_file
	echo "Registration files exists!"

# Hookshot registration file
create_hookshot_registration_file: synapse_namsepace
	@kubectl get configmap registration-hookshot -n ${synapse_namsepace} >/dev/null 2>&1 && \
	  (echo "registration-hookshot already exists."; exit 0) || \
	  (test -f ${hookshot_registration_values_path} && \
	   (echo "Creating registration-hookshot"; kubectl create configmap registration-hookshot  --from-file=${hookshot_registration_values_path} --dry-run=client -n ${synapse_namespace} -o yaml  | kubectl apply -f -)) || \
	  (echo "File '${hookshot_registration_values_path}' does not exist."; exit 1)

# Checking hookshot registration file
check_hookshot_registration_file: 
	@kubectl get namespace ${synapse_namespace} > /dev/null 2>&1 || (echo "Namespace '${synapse_namespace}' does not exist.";)
	@kubectl get configmap -n ${synapse_namespace} registration-hookshot >/dev/null 2>&1 && \
	  (echo "registration-hookshot already exists."; exit) || \
	  (echo "registration-hookshot do NOT exist. Edit ${hookshot_registration_values_path} and run: make create-hookshot-registration-file"; exit 1;)


# Check synapse namespace, and generate if do not exist
hookshot_namsepace:
		@kubectl get namespace ${hookshot_namespace} > /dev/null 2>&1 || (echo "Namespace '${hookshot_namespace}' does not exist, creating...";  kubectl create namespace ${hookshot_namespace})


# Hookshot config file
create_hookshot_config_file: create_hookshot_registration_file hookshot_namsepace
	@kubectl get configmap -n ${hookshot_namespace} ${hookshot_config_file_name} >/dev/null 2>&1 && \
	  (echo "Hookshot config already exists."; exit 0) || \
	  { \
	  	test -f ${hookshot_config_file_path} || (echo "File '${hookshot_config_file_path}' does not exist."; exit 1); \
	  	test -f ${hookshot_passkey_path} || openssl genpkey -out ${hookshot_passkey_path} -outform PEM -algorithm RSA -pkeyopt rsa_keygen_bits:4096; \
	  	test -f ${hookshot_githubkey_path} && \
	  	  kubectl create configmap ${hookshot_config_file_name} -n ${hookshot_namespace} --from-file=${hookshot_config_file_path} --from-file=${hookshot_registration_values_path} --from-file=${hookshot_passkey_path} --from-file=${hookshot_githubkey_path} || \
	  	  kubectl create configmap ${hookshot_config_file_name} -n ${hookshot_namespace} --from-file=${hookshot_config_file_path} --from-file=${hookshot_registration_values_path} --from-file=${hookshot_passkey_path}; \
	  }

# Hookhost ingress
create_hookshot_ingress: hookshot_namsepace
	@test -f ${hookshot_ingress_file_path} && \
		(kubectl apply -f ${hookshot_ingress_file_path})|| \
		(echo "File '${hookshot_ingress_file_path}' does not exist."; exit 1)

# Hookshot installation
install_hookshot: create_hookshot_ingress create_hookshot_config_file 
	sed -i.bak 's/^appVersion:.*/appVersion: "latest"/' ./matrix-hookshot/helm/hookshot/Chart.yaml && rm ./matrix-hookshot/helm/hookshot/Chart.yaml.bak
	$(eval RELEASE_EXIST := $(shell helm list -q | grep -Fx ${hookshot_deployment_name}))
	$(if $(RELEASE_EXIST), \
		$(info Helm release name '${hookshot_deployment_name}' already exists. Please choose a different name.), \
		cp ${hookshot_deployment_values_file_path} ./matrix-hookshot/helm/hookshot/values.yaml && \
		cd ./matrix-hookshot/helm/hookshot && helm install ${hookshot_deployment_name} . --values=values.yaml  -n ${hookshot_namespace} \
	)


# mautrix-telegram database create
create_telegram_database: check_dependencies
	POSTGRES_POD=$$(kubectl get pods -n $(postgresq_namespace) -o json | jq -r '.items[] | select(.metadata.name | contains("postgresql")).metadata.name'); \
	if [ -z "$$POSTGRES_POD" ]; then \
		echo "Cannot create database. PostgreSQL pod not found. Follow steps in README.md/#mautrix-telegram-database"; \
	else \
		kubectl -n $(postgresq_namespace) exec -it $$POSTGRES_POD -- bash -c 'PGPASSWORD=$(postgresq_admin_password) psql -U $(postgresq_admin_username) --command="CREATE DATABASE $(postgresq_telegram_database_name);"'; \
		echo "Created database!"; \
	fi


# mautrix-telegram registration file
create_telegram_registration_file: synapse_namsepace
	@kubectl get configmap registration-telegram -n ${synapse_namsepace} >/dev/null 2>&1 && \
	  (echo "registration-telegram already exists."; exit 0) || \
	  (test -f ${telegram_registration_values_path} && \
	   (echo "Creating registration-telegram"; kubectl create configmap registration-telegram  --from-file=${telegram_registration_values_path} --dry-run=client -n ${synapse_namespace} -o yaml  | kubectl apply -f -)) || \
	  (echo "File '${telegram_registration_values_path}' does not exist."; exit 1)

# Checking mautrix-telegram  registration file
check_telegram_registration_file: 
	@kubectl get namespace ${synapse_namespace} > /dev/null 2>&1 || (echo "Namespace '${synapse_namespace}' does not exist.";)
	@kubectl get configmap -n ${synapse_namespace} registration-telegram >/dev/null 2>&1 && \
	  (echo "registration-telegram already exists."; exit) || \
	  (echo "registration-hookshot do NOT exist. Edit ${hookshot_registration_values_path} and run: make create-telegram-registration-file"; exit 1;)


# Check mautrix-telegram namespace, and generate if do not exist
telegram_namsepace:
		@kubectl get namespace ${telegram_namespace} > /dev/null 2>&1 || (echo "Namespace '${telegram_namespace}' does not exist, creating...";  kubectl create namespace ${telegram_namespace})


install_telegram: check_telegram_registration_file telegram_namsepace
	$(eval RELEASE_EXIST := $(shell helm list -q | grep -Fx ${telegram_deployment_name}))
	$(if $(RELEASE_EXIST), \
		$(info Helm release name '${telegram_deployment_name}' already exists. Please choose a different name.), \
		cp ${telegram_deployment_values_file_path} ./mautrix-telegram/values.yaml && \
		cd ./mautrix-telegram && helm install ${telegram_deployment_name} . --values=values.yaml  -n ${telegram_namespace} \
	)


# POSTGRESS INGRESS

