<h1 align="center">
  <img alt="pipeline diagram" src="./docs/images/pipeline.png" width="100%"/><br/>
  CI/CD Pipeline for Java Webapp
</h1>
<p align="center">Create a <b>Continuous Integration/Continuous Deployment</b> pipeline to deploy an simple Java web application.<br/>Focus on automation the process for <b>DevOps</b>.</p>

<p align="center"><a href="https://www.terraform.io/" target="_blank"><img src="https://img.shields.io/badge/-Terraform-7B42BC?logo=terraform&logoColor=white" alt="terraform" /></a>&nbsp;<a href="https://www.jenkins.io/" target="_blank"><img src="https://img.shields.io/badge/-Jenkins-D24939?logo=jenkins&logoColor=white" alt="jenkins" /></a>&nbsp;<a href="https://www.ansible.com/" target="_blank"><img src="https://img.shields.io/badge/-Ansible-EE0000?logo=ansible&logoColor=white" alt="ansible" /></a>&nbsp;<a href="https://www.docker.com/" target="_blank"><img src="https://img.shields.io/badge/-Docker-2496ED?logo=docker&logoColor=white" alt="Docker" /></a>&nbsp;<a href="https://aws.amazon.com/" target="_blank"><img src="https://img.shields.io/badge/-Amazon%20AWS-FF9900?logo=amazon-aws&logoColor=white" alt="AWS" /></a></p>

## ⚡️ Overview

CI/CD pipeline with Jenkins include of these tasks:
- Pull web app source code and Jenkinsfile to Jenkins server from GitHub.
- Install & build artifacts with Maven on Jenkins server.
- Publish artifacts to the Nexus repository in the Nexus server.
- Use Ansible to download the latest artifacts in the Nexus repository to the Docker host and deploy them on the Docker container.

## 📖 Project Structure

```
cicd-pipeline-java-webapp/
├── src/main/webapp
├── userdata/
├── .gitignore
├── Jenkinsfile
├── README.md
├── download-deploy.yaml
├── hosts
├── main.tf
├── variables.tf
└── pom.xml
```

## ⚙️ Provisioning Infrastructures on AWS with Terraform

You will need:
- The [Terraform CLI](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) (1.2.0+) installed.
- The [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) installed.
- [AWS account](https://aws.amazon.com/free) and [associated credentials](https://docs.aws.amazon.com/IAM/latest/UserGuide/security-creds.html) that allow you to create resources.

>🔔 In Windows, make sure that you add the path of the TF CLI and AWS CLI executable to your PATH environment variable so that you can run from any directory on your laptop/computer. 

Open terminal and run

```
aws configure
```

You will need to input:
```
AWS Access Key ID
AWS Secret Access Key
Default region name
Default output format 
```

Copy 2 files `main.tf`, `variables.tf` and folder `userdata/` of this Github repo to your working directory. Run these following commands to start provisioning:

```
terraform init
terraform apply --auto-approve
```

You can change CIDRs, instance type, AMI and Security Group ports in `variables.tf`. Scripts in `userdata/` for installing Jenkins, Nexus, Ansible, Docker.

> These installing scripts are written for AMI `Amazon Linux 2 AMI (HVM) - Kernel 5.10, SSD Volume Type`.

#### User and SSH Configuration for Ansible

You will notice these configuration in Ansible and Docker userdata.

```
# Add user ansible admin
useradd ansibleadmin

# Set password: the below command will avoid re-entering the password
echo "ansibleadmin" | passwd --stdin ansibleadmin

# Modify the sudoers file at /etc/sudoers and add entry
echo 'ansibleadmin  ALL=(ALL)   NOPASSWD: ALL' | tee -a /etc/sudoers
echo 'ec2-user ALL=(ALL) NOPASSWD: ALL' | tee -a /etc/sudoers

# Enable Password Authentication
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart sshd
```

Use specific user account for Ansible in Ansible controller and these managed node. This practice could help us limit the privileges of that account to only what is necessary for Ansible or tracking Ansible activity.

Enable Password Authentication for SSH will help us grant SSH access easier between Jenkins Server, Ansible Controller and Docker host (Ansible managed node).

That's all you need to know to start! 🎉

### 📝 Setup Jenkins



### 🐳 Docker-way to quick start


> 🔔 

### `create`



- 📺 Full demo video: 
- 📖 Docs: 

### `deploy`

CLI command for deploy Docker containers with your project via Ansible to the remote server.

> 🔔 Make sure that you have [Python 3.8+](https://www.python.org/downloads/) and [Ansible 2.9+](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-ansible-on-specific-operating-systems) installed on your computer.

- 📺 Full demo video:
- 📖 Docs:

## 📝 Production-ready project templates

### Backend



## 🚚 Pre-configured Ansible roles

### Web/Proxy server

- Roles for run Docker container with [Traefik Proxy](https://traefik.io/traefik/):
  - `traefik` — configured Traefik container with a simple ACME challenge via CA server.
  - `traefik-acme-dns` — configured Traefik container with a complex ACME challenge via DNS provider.
- Roles for run Docker container with [Nginx](https://nginx.org):
  - `nginx` — pure Nginx container with "the best practice" configuration.

> ✌️ 


## ⭐️ 