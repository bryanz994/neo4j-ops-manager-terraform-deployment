# Neo4j Deployment using Terraform (AWS)

This repo provides [Terraform](https://www.terraform.io/) templates to support deployment of Neo4j Graph Data Platform and Neo4j Ops Manager (NOM) in Amazon Web Services (AWS).

## **Folder structure**

All the templates in this repo follow a similar folder structure.

```
./
./main.tf           <-- Terraform file that contains the infrastruture deployment instructions (Infrastruture and Neo4j configs are parameterised and will be passed through the `variable.tf` file)
./provider.tf       <-- Terraform file that contains cloud provider and project information
./variables.tf      <-- Terraform file that contains all the input variables that is required by the `main.tf` file to deploy the infrastruture and Neo4j
./assets            <-- All packages used in the deployment will be stored in this folder to reduce external dependencies
./keys              <-- Folder contains Cloud Service Provider Service Account Keys (This is going to vary from vendor to vendor)
./scripts           <-- Folder contains platform/services setup script template that will be executed after the infrastructure is provisioned
```

<br>

## **Prerequisites**

### Terraform

A working Terraform setup in your local machine or host which is going to be used to perform the Cloud deployments. You can get the latest version of Terraform [**here**](https://www.terraform.io/downloads.html). 

<br>

## **Setup**

1. Setup Terraform
2. Clone this repo
3. The following AWS policies are required to run the Terraform script successfully:
   1. AmazonEC2FullAccess
   2. AmazonVPCFullAccess
   3. AmazonS3FullAccess
   4. IAMFullAccess
   5. AmazonElasticIPFullAccess
   6. AmazonSSMFullAccess
4. Create an Access Key in AWS, refer to this [guide](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html)
5. Replace your Access Key and Secret Key in the `cred` file inside the `./keys` folder
6. Replace the contents of your SSH public key in the `public-key` variable inside the `variables.tf` file 

<br>

### Deployment steps

1. Initialise the Terraform template

```
terraform init
```

2. Plan the deployment, this prints out the infrastructure to be deployed based on the template you have chosen

```
terraform plan
```

3. Deploy!! (By default this is an interactive step, when the time is right be ready to say **`'yes'`**)

```
terraform apply
```

4. When it's time to decommission (destroy) the deployment. (By default this is also an interactive step, when the time is right be ready to say **`'yes'`**)

```
terraform destroy
```

<br>
