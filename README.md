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

### Created AWS Resources

4 EC2 with public IP addressed & internet connectivity.
![EC2](/docs/images/terraform-provisioned.png)

SG with inbound ports: `22`, `443`, `80`, `8081`, `8080`
> You can create specific SG with necessary ports for each EC2 instance instead of combine these ports in 1 SG.

### User account and SSH Configuration

All provisioned EC2 use same keypair `ec2` which is manual created on AWS console, you can use it to SSH remote EC2 CLI later. 

`Jenkins Server` and `Nexus Server` use the default user of AWS EC2: **ec2-user**. For `Ansible Controller` and `Dockerhost`, you will notice these configuration in [Ansible](/userdata/InstallAnsibleController.sh) and [Docker](/userdata/InstallDocker.sh) userdata:

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


## 📝 Create Jenkins pipeline

### Setup first time use

Open `http://[Your Jenkins-Server Public IPv4]:8080` on web browser
![Jenkins Login](/docs/images/jenkins-login.png)

Follow instruction to get the initial Administrator password by run
`sudo cat /var/lib/jenkins/secrets/initialAdminPassword` on Jenkins-server CLI.

Install suggested plugins for Jenkins
![Suggested Plugins](/docs/images/suggested-plugins.png)

After install, create your Jenkins account and domain configuration. We can start to use Jenkins
![Jenkins Ready](/docs/images/jenkins-ready.png)

### Create job

Click `+ New Item` or `Create a job`, enter a name `JavaWeb` and choose `Pipeline`. Then click `OK`:
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
To use Maven to build artifacts from Java source code, we need to install Maven plugin. Go to `Manage Jenkins` > `Manage Plugins` > `Available plugins`, search and install `Maven Integration`:
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

**Setup on Nexus-Server**

Open `http://[Your Nexus-Server Public IPv4]:8081` on web browser. Click `Login` on the upper-right corner.

Follow instruction to get the initial admin password by run
`sudo cat /opt/sonatype-work/nexus3/admin.password` on Nexus-server CLI.

![Nexus Login](/docs/images/nexus-login.png)

Continue to setup new passwod for first-time use. Choose `Enable anonymous access`.
In this instruction, my `Nexus account` is **admin** with password **admin**

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

**Setup on Jenkins-Server**

Our goal is setup Jenkins pipeline to publish maven build artifact to corresponding Nexus repo. 
First, we need to `Add Credentials` to access `Nexus repositories`.
- Kind: `Username with password`
- Username: **admin**
- Password: **admin**
- ID: **nexus**

![Nexus Credential](/docs/images/nexus-credential.png)

Click `Create`
![Nexus Credential2](/docs/images/nexus-credential2.png)

Then, installing `Nexus Artifact Uploader` plugin on Jenkins Server:
![Nexus Plugin](/docs/images/nexus-plugin.png)

After install the plugin. Open our created Jenkins pipeline, which is `JavaWeb` as I named it before. On the left-side bar, select `Pipeline Syntax` > `Snippet Generator` to generate syntax of `Jenkinsfile`. Choose `Sample Step` is `nexusArtifactUploader: Nexus Artifact Uploader`
![Pipeline Syntax](/docs/images/pipeline-syntax-nexus.png)

- Nexus Version: `NEXUS3`
- Protocol: `HTTP`
- Nexus URL: `[Your Nexus-Server Public IPv4]:8081`
- Credentials: select your nexus credential you just created in previous step.
- GroupId: **${GroupId}**
- Version: **${Version}**
- Repository: **${NexusRepo}**

- Artifacts: click `Add`. ![artifact](/docs/images/artifact.png)


> We use these `${environment variable}` instead of hard code to update information in `pom.xml` dynamically.

Click `Generate Pipeline Script`, we will have:
![Syntax](/docs/images/generate-pipeline.png)

Copy this syntax to your `Jenkinsfile` then return to `Dashboard`. Here is my `Nexus stage` syntax in `Jenkinsfile`:

```
stage('Publish to Nexus') {
            steps { 
                script {
                    def NexusRepo = Version.endsWith("SNAPSHOT") ? "MyLab-SNAPSHOT" : "MyLab-RELEASE"
                    
                    nexusArtifactUploader artifacts: 
                    [
                        [
                            artifactId: "${ArtifactId}", 
                            classifier: '', 
                            file: "target/${ArtifactId}-${Version}.war", 
                            type: 'war'
                        ]
                    ], 
                    credentialsId: 'nexus', 
                    groupId: "${GroupId}", 
                    nexusUrl: '10.0.0.48:8081', 
                    nexusVersion: 'nexus3', 
                    protocol: 'http', 
                    repository: "${NexusRepo}", 
                    version: "${Version}"
                }
            }
        }
```

>`def NexusRepo = Version.endsWith("SNAPSHOT") ? "MyLab-SNAPSHOT" : "MyLab-RELEASE"` use to select `Nexus repo` base on `version` in `pom.xml` file. 

#### Configure Ansible Controller to Jenkins pipeline.
Deploy stage in pipeline will use Ansible. Before that, we need to add Credential for `Jenkins Server` access `Ansible Controller`.

