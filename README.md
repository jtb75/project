## Tech Task 🛫

The environment requested is a containerized web application backed by an AWS EKS cluster with a MongoDB server installed on an EC2 instance configured for access by the AWS EKS cluster.  The web application will be public facing and communicate with the MongoDB server. Backups of the MongoDB server should be scripted and stored into the public read S3 bucket.

Key Items for task:

• A containerized web application that runs inside AWS EKS and is publicly exposed through an AWS load balancer.  
• This application should connect and leverage the MongoDB instance  
• A publicly readable S3 bucket that holds MongoDB backups

## AWS Architecture 🛬

The environment was created and provisioned using Terraform to deliver the following architecture:

![](https://33333.cdn.cke-cs.com/kSW7V9NHUXugvhoQeFaf/images/e7f6c347f5a184e0b268d951d17b23cd95a636bc0118e394.png)

## Kubernetes Architecture 🛬

| NAMESPACE | NAME | IMAGE | REPLICA |
| --- | --- | --- | --- |
| project | frontend | jtb75/project:latest | 1 |

## Deployment

```plaintext
# terraform init
# terraform plan
# terraform apply
```

## Output

The terraform apply output will include the:

*   Load Balancer path to frontend application
*   The kubernetes cluster information for obtaining kubeconfig
*   The public IP address of the Mongo database

## Directory Layout
**IAC**: Contains all Terraform files for provisioning environment
**Web**: Contains the web application, kubernetes yaml templates, and Dockerfile for creating app deployment
