include ./config/config.bash

# Checking dependencies
check_dependencies:
	@which helm > /dev/null 2>&1 || { echo "Helm command not found. Please install Helm and make sure it's in your system's PATH."; exit 1; }
	@which kubectl > /dev/null 2>&1 || { echo "Kubectl command not found. Please install Helm and make sure it's in your system's PATH."; exit 1; }
	@kubectl cluster-info > /dev/null 2>&1 || { echo "Cannot connect to Kubernetes cluster. Please make sure you have the necessary configuration and connectivity."; exit 1; }
 
# Element-web installation
install_element_web: check_dependencies
	cp ${element_web_values_path} ./ananace/charts/element-web/values.yaml
	cd ./ananace/charts/element-web &&  helm install ${element_deployment_name} . --values=values.yaml -n ${element_web_namespace}

# Element-web tls update
tls_update: check_dependencies
	kubectl apply -f ${element_web_tls_file_path} -n ${element_web_namespace}
	cp ${element_web_values_path} ./ananace/charts/element-web/values.yaml
	cd ./ananace/charts/element-web && helm upgrade ${element_deployment_name} . --values=values.yaml  -n ${element_web_namespace}

# Synapse installation
install_synapse_blank: check_dependencies create-hookshot-registration-file
	cp ${synapse_values_path} ./ananace/charts/matrix-synapse/values.yaml
	@cd ./ananace/charts/matrix-synapse && \
	if [ ! -f "charts/postgresql/Chart.yaml" ] || [ ! -f "charts/redis/Chart.yaml" ]; then \
		helm dependency update; \
	fi
	cd ./ananace/charts/matrix-synapse/ && helm install ${element_web_namespace} . --values=values.yaml  -n ${synapse_namespace}
	kubectl rollout status deployment ${element_web_namespace} -n ${synapse_namespace}

# Hookshot registration file
create-hookshot-registration-file: 
	@kubectl get configmap -n ${hookshot_namespace} registration-hookshot >/dev/null 2>&1 && \
	  (echo "registration-hookshot already exists."; exit 0) || \
	  (test -f ${hookshot_registration_values_path} && \
	   (echo "Creating registration-hookshot"; kubectl create configmap registration-hookshot -n ${hookshot_namespace} --from-file=${hookshot_registration_values_path} --dry-run=client -o yaml | kubectl apply -f -)) || \
	  (echo "File '${hookshot_registration_values_path}' does not exist."; exit 1)

# Checking hookshot registration file
check-hookshot-registration-file:
	@kubectl get configmap -n ${hookshot_namespace} registration-hookshot >/dev/null 2>&1 && \
	  (echo "registration-hookshot already exists."; exit) || \
	  (echo "registration-hookshot do NOT exist. Edit ${hookshot_registration_values_path} and run: make create-hookshot-registration-file";)

# Hookshot config file
create-hookshot-config-file: create-hookshot-registration-file
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
create-hookshot-ingress:
	@test -f ${hookshot_ingress_file_path} && \
		(kubectl apply -f ${hookshot_ingress_file_path})  -n ${hookshot_namespace} || \
		(echo "File '${hookshot_ingress_file_path}' does not exist."; exit 1)

# Hookshot installation
install_hookshot: create-hookshot-ingress create-hookshot-config-file
	sed -i.bak 's/^appVersion:.*/appVersion: "latest"/' ./matrix-hookshot/helm/hookshot/Chart.yaml && rm ./matrix-hookshot/helm/hookshot/Chart.yaml.bak
	$(eval RELEASE_EXIST := $(shell helm list -q | grep -Fx ${hookshot_deployment_name}))
	$(if $(RELEASE_EXIST), \
		$(info Helm release name '${hookshot_deployment_name}' already exists. Please choose a different name.), \
		cp ${hookshot_deployment_values_file_path} ./matrix-hookshot/helm/hookshot/values.yaml && \
		cd ./matrix-hookshot/helm/hookshot && helm install ${hookshot_deployment_name} . --values=values.yaml  -n ${hookshot_namespace} \
	)

