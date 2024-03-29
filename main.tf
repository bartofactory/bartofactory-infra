resource "aws_vpc" "main" {
 cidr_block = "10.0.0.0/16"
 
 tags = {
   Name = "Bartofactory VPC"
 }
}

resource "aws_subnet" "public_subnets" {
 count             = length(var.public_subnet_cidrs)
 vpc_id            = aws_vpc.main.id
 cidr_block        = element(var.public_subnet_cidrs, count.index)
 availability_zone = element(var.azs, count.index)
 
 tags = {
   Name = "Public Subnet ${count.index + 1}"
 }
}
 
resource "aws_subnet" "private_subnets" {
 count             = length(var.private_subnet_cidrs)
 vpc_id            = aws_vpc.main.id
 cidr_block        = element(var.private_subnet_cidrs, count.index)
 availability_zone = element(var.azs, count.index)
 
 tags = {
   Name = "Private Subnet ${count.index + 1}"
 }
}

resource "aws_internet_gateway" "gw" {
 vpc_id = aws_vpc.main.id
 
 tags = {
   Name = "Project VPC IG"
 }
}

resource "aws_route_table" "second_rt" {
 vpc_id = aws_vpc.main.id
 
 route {
   cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.gw.id
 }
 
 tags = {
   Name = "Route to IGW"
 }
}

resource "aws_route_table_association" "public_subnet_asso" {
 count = length(var.public_subnet_cidrs)
 subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
 route_table_id = aws_route_table.second_rt.id
}

# --------------------

resource "aws_security_group" "gpu_instance_sg" {
  name        = "gpu_instance_sg"
  description = "Security Group per istanza EC2 con GPU"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "ec2_stable_diffusion_key" {
	key_name = var.ssh-key-name
	public_key = "${file("~/.ssh/ec2-stable_diffusion.pub")}"
}
resource "aws_ebs_volume" "myebs" {
 availability_zone = var.azs[0]
 size              = 40
 
 tags = {
   Name = "MyEBS"
 }
}

# Creating Ubuntu EC2 instance
resource "aws_instance" "stable_diffusion_instance" {
  ami             = "ami-0faab6bdbac9486fb"
  instance_type   = "g4ad.xlarge"
  key_name        = var.ssh-key-name
  vpc_security_group_ids = [aws_security_group.gpu_instance_sg.id]
  
  
  subnet_id                   = aws_subnet.public_subnets[0].id
  associate_public_ip_address = true

#   user_data = <<-EOF
#   #!/bin/bash -ex

#   amazon-linux-extras install nginx1 -y
#   echo "<h1>$(curl https://api.kanye.rest/?format=text)</h1>" >  /usr/share/nginx/html/index.html 
#   systemctl enable nginx
#   systemctl start nginx
#   EOF
  
  tags = {
    Name = "stable_diffusion"
  }
}

resource "aws_volume_attachment" "ebs_att" {
 device_name = "/dev/sdh"
 volume_id   = aws_ebs_volume.myebs.id
 instance_id = aws_instance.stable_diffusion_instance.id
}