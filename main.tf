provider "aws" {
  region = "${var.aws_region}"
  profile = "${var.aws_profile}"
}


# Availability Zones

data "aws_availability_zones" "available" {}

resource "aws_vpc" "mobiq_vpc"{
  cidr_block = "10.0.0.0/16"

  tags{
    Name = "mobiq_vpc"
  }
}


# VPC
resource "aws_internet_gateway" "mobiq_igw"{
  vpc_id = "${aws_vpc.mobiq_vpc.id}"

  tags{
    Name = "mobiq_igw"
  }
}

# Routes

#Public
resource "aws_route_table" "mobiq_rt_public"{
  vpc_id = "${aws_vpc.mobiq_vpc.id}"
  route{
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.mobiq_igw.id}"
  }
  tags{
    Name = "mobiq_rt_public"
  }
}


# Private
resource "aws_route_table" "mobiq_rt_private"{
  vpc_id = "${aws_vpc.mobiq_vpc.id}"
  tags{
    Name = "mobiq_rt_private"
  }
}

# Subnet

# public
resource "aws_subnet" "mobiq_sn_public_a"{
  vpc_id = "${aws_vpc.mobiq_vpc.id}"
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "${data.aws_availability_zones.available.names[0]}"
  tags{
    Name = "mobiq_sn_public_a"
  }
}

resource "aws_subnet" "mobiq_sn_public_b"{
  vpc_id = "${aws_vpc.mobiq_vpc.id}"
  cidr_block = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone = "${data.aws_availability_zones.available.names[1]}"
  tags{
    Name = "mobiq_sn_public_b"
  }
}

# private
resource "aws_subnet" "mobiq_sn_private_a"{
  vpc_id = "${aws_vpc.mobiq_vpc.id}"
  cidr_block = "10.0.3.0/24"
  map_public_ip_on_launch = false
  availability_zone = "${data.aws_availability_zones.available.names[0]}"
  tags{
    Name = "mobiq_sn_private_a"
  }
}

resource "aws_subnet" "mobiq_sn_private_b"{
  vpc_id = "${aws_vpc.mobiq_vpc.id}"
  cidr_block = "10.0.4.0/24"
  map_public_ip_on_launch = false
  availability_zone = "${data.aws_availability_zones.available.names[1]}"
  tags{
    Name = "mobiq_sn_private_b"
  }
}

resource "aws_subnet" "mobiq_sn_rds1"{
  vpc_id = "${aws_vpc.mobiq_vpc.id}"
  cidr_block = "10.0.5.0/24"
  map_public_ip_on_launch = false
  availability_zone = "${data.aws_availability_zones.available.names[3]}"
  tags{
    Name = "mobiq_sn_rds1"
  }
}


# Route_Subnet Association

resource "aws_route_table_association" "rt_sn_public_a"{
  subnet_id = "${aws_subnet.mobiq_sn_public_a.id}"
  route_table_id = "${aws_route_table.mobiq_rt_public.id}"
}

resource "aws_route_table_association" "rt_sn_public_b"{
  subnet_id = "${aws_subnet.mobiq_sn_public_b.id}"
  route_table_id = "${aws_route_table.mobiq_rt_public.id}"
}

resource "aws_route_table_association" "rt_sn_private_a"{
  subnet_id = "${aws_subnet.mobiq_sn_private_a.id}"
  route_table_id = "${aws_route_table.mobiq_rt_private.id}"
}

resource "aws_route_table_association" "rt_sn_private_b"{
  subnet_id = "${aws_subnet.mobiq_sn_private_b.id}"
  route_table_id = "${aws_route_table.mobiq_rt_private.id}"
}


#Security groups

resource "aws_security_group" "public" {
  name = "sg_public"
  description = "Used for public and private instances for load balancer access"
  vpc_id = "${aws_vpc.mobiq_vpc.id}"


#SSH 

  ingress {
    from_port   = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["${var.localip}"]
  }

  #HTTP 

  ingress {
    from_port   = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #Outbound internet access

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}
# key pair

resource "aws_key_pair" "auth" {
  key_name  ="${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

# server

resource "aws_instance" "dev" {
  instance_type = "${var.dev_instance_type}"
  ami = "${var.dev_ami}"
  tags {
    Name = "wordpress-instance"
  }

  key_name = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.public.id}"]
  subnet_id = "${aws_subnet.mobiq_sn_public_a.id}"


  provisioner "local-exec" {
      command = <<EOD
cat <<EOF > aws_hosts 
[dev] 
${aws_instance.dev.public_ip} 
EOF
EOD
  }

  provisioner "local-exec" {
    command = "sleep 6m && ansible-playbook -i aws_hosts wordpress.yml"
  }
}



