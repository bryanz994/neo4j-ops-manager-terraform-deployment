####################################################################################################################
# Version: 0.0.1
# Created Date: 31/01/2024
# Author: Bryan Lee
# Email: bryan.lee@neo4j.com
# Description:
# Terraform script to deploy infratructure for neo4j v5 cluster and neo4j ops manager in Amazon Web Services (AWS)
# Coverage: Network, Firewall, AWS, S3, Neo4j v5 Cluster and NOM
####################################################################################################################

/*
Setup Network | Subnet | Internet Gateway | Route Table
*/
resource "aws_vpc" "terraform-nom-vpc" {
    cidr_block = "10.0.0.0/16"  # Replace with your desired VPC CIDR block
    enable_dns_support = true
    enable_dns_hostnames = true
    tags = {
        Name = "terraform-nom-vpc"
    }
}

# resource "aws_subnet" "private" {
#     vpc_id                  = aws_vpc.terraform-nom-vpc.id
#     cidr_block              = "10.0.20.0/24"  # Replace with your desired private subnet CIDR block
#     availability_zone       = "ap-southeast-1b"  # Replace with your desired availability zone
#     map_public_ip_on_launch = true
#     tags = {
#         Name = "terraform-nom-private-subnet"
#     }
# }

resource "aws_subnet" "public" {
    vpc_id                  = aws_vpc.terraform-nom-vpc.id
    cidr_block              = "10.0.10.0/24"  # Replace with your desired public subnet CIDR block
    availability_zone       = var.availability_zone  # Replace with your desired availability zone
    map_public_ip_on_launch = true

    tags = {
        Name = "terraform-nom-public-subnet"
    }
}

resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.terraform-nom-vpc.id
    
    tags = {
        Name = "terraform-nom-internet-gateway"
    }
}

resource "aws_route_table" "second_rt" {
    vpc_id = aws_vpc.terraform-nom-vpc.id
    
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }
    
    tags = {
        Name = "terraform-nom-second-route-table"
    }
}

resource "aws_route_table_association" "public_subnet_asso" {
    subnet_id      = aws_subnet.public.id
    route_table_id = aws_route_table.second_rt.id
}

/*
Setup Security Groups | Firewall
*/
resource "aws_security_group" "terraform-neo4j-nom-security-group" {
    name        = "terraform-neo4j-nom-security-group"
    description = "Security Group for Neo4j NOM terraform deployment"
    vpc_id      = aws_vpc.terraform-nom-vpc.id
}

resource "aws_security_group_rule" "neo4j_nom_ingress_rules" {
    for_each          = var.sg_ingress_rules
    type              = "ingress"
    from_port         = each.value.from
    to_port           = each.value.to
    protocol          = each.value.proto
    cidr_blocks       = [each.value.cidr]
    description       = each.value.desc
    security_group_id = aws_security_group.terraform-neo4j-nom-security-group.id
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.terraform-neo4j-nom-security-group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv6" {
  security_group_id = aws_security_group.terraform-neo4j-nom-security-group.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

/*
Generating pfx for NOM Server 
*/
resource "tls_private_key" "my_private_key" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "my_cert" {
  private_key_pem = tls_private_key.my_private_key.private_key_pem
  validity_period_hours = 58440
  early_renewal_hours = 58440
  allowed_uses = [
      "key_encipherment",
      "digital_signature",
      "server_auth",
  ]
  dns_names = [ "${format("%s%s", replace("ip-${var.nom_static_internal_ips}", ".", "-"), ".${var.region}.compute.internal")}", "localhost"]
  ip_addresses = [ "${var.nom_static_internal_ips}" ]
  is_ca_certificate = true 
  set_subject_key_id  = true

  subject {
      common_name  = "${format("%s%s", replace("ip-${var.nom_static_internal_ips}", ".", "-"), ".${var.region}.compute.internal")}"
  }
}

resource "pkcs12_from_pem" "my_pkcs12" {
  password = "changeit"
  cert_pem = tls_self_signed_cert.my_cert.cert_pem
  private_key_pem  = tls_private_key.my_private_key.private_key_pem
}

resource "local_file" "result" {
  filename = "${path.module}/assets/server.pfx"
  content_base64     = pkcs12_from_pem.my_pkcs12.result
}


/*
Setup S3 Bucket | Upload Public Key 
*/
resource "aws_s3_bucket" "terraform-neo4j-nom-s3" {
    bucket = var.s3-bucket-name
    tags = {
        Name        = var.s3-bucket-name
        Environment = "Dev"
    }
    force_destroy = true
}
 
resource "aws_s3_object" "neo4j-assets" {
    for_each = fileset("./assets/", "*")
    bucket = aws_s3_bucket.terraform-neo4j-nom-s3.bucket
    key = each.value
    source = "./assets/${each.value}"
    force_destroy = true
    depends_on = [ local_file.result ]
}

resource "aws_s3_object" "server-pfx" {
    bucket = aws_s3_bucket.terraform-neo4j-nom-s3.bucket
    key = "server.pfx"
    source = "./assets/server.pfx"
    force_destroy = true
    depends_on = [ local_file.result ]
}

resource "aws_iam_instance_profile" "terraform-ec2-iam_instance_profile" {
  name = "TerraformAmazonS3ReadOnlyAccess"
  role = "S3FullAccess"
}

/*
Setup EC2 Instances | Neo4j Cluster | NOM Server
*/

locals {
  discovery_addresses = "${join(",", [for num in range(length(var.static_internal_ips)) : format("%s%s%s", replace("ip-${var.static_internal_ips[num]}", ".", "-"), ".ap-southeast-1.compute.internal", ":5000")])}"
}

resource "aws_key_pair" "your-public-key" {
  key_name   = "your-public-key"
  public_key = var.public-key
}

resource "aws_instance" "terraform-neo4j-cluster-nom" {
    count         = var.instance_count
    ami           = var.ami
    instance_type = "t2.medium"
    key_name = aws_key_pair.your-public-key.key_name
    subnet_id = aws_subnet.public.id
    private_ip = var.static_internal_ips[count.index]
    security_groups  = [aws_security_group.terraform-neo4j-nom-security-group.id]
    iam_instance_profile = aws_iam_instance_profile.terraform-ec2-iam_instance_profile.name

    user_data      = templatefile("./scripts/setup.tftpl", {
        neo4j_version              = "${var.neo4j_version}"
        nom_version                = "${var.nom_version}"
        bloom_version              = "${var.bloom_version}"
        apoc_version               = "${var.apoc_version}"
        initial_heap_size          = "${var.initial_heap_size}"
        max_heap_size              = "${var.max_heap_size}"
        page_cache_size            = "${var.page_cache_size}"
        allow_upgrade              = "${var.allow_upgrade}"
        bloom_license              = "${var.bloom_license}"
        db_owner                   = "${var.db_owner}"
        dbms_mode                  = "${var.dbms_mode}"
        discovery_addresses        = "${local.discovery_addresses}"
        s3_bucket                  = "${aws_s3_bucket.terraform-neo4j-nom-s3.bucket}"
        private_ip                 = "${format("%s%s", replace("ip-${var.static_internal_ips[count.index]}", ".", "-"), ".${var.region}.compute.internal")}"
        nom_server_dns             = "${format("%s%s", replace("ip-${var.nom_static_internal_ips}", ".", "-"), ".${var.region}.compute.internal")}"
        index_count                = "${count.index + 1}"  
    })
    associate_public_ip_address = true
  
    lifecycle {
        create_before_destroy = true
    }

    tags = {
        Name = "nom-terraform-neo4j-cluster-${count.index + 1}"
    }
}

## Setting up Neo4j Ops Manager Server
resource "aws_instance" "terraform-nom-server" {
    count         = 1
    ami           = var.ami
    instance_type = "t2.medium"
    key_name = aws_key_pair.your-public-key.key_name
    subnet_id = aws_subnet.public.id
    private_ip = var.nom_static_internal_ips
    security_groups  = [aws_security_group.terraform-neo4j-nom-security-group.id]
    iam_instance_profile = aws_iam_instance_profile.terraform-ec2-iam_instance_profile.name

    user_data      = templatefile("./scripts/nom_setup.tftpl", {
        neo4j_version              = "${var.neo4j_version}"
        nom_version                = "${var.nom_version}"
        bloom_version              = "${var.bloom_version}"
        apoc_version               = "${var.apoc_version}"
        initial_heap_size          = "${var.initial_heap_size}"
        max_heap_size              = "${var.max_heap_size}"
        page_cache_size            = "${var.page_cache_size}"
        allow_upgrade              = "${var.allow_upgrade}"
        bloom_license              = "${var.bloom_license}"
        db_owner                   = "${var.db_owner}"
        dbms_mode                  = "${var.dbms_mode}"
        discovery_addresses        = "${local.discovery_addresses}"
        s3_bucket                  = "${aws_s3_bucket.terraform-neo4j-nom-s3.bucket}"
        private_ip                 = "${format("%s%s", replace("ip-${var.nom_static_internal_ips}", ".", "-"), ".${var.region}.compute.internal")}"

    })
    associate_public_ip_address = true
  
    lifecycle {
        create_before_destroy = true
    }

    tags = {
        Name = "nom-terraform-server"
    }
}

resource "aws_eip" "ext_static" {
    count = var.instance_count
    instance = aws_instance.terraform-neo4j-cluster-nom[count.index].id
    domain   = "vpc"
}

resource "aws_eip_association" "eip_assoc" {
    count = var.instance_count
    instance_id   = aws_instance.terraform-neo4j-cluster-nom[count.index].id
    allocation_id = aws_eip.ext_static[count.index].id
}

resource "aws_eip" "nom_ext_static" {
    instance = aws_instance.terraform-nom-server[0].id
    domain   = "vpc"
}

resource "aws_eip_association" "nom_eip_assoc" {
    instance_id   = aws_instance.terraform-nom-server[0].id
    allocation_id = aws_eip.nom_ext_static.id
}

# resource local_file render_setup_template {
#   depends_on = [
#     aws_s3_object.neo4j-assets
#   ]
#   count = length(var.static_internal_ips)
#   filename = "./out/rendered_template_${count.index + 1}.txt"
#   content = templatefile("./scripts/setup.tftpl", {
#     "neo4j_version" = var.neo4j_version,
#     "bloom_version" = var.bloom_version,
#     "apoc_version" = var.apoc_version,
#     "initial_heap_size" = var.initial_heap_size,
#     "max_heap_size" = var.max_heap_size,
#     "page_cache_size" = var.page_cache_size,
#     "allow_upgrade" = var.allow_upgrade,
#     "bloom_license" = var.bloom_license,
#     "db_owner" = var.db_owner,
#     "dbms_mode" = var.dbms_mode,
#     "discovery_addresses" = local.discovery_addresses
#     "s3_bucket" = "${aws_s3_bucket.terraform-neo4j-nom-s3.bucket}"
#     })
# }

output "instance_ips" {
    description = "Public IPs of created instances"
    value       = {
        public_ip = "${aws_instance.terraform-neo4j-cluster-nom[*].public_ip}",
        private_ip = "${aws_instance.terraform-neo4j-cluster-nom[*].private_ip}",
    }
}

output "nom_server_ip" {
    description = "Public IP of created instance"
    value       =  {
        public_ip = "${aws_instance.terraform-nom-server[0].public_ip}",
        private_ip = "${aws_instance.terraform-nom-server[0].private_ip}",
    
    }
}