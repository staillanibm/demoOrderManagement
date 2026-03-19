DOCKER_RUNTIME=podman
COMPOSE_RUNTIME=podman compose

IMAGE_NAME=ghcr.io/staillanibm/msr-order-management
TAG=latest

DEPLOYMENT_NAME=msr-order-management

MSR_DEV_PORT_NUMBER=15555
DOCKER_PORT_NUMBER=16666
DOCKER_ROOT_URL=http://localhost:$(DOCKER_PORT_NUMBER)
DOCKER_ADMIN_PASSWORD=$(shell grep '^ADMIN_PASSWORD=' ./resources/docker-compose/.env | cut -d'=' -f2)

KUBE_NAMESPACE=integration
KUBE_ROOT_URL=https://$(shell kubectl get route $(DEPLOYMENT_NAME) -n $(KUBE_NAMESPACE) -o jsonpath='{.spec.host}')
KUBE_TEST_PASSWORD=$(shell kubectl get secret $(DEPLOYMENT_NAME) -n $(KUBE_NAMESPACE) -o jsonpath='{.data.TESTER_PASSWORD}' | base64 -d)

docker-build:
	$(DOCKER_RUNTIME) build -t $(IMAGE_NAME):$(TAG) --platform=linux/amd64 --build-arg WPM_TOKEN=${WPM_TOKEN} .

docker-login-wm:
	@echo ${WM_CR_PASSWORD} | $(DOCKER_RUNTIME) login ${WM_CR_SERVER} -u ${WM_CR_USERNAME} --password-stdin

docker-login-gh:
	@echo ${GH_CR_PASSWORD} | $(DOCKER_RUNTIME) login ${GH_CR_SERVER} -u ${GH_CR_USERNAME} --password-stdin

docker-push:
	$(DOCKER_RUNTIME) push $(IMAGE_NAME):$(TAG)

docker-dev-run:
	MSR_DEV_PORT_NUMBER=${MSR_DEV_PORT_NUMBER} DEPLOYMENT_NAME=$(DEPLOYMENT_NAME) $(COMPOSE_RUNTIME) -f ./resources/docker-compose-dev/docker-compose.yml up -d

docker-dev-stop:
	MSR_DEV_PORT_NUMBER=${MSR_DEV_PORT_NUMBER} DEPLOYMENT_NAME=$(DEPLOYMENT_NAME) $(COMPOSE_RUNTIME) -f ./resources/docker-compose-dev/docker-compose.yml down

docker-dev-msr-logs:
	$(DOCKER_RUNTIME) logs -f DEPLOYMENT_NAME=$(DEPLOYMENT_NAME)-dev

# make sure to pass the PACKAGE variable when invoking this target, e.g.:
# make docker-dev-link-package PACKAGE=sttTest
docker-dev-link-package:
	$(DOCKER_RUNTIME) exec -it $(DEPLOYMENT_NAME)-dev ln -s /opt/softwareag/IntegrationServer/packages/${PACKAGE} /git/${PACKAGE}

docker-run:
	IMAGE_NAME=${IMAGE_NAME} TAG=${TAG} DEPLOYMENT_NAME=$(DEPLOYMENT_NAME)-dev DOCKER_PORT_NUMBER=${DOCKER_PORT_NUMBER} $(COMPOSE_RUNTIME) -f ./resources/docker-compose/docker-compose.yml up -d

docker-stop:
	IMAGE_NAME=${IMAGE_NAME} TAG=${TAG} DEPLOYMENT_NAME=$(DEPLOYMENT_NAME)-dev DOCKER_PORT_NUMBER=${DOCKER_PORT_NUMBER}	$(COMPOSE_RUNTIME) -f ./resources/docker-compose/docker-compose.yml down

docker-msr-logs:
	$(DOCKER_RUNTIME) logs -f $(DEPLOYMENT_NAME)

docker-test-file:
	@TS1=$$(date +%Y%m%d-%H%M%S) && DB2TS1=$$(date +%Y-%m-%d-%H.%M.%S.000000) && \
	sleep 1 && \
	TS2=$$(date +%Y%m%d-%H%M%S) && DB2TS2=$$(date +%Y-%m-%d-%H.%M.%S.000000) && \
	DEST=./resources/docker-compose/files/incoming/orders_$$(date +%Y%m%d-%H%M%S).csv && \
	sed \
		-e "1s/ORD-YYYYMMDD-HHMMSS/ORD-$$TS1/" \
		-e "1s/YYYY-MM-DD-HH\.mm\.ss\.SSSSSS/$$DB2TS1/" \
		-e "2s/ORD-YYYYMMDD-HHMMSS/ORD-$$TS2/" \
		-e "2s/YYYY-MM-DD-HH\.mm\.ss\.SSSSSS/$$DB2TS2/" \
		./resources/samples/orders.csv > $$DEST && \
	echo "Created $$DEST"

