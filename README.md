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
> Before run terraform, login to AWS console and create keypair name `ec2`. If you want to use other keypair, make sure to update this keypair name in `resource "aws_instance" {key_name}` of `main.tf`

```
terraform init
terraform apply --auto-approve
```

> Please aware that Nexus server use `instance type: t2.medium` which don't qualify under [AWS free tier](https://aws.amazon.com/free/)

> To be simple, we will not assign static IP (AWS EIP) for our servers in this lab. So be aware that the public IP will be change if you restart instance.

You can change `CIDRs`, `instance type`, `AMI` and `Security Group ports` in `variables.tf`. Scripts in `userdata/` for installing [Jenkins](/userdata/InstallJenkins.sh), [Nexus](/userdata/InstallNexus.sh), [Ansible](/userdata/InstallAnsibleController.sh), [Docker](/userdata/InstallDocker.sh).

> These installing scripts are written for AMI `Amazon Linux 2 AMI (HVM) - Kernel 5.10, SSD Volume Type`.

### User account and SSH Configuration

All provisioned EC2 use same keypair `ec2.pem` which is manual created on AWS console. `Jenkins Server` and `Nexus Server` use the default user of AWS EC2 (**ec2-user**)

You will notice these configuration in [Ansible](/userdata/InstallAnsibleController.sh) and [Docker](/userdata/InstallDocker.sh) userdata.

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

Use specific user account for Ansible (**ansibleadmin**) in Ansible controller and these managed node. This practice could help us limit the privileges of that account to only what is necessary for Ansible or tracking Ansible activity.

Enable `PasswordAuthentication` for SSH will help us grant SSH access easier between `Jenkins Server`, `Ansible Controller` and `Docker host` (Ansible managed node).

That's all you need to know to start! 🎉

### Created AWS Resources

4 EC2 with public IP addressed & internet connectivity.
![EC2](/docs/images/terraform-provisioned.png)

SG with inbound ports: `22`, `443`, `80`, `8081`, `8080`
> You can create specific SG with necessary ports for each EC2 instance instead of combine these ports in 1 SG.


## 📝 Create Jenkins pipeline

### Setup first time use

Open `http://[Jenkins-Server Public IPv4]:8080` on web browser
![Jenkins Login](/docs/images/jenkins-login.png)

Follow instruction to get the initial Administrator password by run
`sudo cat /var/lib/jenkins/secrets/initialAdminPassword` on Jenkins-server CLI.

Install suggested plugins for Jenkins
![Suggested Plugins](/docs/images/suggested-plugins.png)

After install, create your Jenkins account and domain configuration. We can start to use Jenkins
![Jenkins Ready](/docs/images/jenkins-ready.png)

### Create job

Click `+ New Item` or `Create a job`, enter a name and choose `Pipeline`. Then `Ok`:
![Create Pipeline](/docs/images/create-pipeline.png)

Scroll down to `Pipeline` section. 
- In `Definition`, select `Pipeline script from SCM` (We will pull Jenkinsfile from Source Code Management instead of type in Jenkinsfile context directly in this pipeline)
- In `SCM`, select `Git` (Suggested plugin we have installed contain Git plugin, allow us to poll, fetch, checkout and merge contents of git repositories.)
- In `Repository URL`, paste your Github repo URL 
![Github URL](/docs/images/repository.png)
>We checkout public repository with HTTPS so leave `Credentials` as `- none -`.
- In `Branch Specifier (blank for 'any')`, change to `*/main`

Click `Apply` and `Save`

> When run pipeline, Jenkins server will clone your git repository to workspace path on agent machine which run the pipeline. In this case, workspace path will be `/var/lib/jenkins/workspace/[Job name]` on Jenkins server EC2.

### Explain Jenkinsfile

#### Maven build
To use Maven to build artifacts from Java source code, we need to install Maven plugin. Go to `Manage Jenkins` > `Plugin Manager` > `Available plugins`, search and install `Maven Integration`:
![Maven Plugin](/docs/images/maven-plugin.png)

