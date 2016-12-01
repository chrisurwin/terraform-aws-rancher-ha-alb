# terraform-aws-rancher-ha-alb
Rancher Server v1.2.0 terraform script to stand up Rancher HA cluster on AWS

This script will setup HA on AWS with SSL terminating on an ALB with an appropriately configured variable file. This was developed so that it should be simple for someone to stand up a Rancher HA server and test its functionality.

It will create the appropriate security groups, ALB, RDS and EC2 instances. It will also set up the route53 zone, if you don't want this remove the 

Usage
You will need to update the sample tf.vars file with appropriate values

This was tested with Rancher OS 0.7.1
