#!/bin/bash
yum update -y
yum install -y nginx
systemctl start nginx
systemctl enable nginx
echo "<h1>Portafolio de Javier - desplegado con Terraform</h1>" > /usr/share/nginx/html/index.html