After install successfully, go to `Manage Jenkins` > `Global Tool Configuration`. Click `Add Maven`, enter `Name`. (You can select other version of Maven if you want)
![Maven Configure](/docs/images/maven-configure.png)
Click `Apply` and `Save`

These line below in Jenkinsfile will configure pipeline install Maven (`maven` in `''` is your `Name` you input in `Global Tool Configuration`)
```
tool {
  maven 'maven'
}
```
and use command `mvn clean install package` to build Java project:
```
stages {
        stage('Build') {
            steps {
                sh 'mvn clean install package'
            }
        }
        ...
}
```

#### pom.xml
As you can see, there is a `pom.xml` file in Github repository. We will define some information for our build artifact and update version everytime we want to update our project here. You can find more information about POM [here](https://maven.apache.org/guides/introduction/introduction-to-the-pom.html#).

```
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.mylab</groupId>
  <artifactId>MyLab</artifactId>
  <packaging>war</packaging>
  <version>0.0.1</version>
  <name>MyLab</name>
  <url>http://maven.apache.org</url>
  <dependencies>
    <dependency>
      <groupId>junit</groupId>
      <artifactId>junit</artifactId>
      <version>4.13.1</version>
      <scope>test</scope>
    </dependency>
  </dependencies>
  <build>
    <finalName>${project.artifactId}-${project.version}</finalName>
  </build>
</project>
```

To print these artifact information when we update and run pipeline, we will use environment variables in Jenkinsfile to get context from `pom.xml` file dynamically.
Install plugin `Pipeline Utility Steps`:
![Pipeline Utility Steps](/docs/images/pipeline-utility-steps.png)

In `Jenkinsfile`, these line will be get context from `pom.xml` of repository:
```
environment {
        ArtifactId = readMavenPom().getArtifactId()
        Version = readMavenPom().getVersion()
        GroupId = readMavenPom().getGroupId()
        Name = readMavenPom().getName()
    }
```

and print out when run pipeline:
```
stage('Print Environment variables') {
            steps {
                echo "Artifact ID is '${ArtifactId}'"
                echo "Group ID is '${GroupId}'"
                echo "Version is '${Version}'"
                echo "Name is '${Name}'"
            }
        }
```

#### Publish artifacts to Nexus repository

We will need store `RELEASE`/`SNAPSHOT` version everytime we update source code of java web. Here is how we do that using **Sonatype Nexus**

Open `http://[Nexus-Server Public IPv4]:8081` on web browser. Click `Login` on the upper-right corner.

Follow instruction to get the initial admin password by run
`sudo cat /opt/sonatype-work/nexus3/admin.password` on Nexus-server CLI.

![Nexus Login](/docs/images/nexus-login.png)

Continue to setup for first-time use. Choose `Enable anonymous access`.

> By default, Nexus has already provide us two repo `maven-releases` and `maven-snapshots`. Use can skip these step below if you want to use default repo. Just make sure remmeber these name to declare in the Jenkinsfile

Click to `Gear icon ⚙️` on top bar, then select `Repositories` on left-hand side. Choose `Create repository`
![Create Repository](/docs/images/create-nexus-repo.png)

Select Recipe: `maven2 (hosted)`
![Select Repository](/docs/images/select-nexus-repo.png)

Enter name: `MyLab-RELEASE` and choose `What type of artifacts does this repository store?` is `Release`
![RELEASE Repository](/docs/images/release-repo.png)

Repeat these steps above to create another repo with name: `MyLab-SNAPSHOT` and choose `What type of artifacts does this repository store?` is `Snapshot`
![SNAPSHOT Repository](/docs/images/snapshot-repo.png)

Return to your Nexus Browser tab and the result should be like that:
![Nexus Browser](/docs/images/nexus-browser.png)

Our goal is setup Jenkins pipeline to publish maven build artifact to Nexus repo, 


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