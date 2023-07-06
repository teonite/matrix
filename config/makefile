check_dependencies:
	# Checking if helm and kubectl are installed
	@which helm > /dev/null 2>&1 || { echo "Helm command not found. Please install Helm and make sure it's in your system's PATH."; exit 1; }
	@which kubectl > /dev/null 2>&1 || { echo "Kubectl command not found. Please install Helm and make sure it's in your system's PATH."; exit 1; }
	# Checking connection to Kubernetes
	@kubectl cluster-info > /dev/null 2>&1 || { echo "Cannot connect to Kubernetes cluster. Please make sure you have the necessary configuration and connectivity."; exit 1; }
 
install_element_web: check_dependencies
# chcek if already exist
	cp ./element-web.yaml ../ananace/charts/element-web/values.yaml
	cd ../ananace/charts/element-web &&  helm install element-web . --values=values.yaml


# add element tls setup

install_synapse_blank: check_dependencies create-hookshot-registration-file
# chcek if already exist

	cp ./synapse.yaml ../ananace/charts/matrix-synapse/values.yaml
	@cd ../ananace/charts/matrix-synapse && \
	if [ ! -f "charts/postgresql/Chart.yaml" ] || [ ! -f "charts/redis/Chart.yaml" ]; then \
		helm dependency build; \
	fi
	cd ../ananace/charts/matrix-synapse/ && helm install matrix-synapse . --values=values.yaml

create-hookshot-registration-file:
	@kubectl get configmap -n default registration-hookshot >/dev/null 2>&1 && \
	  (echo "Registration-matrix already exists."; exit 0) || \
	  (test -f ./appservices/hookshot/registration.yml && \
	   (echo "Creating registration-matrix"; kubectl create configmap registration-hookshot -n default --from-file=./appservices/hookshot/registration.yml --dry-run=client -o yaml | kubectl apply -f -)) || \
	  (echo "File './appservices/hookshot/registration.yml' does not exist."; exit 1)

create-hookshot-config-file: create-hookshot-registration-file
	@kubectl get configmap -n default hookshot-config >/dev/null 2>&1 && \
	  (echo "Hookshot config already exists."; exit 0) || \
	  { \
	  	test -f ./appservices/hookshot/config.yml || (echo "File './appservices/hookshot/config.yml' does not exist."; exit 1); \
	  	test -f ./appservices/hookshot/passkey.pem || openssl genpkey -out ./appservices/hookshot/passkey.pem -outform PEM -algorithm RSA -pkeyopt rsa_keygen_bits:4096; \
	  	test -f ./appservices/hookshot/githubKey.pem && \
	  	  kubectl create configmap hookshot-config -n default --from-file=./appservices/hookshot/config.yml --from-file=./appservices/hookshot/registration.yml --from-file=./appservices/hookshot/passkey.pem --from-file=./appservices/hookshot/githubKey.pem || \
	  	  kubectl create configmap hookshot-config -n default --from-file=./appservices/hookshot/config.yml --from-file=./appservices/hookshot/registration.yml --from-file=./appservices/hookshot/passkey.pem; \
	  }

create-hookshot-ingress:
	@test -f ./appservices/hookshot/ingress.yaml && \
		(kubectl apply -f ./appservices/hookshot/ingress.yaml) || \
		(echo "File './appservices/hookshots/ingress.yaml' does not exist."; exit 1)


install_hookshot: create-hookshot-ingress create-hookshot-config-file
	$(eval RELEASE_EXIST := $(shell helm list -q | grep -Fx matrix-hookshot))
	$(if $(RELEASE_EXIST), \
		$(info Helm release name 'matrix-hookshot' already exists. Please choose a different name.), \
		cp ./appservices/hookshot/values.yaml ../matrix-hookshot/helm/hookshot/values.yaml && \
		cd ../matrix-hookshot/helm/hookshot && helm install matrix-hookshot . --values=values.yaml \
	)
# dodac zmiane Chart.yaml appVerison na latest
# update synapse 
check_if_minikube_exists:
