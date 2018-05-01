// AWS Provider for the entire setup
provider "aws" {
  # region = "${var.aws_region}"
  region = "us-east-1"
  # shared_credentials_file = "${pathexpand("~/.aws/credentials")}"
  profile = "default"
  # access_key = "${var.access_key}"
  # secret_key = "${var.secret_key}"
}

variable "adefcustom" {
    type = "map"
    default {
        "tag" = "adef"
        "azone" = "us-east-1b"
        "elastic_stack_ip" = "192.168.1.10"
    }
}


// Creating new vpc
resource "aws_vpc" "adeflab-vpc" {
    cidr_block = "192.168.0.0/16"
    instance_tenancy = "default"
    enable_dns_support = "true"
    enable_dns_hostnames = "true"
    enable_classiclink = "false"
    tags {
       Name = "adeflab-vpc"
       key = "${var.adefcustom["tag"]}"
    }
}


// Creating elastic in (public) subnet
resource "aws_subnet" "elastic-subnet" {
    vpc_id = "${aws_vpc.adeflab-vpc.id}"
    cidr_block ="192.168.1.0/24"
    map_public_ip_on_launch = "true"
    availability_zone = "${var.adefcustom["azone"]}"
    tags {
        Name = "elastic-subnet"
        key = "${var.adefcustom["tag"]}"      
    }
}


// Creating internet gateway for vpc
resource "aws_internet_gateway" "elastic-igw" {
    vpc_id = "${aws_vpc.adeflab-vpc.id}"
    tags {
        Name = "elastic-igw"
        key = "${var.adefcustom["tag"]}"
    }
}


// Creating subnet route table for elastic
resource "aws_route_table" "elastic-route" {
    vpc_id = "${aws_vpc.adeflab-vpc.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.elastic-igw.id}"
    }
    tags {
        Name = "elastic-route"
        key = "${var.adefcustom["tag"]}"
    }
}


// Associating elastic subnet in route table
resource "aws_route_table_association" "elastic-associate-subnet" {
    subnet_id = "${aws_subnet.elastic-subnet.id}"
    route_table_id = "${aws_route_table.elastic-route.id}"
}


// Creating elastic ip for elastic-stack machine
resource "aws_eip" "elastic-eip" {
    tags {
        Name = "elastic-eip"
        key = "${var.adefcustom["tag"]}"
    }
}


// Associating elastic ip to the elastic machine
resource "aws_eip_association" "elastic-eip-associate" {
  instance_id   = "${aws_instance.elastic-machine.id}"
  allocation_id = "${aws_eip.elastic-eip.id}"
}


// Uploading the ssh key pair to AWS
resource "aws_key_pair" "adeflabkey-elastic" {
    key_name = "adeflabkey-elastic"
    public_key = "${file("~/.ssh/id_rsa.pub")}"
}


// Creating elastic machine
resource "aws_instance" "elastic-machine" {
    ami = "ami-fd0cb382"
    instance_type = "t2.medium"
    vpc_security_group_ids = ["${aws_security_group.elastic-sg.id}"]
    private_ip = "${var.adefcustom["elastic_stack_ip"]}"
    subnet_id = "${aws_subnet.elastic-subnet.id}"
    key_name = "${aws_key_pair.adeflabkey-elastic.key_name}"
    user_data = <<-EOF
    #!/bin/bash
    sed -i '/packer/c\' /home/ubuntu/.ssh/authorized_keys
    id
    EOF

    lifecycle {
        create_before_destroy = true
    }

    tags {
        Name = "elastic-machine"
        key = "${var.adefcustom["tag"]}"
    }

}


// Creating elastic security group
resource "aws_security_group" "elastic-sg" {
    name = "security_group_for_elastic"
    vpc_id = "${aws_vpc.adeflab-vpc.id}"
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 5044
        to_port = 5044
        protocol = "tcp"
        cidr_blocks = ["192.168.0.0/16"]
    }

    egress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    lifecycle {
        create_before_destroy = true
    }

    tags {
        Name = "elastic-sg"
        key = "${var.adefcustom["tag"]}"
    }
}


// output "adeflab_vpc_id" {
//     value = "${aws_vpc.adeflab-vpc.id}"
// }

// output "elastic_subnet_id" {
//     value = "${aws_subnet.elastic-subnet.id}"
// }

// output "elastic_igw_id" {
//     value = "${aws_internet_gateway.elastic-igw.id}"
// }

// output "elastic_route_id" {
//     value = "${aws_route_table.elastic-route.id}"
// }

// output "elastic_eip_id" {
//     value = "${aws_eip.elastic-eip.id}"
// }

// output "elastic_eip_public_ip" {
//     value = "${aws_eip.elastic-eip.public_ip}"
// }

output "elastic_machine_id" {
    value = "${aws_instance.elastic-machine.id}"
}

// output "elastic_key_name" {
//     value = "${aws_key_pair.adeflabkey.key_name}"
// }

// output "elastic_sg_id" {
//     value = "${aws_security_group.elastic-sg.id}"
// }

// output "elastic_machine_iip" {
//     value = "${aws_instance.elastic-machine.private_ip}"
// }

// Returing the elastic public ip to access
output "Your elastic machine IP address is: " {
    value = "${aws_eip.elastic-eip.public_ip}"
}