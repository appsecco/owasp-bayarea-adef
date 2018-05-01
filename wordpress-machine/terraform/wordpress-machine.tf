// AWS Provider for the entire setup
provider "aws" {
  # region = "${var.aws_region}"
  region = "us-east-1"
  # shared_credentials_file = "${pathexpand("~/.aws/credentials")}"
  profile = "default"
  # access_key = "${var.access_key}"
  # secret_key = "${var.secret_key}"
}

variable "uniquename" {}

variable "adefcustom" {
    type = "map"
    default {
        "tag" = "adef"
        "azone" = "us-east-1b"
        "wordpress_ip" = "192.168.1.20"
    }
}


##############################################################
# Data sources to get VPC, subnets and security group details
##############################################################
data "aws_vpc" "adeflab-vpc" {
      tags {
        Name = "adeflab-vpc"
        key = "${var.adefcustom["tag"]}"
    }
}

data "aws_subnet" "elastic-subnet" {
  vpc_id = "${data.aws_vpc.adeflab-vpc.id}"
    tags {
    Name = "elastic-subnet"
    key = "${var.adefcustom["tag"]}"
  }
}


// Creating elastic ip for wordpress machine
resource "aws_eip" "wordpress-eip" {
    tags {
        Name = "wordpress-eip"
        key = "${var.adefcustom["tag"]}"
    }
}


// Associating elastic ip to the wordpress machine
resource "aws_eip_association" "wordpress-eip-associate" {
  instance_id   = "${aws_instance.wordpress-machine.id}"
  allocation_id = "${aws_eip.wordpress-eip.id}"
}


// Uploading the ssh key pair to AWS
resource "aws_key_pair" "adeflabkey-wordpress" {
    key_name = "adeflabkey-wordpress"
    public_key = "${file("~/.ssh/id_rsa.pub")}"
}


// Creating wordpress machine
resource "aws_instance" "wordpress-machine" {
    ami = "ami-3c07b843"
    instance_type = "t2.micro"
    vpc_security_group_ids = ["${aws_security_group.wordpress-sg.id}"]
    private_ip = "${var.adefcustom["wordpress_ip"]}"    
    subnet_id = "${data.aws_subnet.elastic-subnet.id}"
    key_name = "${aws_key_pair.adeflabkey-wordpress.key_name}"
    user_data = <<-EOF
    #!/bin/bash
    sed -i '/packer/c\' /home/ubuntu/.ssh/authorized_keys
    mkdir -p /home/jumbo/.ssh
    cp /home/ubuntu/.ssh/authorized_keys /home/jumbo/.ssh/authorized_keys
    chown jumbo:jumbo -R /home/jumbo/.ssh
    sed -i 's/http:\/\/localhost/http:\/\/${var.uniquename}.cloudsec.training/g' /var/www/html/wp-config.php
    EOF

    lifecycle {
        create_before_destroy = true
    }

    tags {
        Name = "wordpress-machine"
        key = "${var.adefcustom["tag"]}"
    }

    // provisioner "local-exec" {
    //     command = "echo export jumboip=${aws_eip.wordpress-eip.public_ip} >> /home/student/.bash_profile"
    // }
}


// Creating wordpress security group
resource "aws_security_group" "wordpress-sg" {
    name = "security_group_for_wordpress"
    vpc_id = "${data.aws_vpc.adeflab-vpc.id}"
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
        Name = "wordpress-sg"
        key = "${var.adefcustom["tag"]}"
    }
}


// VPC FLOW LOG STUFF

resource "aws_flow_log" "vpc_flow_log" {
  log_group_name = "${aws_cloudwatch_log_group.adef_log_group.name}"
  iam_role_arn   = "${aws_iam_role.adef_role.arn}"
  vpc_id         = "${data.aws_vpc.adeflab-vpc.id}"
  traffic_type   = "ALL"
}

resource "aws_cloudwatch_log_group" "adef_log_group" {
  name = "adef_log_group"
}

resource "aws_iam_role" "adef_role" {
  name = "adef_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "vpc-flow-logs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "adef_policy" {
  name = "adef_policy"
  role = "${aws_iam_role.adef_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}


output "wordpress_machine_id" {
    value = "${aws_instance.wordpress-machine.id}"
}

// output "wordpress_key_name" {
//     value = "${aws_key_pair.adeflabkey.key_name}"
// }

// output "wordpress_sg_id" {
//     value = "${aws_security_group.wordpress-sg.id}"
// }

// output "wordpress_machine_iip" {
//     value = "${aws_instance.wordpress-machine.private_ip}"
// }

output "Your site is available at: " {
    value = "http://${var.uniquename}.cloudsec.training"
}

// Returing the wordpress public ip to access
output "Your wordpress machine IP address is: " {
    value = "${aws_eip.wordpress-eip.public_ip}"
}