Go to `Manage Jenkins` > `Plugin Manager`, search `Publish Over SSH` plugin on Jenkins Server and choose `Download now and install after restart`
![Publish Over SSH Plugin](/docs/images/publish-over-ssh-plugin.png)

After install successfully, go to `Manage Jenkins` > `Configure System`. Scroll down to the bottom at section **SSH Servers**, click `Add`:
- Name: **ansible-controller**
- Hostname: **[Your Ansible Controller Private IP]**
- Username: **ansibleadmin**
- Remote Directory: **/home/ansibleadmin**

Click `Advanced` and check `Use password authentication, or use a different key`
- Passphrase / Password: **ansibleadmin**

Scroll down and click `Test Configuration`, it should be show `Success` as below
![SSH Server](/docs/images/SSH-server-ansible.png)

Click `Apply` and `Save`.

> Our goal is transfer `ansible playbook files`, `ansible inventory files` on `Jenkins-Server` to `Ansible-Controller` and run it by `Ansible CLI`

Open our created Jenkins pipeline `JavaWeb` again. On the left-side bar, select `Pipeline Syntax` > `Snippet Generator` to generate syntax of `Jenkinsfile`. Choose `Sample Step` is `sshPublisher: Send build artifacts over SSH`.

- Name: select `ansible-controller`
Transfer Set:
- Source files: `download-deploy.yaml, hosts`
- Remote directory: `/playbooks` (this directory on `Ansible-Controller` will be created to store source files transfer from `Jenkins-Server`)
- Exec command: ``cd playbooks/ && ansible-playbook download-deploy.yaml -i hosts``

Click `Generate Pipeline Script`, we will have:
![Syntax](/docs/images/generate-sshPublishOver.png)

Copy this syntax to your `Jenkinsfile` then return to `Dashboard`. Here is my `Deploy stage` in `Jenkinsfile`:

```
stage('Deploy to Docker') {
            steps {
                echo 'Deploying...'
                sshPublisher(publishers: 
                [sshPublisherDesc(
                    configName: 'ansible-controller', 
                    transfers: [
                        sshTransfer(
                            sourceFiles: 'download-deploy.yaml, hosts',
                            remoteDirectory: '/playbooks',
                            cleanRemote: false,
                            execCommand: 'cd playbooks/ && ansible-playbook download-deploy.yaml -i hosts', 
                            execTimeout: 120000, 
                        )
                    ], 
                    usePromotionTimestamp: false, 
                    useWorkspaceInPromotion: false, 
                    verbose: false)
                ])
            }
        }
```

✌️ Our [Jenkinsfile](./Jenkinsfile) is completed!

## 🚚 Continuous Deployment with Ansible

### Manual configure SSH Credentials between `Ansible-Controller` and `Dockerhost`

Remote SSH to `Ansible-Controller` with account **ansibleadmin**, password **ansibleadmin**:
```
ssh ansibleadmin@[Your Ansible-Controller Public IP]
...
ansibleadmin@52.91.160.84's password:
```

Generate ssh keypair by run command `ssh-keygen`
```
[ansibleadmin@ip-10-0-0-237 ~]$ ssh-keygen
Generating public/private rsa key pair.
Enter file in which to save the key (/home/ansibleadmin/.ssh/id_rsa): 
Created directory '/home/ansibleadmin/.ssh'.
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in /home/ansibleadmin/.ssh/id_rsa.
Your public key has been saved in /home/ansibleadmin/.ssh/id_rsa.pub.
The key fingerprint is:
SHA256:LwV0cZlxt2qyX7zu6uVygLfrnXQfDNDK0PIeCNAshpg ansibleadmin@ip-10-0-0-237.ec2.internal
The key's randomart image is:
+---[RSA 2048]----+
|  o ..o . o.o+. .|
| E . o.+ ...+. ..|
|    . ...o o . . |
|        ..* o .  |
|        S..*.+   |
|         o..=o+  |
|        . .o. oB.|
|         .  .o*.*|
|            o*BB.|
+----[SHA256]-----+
```

Then, run command `ssh-copy-id ansibleadmin@[Your Dockerhost Private IP]` to copy public key to the `Dockerhost`, allow us to log in to the `Dockerhost` without having to enter password.
```
[ansibleadmin@ip-10-0-0-237 ~]$ ssh-copy-id ansibleadmin@10.0.0.85
/usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "/home/ansibleadmin/.ssh/id_rsa.pub"
The authenticity of host '10.0.0.85 (10.0.0.85)' can't be established.
ECDSA key fingerprint is SHA256:Zghtxh+5N5xRs4CgyXm7WEobMD18MF5bVhDLOE2EqTg.
ECDSA key fingerprint is MD5:03:8b:ee:bd:3f:bf:63:93:b5:49:f1:a8:6f:7b:7c:e8.
Are you sure you want to continue connecting (yes/no)? yes
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
ansibleadmin@10.0.0.85's password: 

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'ansibleadmin@10.0.0.85'"
and check to make sure that only the key(s) you wanted were added.
```

