#!/bin/bash

# Ensure that your software packages are up to date on your instance by uing the following command to perform a quick software update:
yum update –y

# Add the Jenkins repo using the following command:

wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat-stable/jenkins.repo

# Import a key file from Jenkins-CI to enable installation from the package:
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
yum upgrade

# Install Java:
amazon-linux-extras install java-openjdk11 -y

# Install Git:
yum install git -y

# Install Jenkins:
yum install jenkins -y

# Enable the Jenkins service to start at boot:
systemctl enable jenkins

# Start Jenkins as a service:
systemctl start jenkins

# Reference: https://www.jenkins.io/doc/tutorials/tutorial-for-installing-jenkins-on-AWS/