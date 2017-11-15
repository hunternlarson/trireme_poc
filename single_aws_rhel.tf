# Ohio
variable "region" {
    default="us-east-2"
}

provider "aws" {
  # set in env variables
  #access_key = "${var.access_key}"
  #secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

#variable "access_key" {}
#variable "secret_key" {}

#hnl
# Need to generate key pair locally that we wish to use.
# ssh-keygen -t rsa -b 4096 -C "calico@npd.com"
variable "public_key_path" {
  description = <<DESCRIPTION
Path to the SSH public key to be used for authentication.
Ensure this keypair is added to your local SSH agent so provisioners can
connect.
Example: ~/.ssh/calico_test.pub
DESCRIPTION
  default="C:\\Users\\hunter.n.larson\\OneDrive - Accenture\\Important\\keys\\AWS\\jp-lab\\hnl-overlay-v2-npd.pub"
}

variable "private_key_path" {
  default="C:\\Users\\hunter.n.larson\\OneDrive - Accenture\\Important\\keys\\AWS\\jp-lab\\hnl-overlay-v2-npd.pem"
}

#hnl
variable "key_name" {
  description = "wg_bare_metal key pair"
  default="hnl-overlay-v2-npd"
}

variable "vpc_id" {
  default="vpc-9b447af2"
}

variable "subnet_id" {
    default = "subnet-eea1ae87"
}

variable "amis" {
  type = "map"
  default = {
    us-east-2 = "ami-cfdafaaa" #Red Hat Enterprise Linux 7.4 (HVM), SSD Volume Type
  }
}

data "aws_subnet" "selected" {
  id = "${var.subnet_id}"
}

resource "aws_instance" "single_instance_rhel" {
  ami           = "${lookup(var.amis, var.region)}"
  instance_type = "t2.micro"
  subnet_id = "${data.aws_subnet.selected.id}"
  
  tags {
    Name = "hnl_tf_single_instance_rhel"
  }

  # The name of our SSH keypair we created above.
  key_name = "${var.key_name}"
  
  # The connection block tells our provisioner how to
  # communicate with the resource (instance)
  connection {
    type = "ssh"
    user = "ec2-user"
    private_key = "${file(var.private_key_path)}"
    agent="false"
  }
  
  # Security group for inbound 80 and 22
  vpc_security_group_ids = ["sg-cc1291a4"]

  provisioner "file" {
    source = "provision/setup-notes"
    destination = "/home/ec2-user/setup-notes"
  }

  provisioner "remote-exec" {
    inline = [<<EOF
        mkdir /home/ec2-user/src
    EOF
    ]
  }
  
  provisioner "file" {
    source = "provision/my-test-project"
    destination = "/home/ec2-user/src/my-test-project"
  }

  provisioner "remote-exec" {
    inline = [<<EOF
        sudo yum install iperf3
    
        sudo curl -O https://storage.googleapis.com/golang/go1.8.linux-amd64.tar.gz
        sudo tar -xvf go1.8.linux-amd64.tar.gz
        
        export PATH=$PATH:/usr/local/go/bin
        export GOPATH=$HOME
        #custom builds here
        export PATH=$PATH:$GOPATH/bin
        sudo mv go /usr/local
        echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.profile
        source ~/.profile
        go install my-test-project
        sudo $GOPATH/bin/my-test-project

        sudo yum install -y yum-utils \
        device-mapper-persistent-data \
        lvm2
        sudo yum-config-manager \
        --add-repo \
        https://download.docker.com/linux/centos/docker-ce.repo

        # for AWS
        sudo yum-config-manager --enable rhui-REGION-rhel-server-extras

        sudo yum -y install docker-ce

        sudo systemctl start docker

        
        #L follows redirects, -k if certificate missing
        sudo curl -LkSs https://api.github.com/repos/aporeto-inc/trireme-example/tarball -o master-example.tar.gz
        sudo tar -xvf master-example.tar.gz

    EOF
    ]
  }
  
}

