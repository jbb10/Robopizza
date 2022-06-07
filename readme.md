# Microservices from the Ground up
In this course we’re zooming out and looking at what’s needed to go from zero to a fully functioning microservice-oriented architecture! We’re using Docker to containerize some microservices that are then deployed in Kubernetes. The microservices communicate using APIs (REST) and messaging (RabbitMQ) with the whole thing provisioned in Azure using Terraform, so we’re touching upon a lot of cool tech!

## Microservices and Docker
The project contains a folder called **ApplicationCode** which contains our microservices. We have a service called "Api" that exposes a REST API towards our end-users that allows them to put in orders for pizzas. Api takes these orders and puts them on our job queue. The second type of microservice we have is called Worker. These grab orders from the queue and actually make the pizzas.