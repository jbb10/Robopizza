# Microservices from the Ground up
In this course we’re zooming out and looking at what’s needed to go from zero to a fully functioning microservice-oriented architecture! We’re using Docker to containerize some microservices that are then deployed in Kubernetes. The microservices communicate using APIs (REST) and messaging (RabbitMQ) with the whole thing provisioned in Azure using Terraform, so we’re touching upon a lot of cool tech!
- This readme serves as the main tutorial and includes all the information needed to go implement the project
- In the root of the project there's a Powerpoint slide deck that has a high-level walkthrough and an overview of the contents of the project including diagrams
- A walkthrough of the course was recorded for the DK Engineering Engineering community which mostly follows the steps in this readme available [here](https://myresources.deloitte.com/personal/jbjornsson_deloitte_dk/_layouts/15/onedrive.aspx?id=%2Fpersonal%2Fjbjornsson%5Fdeloitte%5Fdk%2FDocuments%2FRecordings%2FDK%20Engineering%20Community%20%2D%20SE%20Edition%2D20220623%5F162235%2DMeeting%20Recording%2Emp4&parent=%2Fpersonal%2Fjbjornsson%5Fdeloitte%5Fdk%2FDocuments%2FRecordings)

## Prerequisites
- Get a Deloitte Azure subscription. We’ll be using Azure to host our cluster and as Deloitte employees we can get an Azure subscription with 350 DKK credits per month to play with! To get the subscription, send an email to Henrik Randløv and ask for a Deloitte Azure subscription. 
- Get local administrator access on your computer. Instructions can be found under "Local admin rights on your laptop” in the wiki on our Teams channel
- Install an IDE. We’re not doing heavy C# coding this time so a general purpose text editor is fine (e.g. Sublime, Notepad++ or VS Code)
- Install Docker Desktop. Used to build our docker images (the mircoservices)
- Install the .NET SDK. Used to build our micrservices
- Install Git. Used to pull the code from the repo
- Install kubectl. Used to control Kubernetes
- Install the Azure CLI. We use this to interact with Azure
- Install Helm. This tool allows us to install Helm Charts which are packages of Kubernetes components

## Prerequisites
- Get a Deloitte Azure subscription. The quickest option is to simply start a free trial with Azure. Another option is to get a Deloitte-provided subscription (talk to the Tech Engineering Leadership Team). 
- Get local administrator access on your computer. Instructions can be found under ["Local admin rights on your laptop"](https://teams.microsoft.com/l/entity/com.microsoft.teamspace.tab.wiki/tab::7e5b95cb-bdb9-4245-8aa5-f80650e2f33c?context=%7B%22subEntityId%22%3A%22%7B%5C%22pageId%5C%22%3A2%2C%5C%22sectionId%5C%22%3A17%2C%5C%22origin%5C%22%3A2%7D%22%2C%22channelId%22%3A%2219%3A4b0ca2536333440d94a6a254e4fbb83f%40thread.skype%22%7D&tenantId=36da45f1-dd2c-4d1f-af13-5abe46b99921) in the wiki on our "Custom Development" Teams channel
- Install an IDE. We’re not doing heavy C# coding this time so a general purpose text editor is fine (e.g. VS Code, Sublime, Notepad++), but IDEs work too (Visual Studio, Rider, IntelliJ, etc.)
- Install Docker Desktop. Used to build our docker images (the mircoservices)
- Install the .NET SDK. Used to build our micrservices
- Install Git. Used to pull the code from the repo
- Install kubectl. Used to control Kubernetes
- Install the Azure CLI. We use this to interact with Azure
- Install Helm. This tool allows us to install Helm Charts which are packages of Kubernetes components

## Microservices and Docker
The project contains a folder called **ApplicationCode** which contains our microservices. We have a service called "Api" that exposes a REST API towards our end-users that allows them to put in orders for pizzas. Api takes these orders and puts them on our job queue. The second type of microservice we have is called Worker. These grab orders from the queue and actually make the pizzas.

- Start by opening the **Api project** and taking a look at the code. The API is extremely simple - it has one POST operation for creating our jobs. This operation creates a connection to our RabbitMQ server, and creates a channel in that connection. That channel is used to create a queue (if it doesn't exist) and then publish our messages. See any issues with the performance of this setup?
- Now let's look at the **Worker project**. It's even simpler, using IHostedService to implement our background service behaviour. When the Worker starts it starts listening to a queue (via a channel and connection) and defines a callback function that runs when a message is received. In order to simulate our pizza making, we simply sleep the thread for 15-25 seconds.
- Try running the API project and see what happens when you try to create a job..
    - To build a docker image navigate to the solution folder (ApplicationCode) and issue the following command: `docker build -f .\Api\Dockerfile . -t api:v1` where the `-f` parameter specifies the path to the Dockerfile, the `.` is the context from where we execute the commands in the Dockerfile, and `-t` tags the image
    - To instantiate the newly created *image* as a running **container**, issue the following command: `docker run -d -p 55001:80 --name Api api:v1` where the `-p` parameter maps port 55001 on our local computer to port 80 on the contianer and `--name` gives our container a name.
    - We should get an error from our API where it complains about not finding a RabbitMQ server..
- We need to install RabbitMQ on our computer for this to work! With docker this is a simple matter of issuing the following command (the `-p` command forwards port 15672 on our machine to the same port on the container): `docker run -d --hostname my-rabbit -p 15672:15672 --name RabbitMQ rabbitmq:3-management`
- Try navigating to http://localhost:15672 and logging in using username: `guest`, password `guest` to see the RabbitMQ admin console
- Find the internal IP (virtualized inside Docker) of our RabbitMQ service by issuing `docker inspect RabbitMQ` and looking under NetworkSettings > IPAddress. Update the appsettings.json file for both the Api and the Worker project with this IP (the key is RabbitMqHostName). This is crucial for our services to find our RabbitMQ service.
- Try building and running the Api again. Before *running* again, you might need to delete the already running container by clicking the garbage icon next to it in the Docker Desktop UI (under the *Containers* tab)
- As we order pizzas, we should see our queue grow bigger in the RabbitMQ admin console (under Queues > job-queue). The *Ready* messages are on the queue waiting to be picked up. Since we haven't started any workers, we can only expect the queue to grow and no pizzas actually being made!
- Let's start a worker. From the solution folder, issue the command `docker build -f .\Worker\Dockerfile . -t worker:v1` to build the image and `docker run -d --name Worker worker:v1` to instantiate it as a running container.
- As soon as the worker starts, it will connect to the queue and start doing work so we should see the load on the queue decrease. The amount of *Ready* messages should decrease and *Unacked* should stay at 1 (this is the amount of "pizzas in process").
- As a bonus, try instantiating another worker container from our worker image by issuing `docker run -d --name Worker2 worker:v1`. If we put some more orders in, we should see the queue empty much faster now!

## Container Orchestration and Kubernetes
Managing containers manually on the command line is fine during development but is not practical in production. We want our containers to automatically spin up if there's a failure or high load and we'd like the computer to take care of making sure the system is in the state we desire. This is where Kubernetes - a container orchestrator - comes in.
- Let's start off by cleaning up our Docker Desktop-managed images by opening the Containers tab and deleteing Api, Worker and RabbitMQ (click the dots on the right > remove)
- Docker Desktop supports setting up a Kubernetes cluster on our computer without needing a cloud provider. Open Docker Desktop settings (click the cogwheel at the top) > Kubernetes > Enable Kubernetes. It takes a few minutes for it to start running but once it is, we should see a green kubernetes logo in the bottom left corner of Docker Desktop, next to the Docker logo
    - If you have problems getting this to work, try clicking the bug in the top right and click "Clean / Purge data".
    - If that doesn't work, restart your computer (really!)
- We set up Kubernetes by describing the state we want the system to be in. This is done by writing yaml files. Both the Api and the Worker services contain a kubernetes folder that contains kubernetes resources. Have a look at them
- Try applying the api.yaml file in the Api project to the Kubernetes cluster by issuing `kubectl apply -f .\Api\kubernetes\api.yaml` from the solution folder (ApplicationCode). This creates the two resources in the file in Kubernetes and the cluster will start working right away at migrating itself into the state described in the file. By issuing `kubectl get all` we should see a Service "api" being created along with Pods being spun up for that Service.
    - Since we gave that Service the type of "LoadBalancer", it gets exposed outside the cluster to our computer on the port we designate (8080). On top of that, the Service will load balance between the two replicas of the Api we designated in the Deployment file.
    - To find out how to reach the Service (and thus the Pods behind the Service), issue `kubectl get service api` and we should see an EXTERNAL-IP of `localhost` and TCP 8080 in the port list. Let's try navigating to http://localhost:8080/swagger to verify that our Api service is running in Kubernetes.
- Like earlier, we need to install RabbitMQ for our service to work and to do that we use Helm. Deploying Helm charts is a very convenient way to deploy multiple yaml resources and configure them at the same time. Issue the command `helm repo add bitnami https://charts.bitnami.com/bitnami` to add the relevant Helm repository to our Helm installation and `helm install rabbitmq --set auth.username=guest,auth.password=guest,service.type=LoadBalancer bitnami/rabbitmq` to install RabbitMQ to our Kubernetes cluster
    - We're specifying that Helm should configure the RabbitMQ yaml so that it should expose the RabbitMQ admin console as a Service of type **LoadBalancer** which means again that we can access it from outside the cluster (from our browser). We should be able to get to it on http://localhost:15672
- If we try to submit a pizza order from our Api, we get an error since the service is still trying to reach that IP that Docker Desktop gave our old RabbitMQ container. IP addresses are usually assigned dynamically in these environments and are thus not reliably stable. It's a better idea to use DNS names. Kubernetes has a system for giving its resources internal DNS names and services get names that follow this standard: `servicename.servicenamespace.svc.cluster-domain.tld`. So by issuing `kubectl describe service rabbitmq` we can see that it has an internal DNS name of `rabbitmq.default.svc.cluster.local` (local clusters end with cluster.local)
- Open the appsettings.json in both the Api and Worker projects and put in this new name for the RabbitMqHostName. Now build both images again overwriting the already existing images (see commands above). We can ask the cluster to pull the new image for Api by restarting the two deployment. To do that we issue `kubectl rollout restart deployment api`. Now let's create the Worker deployment in the cluster by issuing `kubectl apply -f .\Worker\kubernetes\worker.yaml` from the solution folder.
- Once the deployment start/restart has finished we should be able to submit pizza orders and have the workers pick them up.
- Try putting in 40 orders in a short amount of time. This is going to take forever... is there anything in the worker.yaml that we can modify to make this go faster?

## Cloud providers and Terraform
Terraform is a tool for provisioning and managing infrastructure with cloud providers. Similar to yaml for Kubernetes, it provides a *declarative* way to provision infrastructure by simply telling the cloud provider what the infrastructure should look like, and allowing them to figure out how to implement that vision.
- Navigate to the terraform folder and issue `terraform init`. This Prepares the folder containing the terraform code for talking with the cloud provider.
- This folder contains a single `main.tf` file with Terraform code.
- Before terraform can start provisioning infrastructure on your behalf, it needs to log in (much like you need to log in to the cloud provider's portal before provisioning infrastrucutre by hand). With Azure, the azure command line provides a handy tool for this, simply issue `az login` and follow the instructions.
- When login has completed issue `terraform plan`. Terraform will scan the folder and find all contained terraform code and compare it with the infrastructure already in place in the cloud. In our case there's only one .tf file but having many (with any name/names) would work exactly the same.
- The output of `terraform plan` will show you what acitons terraform will need to take to make whatever's in your terraform files happen. These actions are either *create*, *change*, or *destroy* or *no change*, and the output will detail what resources get which action
- To apply your changes issue `terraform apply`. The command will show you again what it plans to do to apply your infrastructure code and you'll have to type "yes" for the provisioning to begin. Once it begins it can take a while depending on the nature of the resources you provision.