# Specify the provider and access details

provider "aws" {
  region     = "${var.aws_region}"
}

### Network

# Fetch AZs in the current region
data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  count      = "${var.enabled ? 1: 0}"
  cidr_block = "172.17.0.0/16"
  tags = {
    Name = "${var.prefix}"
  }
}

# Create var.az_count private subnets, each in a different AZ
resource "aws_subnet" "private" {
  count             = "${var.enabled ? var.az_count : 0}"
  cidr_block        = "${cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  vpc_id            = "${aws_vpc.main.id}"
  tags = {
    Name = "${var.prefix}-sub-pub"
  }
}

# Create var.az_count public subnets, each in a different AZ
resource "aws_subnet" "public" {
  count                   = "${var.enabled ? var.az_count : 0}"
  cidr_block              = "${cidrsubnet(aws_vpc.main.cidr_block, 8, var.az_count + count.index)}"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  vpc_id                  = "${aws_vpc.main.id}"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.prefix}-sub-priv"
  }
}

# IGW for the public subnet
resource "aws_internet_gateway" "gw" {
  count      = "${var.enabled ? 1: 0}"
  vpc_id     = "${aws_vpc.main.id}"
  tags = {
    Name = "${var.prefix}-gw"
  }
}

# Route the public subnet traffic through the IGW
resource "aws_route" "internet_access" {
  count                  = "${var.enabled ? 1: 0}"
  route_table_id         = "${aws_vpc.main.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.gw.id}"
}

# Create a NAT gateway with an EIP for each private subnet to get internet connectivity
resource "aws_eip" "gw" {
  count      = "${var.enabled ? var.az_count : 0}"
  vpc        = true
  depends_on = ["aws_internet_gateway.gw"]
  tags       = {
    Name = "${var.prefix}-eip"
  }
}

resource "aws_nat_gateway" "gw" {
  count         = "${var.enabled ? var.az_count : 0}"
  subnet_id     = "${element(aws_subnet.public.*.id, count.index)}"
  allocation_id = "${element(aws_eip.gw.*.id, count.index)}"
  tags       = {
    Name = "${var.prefix}-nat-gw"
  }
}

# Create a new route table for the private subnets
# And make it route non-local traffic through the NAT gateway to the internet
resource "aws_route_table" "private" {
  count  = "${var.enabled ? var.az_count : 0}"
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${element(aws_nat_gateway.gw.*.id, count.index)}"
  }
}

# Explicitely associate the newly created route tables to the private subnets (so they don't default to the main route table)
resource "aws_route_table_association" "private" {
  count          = "${var.enabled ? var.az_count : 0}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}

### Security

# ALB Security group
# This is the group you need to edit if you want to restrict access to your application
resource "aws_security_group" "lb" {
  count       = "${var.enabled ? 1: 0}"
  name        = "${var.prefix}-sg"
  description = "controls access to the ALB"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Traffic to the ECS Cluster should only come from the ALB
resource "aws_security_group" "ecs_tasks" {
  count       = "${var.enabled ? 1: 0}"
  name        = "${var.prefix}-sg-inbound"
  description = "allow inbound access from the ALB only"
  vpc_id      = "${aws_vpc.main.id}"

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