### Update ansible inventory

open file `hosts` in Github repository, change IP address under `[Dockerhost]` to `[Your Dockerhost Private IP]`

```
[dockerhost]
10.0.0.85
```

### Create ansible playbook

Playbook file will instruct Ansible to performing these task on `Dockerhost`:
- Download latest artifact from Nexus repository release.
- Create Dockerfile to build Apache-Tomcat image with latest artifact.
- Build image & run container.

Checkout my playbook file on Github repo `download-deploy.yaml`.

##### Performing task on `Dockerhost` by declare group name [dockerhost] in inventory file `hosts`:
```
  hosts: dockerhost
  become: true
```

##### Download latest artifact from Nexus release repo by using [Search API](https://help.sonatype.com/repomanager3/integrations/rest-and-integration-api/search-api).: 
```
curl -u [Nexus account]:[Nexus password] -L "http://[Your Nexus-Server Private IP]:8081/service/rest/v1/search/assets/download?sort=version&repository=[Nexus repository name]&maven.groupId=[groupID in pom.xml]&maven.artifactId=[artifactId in pom.xml]&maven.extension=[packaging in pom.xml]" -H "accept: application/json" --output /home/ansibleadmin/latest.war'
```

In my ansible playbook, it will look like this:

```
...
  tasks:
      - name: Download the war file
        shell: 'curl -u admin:admin -L "http://10.0.0.48:8081/service/rest/v1/search/assets/download?sort=version&repository=MyLab-RELEASE&maven.groupId=com.mylab&maven.artifactId=MyLab&maven.extension=war" -H "accept: application/json" --output /home/ansibleadmin/latest.war'
        args:
          chdir: /home/ansibleadmin
```

##### Create Dockerfile on `Dockerhost` to build Apache-Tomcat image

We will use image tomcat on [Dockerhub](https://hub.docker.com/_/tomcat) as our base image. Then copy downloaded artifact to root folder of tomcat web server `/usr/local/tomcat/webapps`.
Finally, grant proper access and run Tomcat server by `catalina.sh` script.
>`catalina.sh` is a shell script that is included with Apache Tomcat, provides a number of options that can be used to customize the server's behavior.

Content of Dockerfile will be like this:
```
FROM tomcat:latest
LABEL Author: "Minhung"
ADD ./latest.war /usr/local/tomcat/webapps
RUN chmod +x $CATALINA_HOME/bin
EXPOSE 8080
CMD ["catalina.sh", "run"]
```

In ansible playbook, this task will be like this:

```
  tasks:
    ...
    - name: Create Dockerfile with content
      copy:
        dest: /home/ansibleadmin/Dockerfile
        content: |
                FROM tomcat:latest
                LABEL Author: "Minhung"
                ADD ./latest.war /usr/local/tomcat/webapps
                RUN chmod +x $CATALINA_HOME/bin
                EXPOSE 8080
                CMD ["catalina.sh", "run"]
```

##### Build image and run container in `Dockerhost`

Instead of run shell script, use ansible task with `force: yes` will rebuild the image, even if it already exists. (Ansible will add the `--no-cache=true` option to the `docker build` command)

```
  tasks:
    ...
    - name: Build an image
      docker_image:
        name: mylab-image
        path: /home/ansibleadmin
        force: yes
        state: present
```

For running container, use ansible task with `recreate: yes` will ensure that any existing container with the same name is stopped and removed before the new container is created. Our container will expose to port 8080 of `Dockerhost`.

```
  tasks:
    ...
    - name: Run the container
      docker_container:
        name: mylab-container
        image: mylab-image:latest
        state: started
        recreate: yes
        published_ports:
          - 0.0.0.0:8080:8080
```

So, we are complete create a CI/CD pipeline for Java web app!✌️ 


## ⭐️ Test the result

Open Jenkins, run our pipeline. The result should be successful like that:
![Jenkins Successful](/docs/images/pipeline-successful.png)

Open Nexus, select our created release repository. The result should be like that:
![Nexus Successful](/docs/images/nexus-successful.png)

Test our web app by enter `http://[Your Dockerhost Public IP]:8080/latest/` on web browser
![Web App](/docs/images/web-app.png)

Now, everytime you change your Web app source code, just push to GitHub repository and go to Jenkins pipeline and click `Build Now`. New version of web app will be deployed automatically.

> You can also automate step click `Build Now` in Jenkins by go to `Configuration` in your pipeline. Select `Poll SCM` in section `Build Trigger` and define the schedule. Click to the `?` sign to read the schedule instruction.

#### Troubleshooting

If your pipeline trigger error, open `Console Output` of this `build #` to identy find which stage have issue. 
![Troubleshooting](/docs/images/troubleshoot.png)

Manual perform this step on corresponding server to troubleshooting.

#### Clean up AWS Infrastructure

AWS resource will cost you per hours, so please remember to clean up after you finished.
Go to your working directory which is run `terraform` earlier, run this command to clean up:
```
terraform destroy --auto-approve
```

*Good Luck!!!* 👏 👏 👏