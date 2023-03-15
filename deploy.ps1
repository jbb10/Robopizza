# Build API and Worker images
# LAUNCH DOCKER
docker build -f ApplicationCode\Api\Dockerfile ApplicationCode -t api:v1
docker build -f ApplicationCode\Worker\Dockerfile ApplicationCode -t worker:v1

#docker run -d -p 55001:80 --name api api:v1
#docker run -d --name worker worker:v1
#docker run -d --hostname my-rabbit -p 15672:15672 --name RabbitMQ rabbitmq:3-management

# Create the infrastructure
az login
terraform -chdir=terraform init
terraform -chdir=terraform apply -auto-approve

# Configure a kubectl context for our new cluster and create our namespace
az aks get-credentials -g robopizza-rg -n robopizza-cluster --overwrite-existing
kubectl config set-context --current --namespace=robopizza

kubectl apply -f kubernetes/namespace.yaml

# Install ingress controller using Helm
#helm install ingress-nginx ingress-nginx/ingress-nginx --create-namespace --namespace ingress-nginx --set controller.watchIngressWithoutClass=true,controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz

# Install rabbitmq and nginx-ingress using Helm
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install rabbitmq --set auth.username=guest,auth.password=guest,namespaceOverride=robopizza bitnami/rabbitmq
#helm install rabbitmq --set auth.username=guest,auth.password=guest,service.type=LoadBalancer,service.ports.manager=80,namespaceOverride=robopizza bitnami/rabbitmq
helm install nginx-ingress bitnami/nginx-ingress-controller

#helm delete rabbitmq
#kubectl delete persistentvolumeclaim data-rabbitmq-0 -n robopizza

# Push Docker containers into ACR
az acr login -n robopizzaregistry
docker tag api:v1 robopizzaregistry.azurecr.io/api:v1
docker push robopizzaregistry.azurecr.io/api:v1

docker tag worker:v1 robopizzaregistry.azurecr.io/worker:v1
docker push robopizzaregistry.azurecr.io/worker:v1

kubectl rollout restart deployment api -n robopizza
kubectl rollout restart deployment worker -n robopizza

# Apply Kubernetes manifests in the cluster
kubectl apply -f kubernetes

# The workers need to have their RabbitMqHostName set to "rabbitmq.robopizza.svc.cluster.local" in AppSettings