FROM debian:buster-20181112

LABEL maintainer="IGN <idev@ign.fr>"
LABEL version="1.0"

### Arguments pour le build de l'image
# DNS
ARG dnsHost=""
ARG dnsIP=""
# Proxy
ARG proxy=""

### DNS

RUN if [ "$dnsHost" != "" ] ; then echo "search $dnsHost" > /etc/resolv.conf ; fi
RUN if [ "$dnsHost" != "" ] ; then echo "nameserver $dnsIP" >> /etc/resolv.conf ; fi

### PROXY
ENV http_proxy=$proxy
ENV https_proxy=$proxy
ENV HTTP_PROXY=$proxy
ENV HTTPS_PROXY=$proxy

### MAJ
RUN apt-get -y update
RUN apt-get -y upgrade

### Utilitaires
RUN apt-get -y install wget vim

### Installation de R
RUN apt-get install -y r-base

### Récupération des scripts
WORKDIR /home/docker/scripts
COPY /tests/performances/scripts ./

WORKDIR /home/docker/
