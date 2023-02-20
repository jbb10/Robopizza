# Build API and Worker images
# LAUNCH DOCKER
docker build -f ApplicationCode\Api\Dockerfile ApplicationCode -t api:v1
docker build -f ApplicationCode\Worker\Dockerfile ApplicationCode -t worker:v1

# Create the infrastructure
az login
terraform -chdir=terraform init
terraform -chdir=terraform apply

# Configure a kubectl context for our new cluster and create our namespace
az aks get-credentials -g robopizza-rg -n robopizza-cluster --overwrite-existing
kubectl apply -f kubernetes/namespace.yaml

# Install ingress controller using Helm
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx --create-namespace --namespace ingress-nginx --set controller.watchIngressWithoutClass=true

# Install rabbitmq using Helm
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install rabbitmq --set auth.username=guest,auth.password=guest,namespaceOverride=robopizza bitnami/rabbitmq
#helm install rabbitmq --set auth.username=guest,auth.password=guest,service.type=LoadBalancer,service.ports.manager=80,namespaceOverride=robopizza bitnami/rabbitmq

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

kubectl config set-context --current --namespace=robopizza
# The workers need to have their RabbitMqHostName set to "rabbitmq.robopizza.svc.cluster.local" in AppSettings