# variables.tf
# change your public key here!
variable "public-key" {
    description = "Public SSH key"
    default = "changeme"
}

variable "region" {
    description = "AWS region"
    default     = "ap-southeast-1"
}

variable "availability_zone" {
    description = "AWS region"
    default     = "ap-southeast-1b"
}

variable "instance_count" {
  description = "Number of instances to create"
  default     = 3
}

variable "ami" {
    description = "Amazon Machine Image id (default to RHEL 8)"
    default = "ami-0e28ce9494c87c82b"
}

variable "s3-bucket-name" {
    description = "AWS S3 bucket name"
    default = "terraform-neo4j-nom-s3"
}

variable "sg_ingress_rules" {
  type = map(map(any))
  default = {
    port_22   = { from = 22, to = 22, proto = "tcp", cidr = "0.0.0.0/0", desc = "Allow port 22 from all" },
    port_80   = { from = 80, to = 80, proto = "tcp", cidr = "0.0.0.0/0", desc = "Allow port 80 from all" },
    port_5000 = { from = 5000, to = 5000, proto = "tcp", cidr = "0.0.0.0/0", desc = "Allow port 5000 from all" },
    port_6000 = { from = 6000, to = 6000, proto = "tcp", cidr = "0.0.0.0/0", desc = "Allow port 6000 from all" },
    port_7000 = { from = 7000, to = 7000, proto = "tcp", cidr = "0.0.0.0/0", desc = "Allow port 7000 from all" },
    port_7474 = { from = 7474, to = 7474, proto = "tcp", cidr = "0.0.0.0/0", desc = "Allow port 7474 from all" },
    port_7687 = { from = 7687, to = 7687, proto = "tcp", cidr = "0.0.0.0/0", desc = "Allow port 7687 from all" },
    port_7688 = { from = 7688, to = 7688, proto = "tcp", cidr = "0.0.0.0/0", desc = "Allow port 7687 from all" },
    port_8080 = { from = 8080, to = 8080, proto = "tcp", cidr = "0.0.0.0/0", desc = "Allow port 8080 from all" },
    port_9090 = { from = 9090, to = 9090, proto = "tcp", cidr = "0.0.0.0/0", desc = "Allow port 9090 from all" },
  }
}

variable "dbms_mode" {
    description = "DBMS mode of the node being provisioned"
    type = string
    default = "CORE"
}

variable "neo4j_version" {
    description = "Neo4j version to be installed"
    type = string
    default = "5.15.0"
}

variable "nom_version" {
    description = "Neo4j version to be installed"
    type = string
    default = "1.9.0"
}

variable "bloom_version" {
    description = "Neo4j Bloom version to be installed"
    type = string
    default = "1.9.1"
}

variable "apoc_version" {
    description = "Neo4j APOC version to be installed"
    type = string
    default = "4.3.0.4"
}

/*Enter memory config size, the 
inputs needs to be in GB relative 
to available memory*/
variable "initial_heap_size" {
    type = string
    default = "1"
}

/*Enter memory config size, the 
inputs needs to be in GB relative 
to available memory*/
variable "max_heap_size" {
    type = string
    default = "1"
}

/*Enter memory config size, the 
inputs needs to be in GB relative 
to available memory*/
variable "page_cache_size" {
    type = string
    default = "1"
}

variable "allow_upgrade" {
    description = "Allow upgrade of the Neo4j DB being provisioned"
    type = string
    default = "true"
}

variable "bloom_license" {
    description = "License key for the Neo4j Bloom plugin"
    type = string
    default = "bloom.txt"
}

/*Provide the username that will 
own the DB in this instance*/
variable "db_owner" {
    type = string
    default = "neo4j"
}

variable "static_internal_ips" {
  type = list(string)
  default = ["10.0.10.21","10.0.10.22","10.0.10.23"]
}

variable "nom_static_internal_ips" {
  type = string
  default = "10.0.10.24"
}

variable "static_external_ip_name" {
  description = "Name assigned to External IP used by this Terraform deployment"
  type = string
  default = "neo4j-causal-cluster-external-ip"
}

variable "vm_name" {
    description = "Name of the VM being provisioned by this Terraform deployment"
    type = string
    default = "nom-terraform-cluster"
}
