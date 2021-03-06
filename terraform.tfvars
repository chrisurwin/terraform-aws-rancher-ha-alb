name = "rancher-ha"
ami_id = "ami-xxxxxxxx"
instance_type = "t2.medium"
database_instance_class = "db.t2.medium"
key_name = "aws_ssh_key_name"
rancher_ssl_cert = "certificate.crt"
rancher_ssl_key = ".private.key"
rancher_ssl_chain = "ca_bundle.crt"
database_port = "3306"
database_name = "cattle"
database_username = "cattle"
database_password = "Password"
scale_min_size = "2"
scale_max_size = "2"
scale_desired_size = "2"
fqdn = "www.yoururl.com"
zone_id = "hosted zone id for your domain"
region = "eu-west-1"
vpc_id = "vpc-xxxxxxxx"
subnet1 = "subnet-xxxxxxxx"
subnet2 = "subnet-xxxxxxxx"
subnet3 = "subnet-xxxxxxxx"
az1 = "eu-west-1a"
az2 = "eu-west-1b"
az3 = "eu-west-1c"
rancher_version = "rancher/server:v1.2.0"