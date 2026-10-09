region             = "us-east-1"
cluster_name       = "devboard"
kubernetes_version = "1.34"

node_instance_type = "c7i-flex.large"
node_desired_size  = 2
node_min_size      = 2
node_max_size      = 3

ec2_instance_type = "t3.micro"
ec2_key_name      = "terra-automate-key"
# Set this to your public IP in CIDR form, for example "YOUR_PUBLIC_IP/32".
