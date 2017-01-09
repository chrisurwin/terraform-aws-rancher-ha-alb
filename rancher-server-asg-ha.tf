variable "name" {}
variable "ami_id" {}
variable "instance_type" {}
variable "key_name" {}
variable "rancher_ssl_cert" {}
variable "rancher_ssl_key"  {}
variable "rancher_ssl_chain"  {}
variable "database_port"    {}
variable "database_name"    {}
variable "database_username" {}
variable "database_password" {}
variable "scale_min_size" {}
variable "scale_max_size" {}
variable "scale_desired_size" {}
variable "region" {}
variable "vpc_id" {}
variable "az1" {}
variable "az2" {}
variable "az3" {}
variable "subnet1" {}
variable "subnet2" {}
variable "subnet3" {}
variable "zone_id" {}
variable "fqdn" {}
variable "database_instance_class" {}
variable "rancher_version" {}

#Create Security group for access to RDS instance
resource "aws_security_group" "rancher_ha_allow_db" {
  name = "${var.name}_allow_db"
  description = "Allow Connection from internal"
  vpc_id = "${var.vpc_id}"
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = "${var.database_port}"
    to_port = "${var.database_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

}
#Create RDS database
resource "aws_db_instance" "rancherdb" {
  allocated_storage    = 10
  engine               = "mysql"
  instance_class       = "${var.database_instance_class}" 
  name                 = "${var.database_name}"
  username             = "${var.database_username}"
  password             = "${var.database_password}"
  vpc_security_group_ids = ["${aws_security_group.rancher_ha_allow_db.id}"]
  }

resource "aws_iam_server_certificate" "rancher_ha"
 {
  name             = "${var.name}-cert"
  certificate_body = "${file("${var.rancher_ssl_cert}")}"
  private_key      = "${file("${var.rancher_ssl_key}")}"
  certificate_chain = "${file("${var.rancher_ssl_chain}")}"

  provisioner "local-exec" {
    command =  "ping 127.0.0.1 -n 10 > nul" # use -n on Windows terraform, and -c on linux
  }
}

# Into ALB from upstream
resource "aws_security_group" "rancher_ha_web_alb" {
  name = "${var.name}_web_alb"
  description = "Allow ports rancher "
  vpc_id = "${var.vpc_id}"
   egress {
     from_port = 0
     to_port = 0
     protocol = "-1"
     cidr_blocks = ["0.0.0.0/0"]
   }
   ingress {
      from_port = 443
      to_port = 443
      protocol = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
   }
}

#Into servers
resource "aws_security_group" "rancher_ha_allow_alb" {
  name = "${var.name}_allow_alb"
  description = "Allow Connection from alb"
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
      from_port = 8080
      to_port = 8080
      protocol = "tcp"
      security_groups = ["${aws_security_group.rancher_ha_web_alb.id}"]
  }
}

#Direct into Rancher HA instances
resource "aws_security_group" "rancher_ha_allow_internal" {
  name = "${var.name}_allow_internal"
  description = "Allow Connection from internal"
  vpc_id = "${var.vpc_id}"
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 9345
    to_port = 9345
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "ingress_all_rancher_ha" {
    security_group_id = "${aws_security_group.rancher_ha_allow_internal.id}"
    type = "ingress"
    from_port = 0
    to_port = "0"
    protocol = "-1"
    source_security_group_id = "${aws_security_group.rancher_ha_allow_internal.id}"
}

resource "aws_security_group_rule" "egress_all_rancher_ha" {
    security_group_id = "${aws_security_group.rancher_ha_allow_internal.id}"
    type = "egress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    source_security_group_id = "${aws_security_group.rancher_ha_allow_internal.id}"
}
# User-data template
data "template_file" "userdata" {

    template = "${file("${path.module}/files/userdata.template")}"

    vars {
        # Database
        database_address  = "${aws_db_instance.rancherdb.address}"
        database_port     = "${var.database_port}"
        database_name     = "${var.database_name}"
        database_username = "${var.database_username}"
        database_password = "${var.database_password}"
        rancher_version = "${var.rancher_version}"
    }
}

provider "aws" {
    region = "${var.region}"
}

# Create a new load balancer
resource "aws_alb" "rancher_ha" {
  name = "${var.name}-alb"
  internal = false
  security_groups = ["${aws_security_group.rancher_ha_web_alb.id}"]
  subnets = ["${var.subnet1}","${var.subnet2}","${var.subnet3}"]
}

resource "aws_alb_target_group" "rancher_ha" {
 name = "${var.name}-tg"
 port = 8080
 protocol = "HTTP"
 vpc_id = "${var.vpc_id}"
 health_check {
   path="/ping"
 }
}

resource "aws_alb_listener" "rancher_ha" {
   load_balancer_arn = "${aws_alb.rancher_ha.arn}"
   port = "443"
   protocol = "HTTPS"
   ssl_policy = "ELBSecurityPolicy-2015-05"
   certificate_arn = "${aws_iam_server_certificate.rancher_ha.arn}"

   default_action {
     target_group_arn = "${aws_alb_target_group.rancher_ha.arn}"
     type = "forward"
   }
}

resource "aws_autoscaling_group" "rancher_ha" {
  name   = "${var.name}-asg"
  min_size = "${var.scale_min_size}"
  max_size = "${var.scale_max_size}"
  desired_capacity = "${var.scale_desired_size}"
  health_check_grace_period = 900
  #health_check_type = "alb"
  force_delete = true
  launch_configuration = "${aws_launch_configuration.rancher_ha.name}"
  target_group_arns = ["${aws_alb_target_group.rancher_ha.arn}"]
  #load_balancers = ["${aws_alb.rancher_ha.name}"]
  availability_zones = ["${var.az1}","${var.az2}","${var.az3}"]
  tag {
    key = "Name"
    value = "${var.name}"
    propagate_at_launch = true
  }
  lifecycle {
      create_before_destroy = true
  }

}

# rancher resource
resource "aws_launch_configuration" "rancher_ha" {
    name_prefix = "Launch-Config-rancher-server-ha"
    image_id = "${var.ami_id}"
    security_groups = [ "${aws_security_group.rancher_ha_allow_alb.id}",
                        "${aws_security_group.rancher_ha_web_alb.id}",
                   "${aws_security_group.rancher_ha_allow_internal.id}"]
    instance_type = "${var.instance_type}"
    key_name      = "${var.key_name}"
    user_data     = "${data.template_file.userdata.rendered}"
    associate_public_ip_address = false
    ebs_optimized = false
    lifecycle {
      create_before_destroy = true
    }

}

output "alb_dns"      { value = "${aws_alb.rancher_ha.dns_name}" }

#### Remove below here if you don't want Route 53 to handle the DNS zone####

# works
resource "aws_route53_record" "www" {
   zone_id = "${var.zone_id}"
   name = "${var.fqdn}"
   type = "CNAME"
   ttl = "300"
   records = ["${aws_alb.rancher_ha.dns_name}"]
}