docker-test-api-post:
	@TS=$$(date +%Y%m%d-%H%M%S) ISO_TS=$$(date +%Y-%m-%dT%H:%M:%S.000) \
	ROOT_URL=$(DOCKER_ROOT_URL) API_USER=Administrator API_PASSWORD=$(DOCKER_ADMIN_PASSWORD) \
	bash ./resources/tests/postOrder.sh

docker-test-api-list:
	@if [ -n "$(ORDER_ID)" ]; then \
		ROOT_URL=$(DOCKER_ROOT_URL) API_USER=Administrator API_PASSWORD=$(DOCKER_ADMIN_PASSWORD) ORDER_ID=$(ORDER_ID) \
		bash ./resources/tests/getOrderById.sh; \
	else \
		ROOT_URL=$(DOCKER_ROOT_URL) API_USER=Administrator API_PASSWORD=$(DOCKER_ADMIN_PASSWORD) \
		bash ./resources/tests/listOrders.sh; \
	fi

kube-test-file:
	@TS1=$$(date +%Y%m%d-%H%M%S) && DB2TS1=$$(date +%Y-%m-%d-%H.%M.%S.000000) && \
	sleep 1 && \
	TS2=$$(date +%Y%m%d-%H%M%S) && DB2TS2=$$(date +%Y-%m-%d-%H.%M.%S.000000) && \
	FILENAME=orders_$$(date +%Y%m%d-%H%M%S).csv && \
	LINE1="ORD-$$TS1;$$DB2TS1;CUST-5678;Stephane;stephane@email.com;12 Rue de la Paix;Paris;75002;FR;EUR;PROD-001|2|29.99;PROD-002|1|15.50;;;" && \
	LINE2="ORD-$$TS2;$$DB2TS2;CUST-9012;Stephane;stephane@email.com;8 Avenue des Champs;Lyon;69001;FR;EUR;PROD-003|5|9.99;PROD-004|3|45.00;PROD-005|1|120.00;;" && \
	BUSYBOX_POD=$$(kubectl get pod -l app=busybox-pvc-browser -n $(KUBE_NAMESPACE) -o jsonpath='{.items[0].metadata.name}') && \
	kubectl exec $$BUSYBOX_POD -n $(KUBE_NAMESPACE) -- sh -c "mkdir -p /data/incoming && printf '%s\n%s\n' '$$LINE1' '$$LINE2' > /data/incoming/$$FILENAME && echo '--- File content ---' && cat /data/incoming/$$FILENAME && echo '---'"

kube-deploy:
	@cd ./resources/kubernetes && kustomize edit set image $(IMAGE_NAME)=$(IMAGE_NAME):$(TAG)
	kubectl apply -k ./resources/kubernetes/ -n $(KUBE_NAMESPACE)

kube-deploy-status:
	kubectl rollout status deployment/$(DEPLOYMENT_NAME) -n $(KUBE_NAMESPACE)

kube-undeploy:
	kubectl delete -f ./resources/kubernetes/ -n $(KUBE_NAMESPACE)

kube-msr-logs:
	kubectl logs -f deployment/$(DEPLOYMENT_NAME) -n $(KUBE_NAMESPACE) --prefix=true

kube-test-api-post:
	@TS=$$(date +%Y%m%d-%H%M%S) ISO_TS=$$(date +%Y-%m-%dT%H:%M:%S.000) \
	ROOT_URL=$(KUBE_ROOT_URL) API_USER=tester API_PASSWORD=$(KUBE_TEST_PASSWORD) \
	bash ./resources/tests/postOrder.sh

kube-test-api-list:
	@if [ -n "$(ORDER_ID)" ]; then \
		ROOT_URL=$(KUBE_ROOT_URL) API_USER=tester API_PASSWORD=$(KUBE_TEST_PASSWORD) ORDER_ID=$(ORDER_ID) \
		bash ./resources/tests/getOrderById.sh; \
	else \
		ROOT_URL=$(KUBE_ROOT_URL) API_USER=tester API_PASSWORD=$(KUBE_TEST_PASSWORD) \
		bash ./resources/tests/listOrders.sh; \
	fi