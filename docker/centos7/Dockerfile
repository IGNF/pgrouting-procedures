FROM centos:7.5.1804

ARG proxy=""
ARG ipRange=""

ENV http_proxy=$proxy https_proxy=$proxy HTTP_PROXY=$proxy HTTPS_PROXY=$proxy

ENV HOME=/var/lib/pgsql PGDATA=/var/lib/pgsql/10/data

# Update et dépendances
RUN yum -y update
RUN yum -y install yum-utils centos-release-scl epel-release
RUN yum-config-manager --enable rhel-server-rhscl-7-rpms
RUN yum -y install devtoolset-8
RUN yum install -y https://download.postgresql.org/pub/repos/yum/10/redhat/rhel-7-x86_64/pgdg-redhat-repo-42.0-9.noarch.rpm
RUN yum -y install git cmake3 zlib-devel postgresql10-10.7 postgresql10-server-10.7 postgresql10-libs-10.7 postgresql10-contrib-10.7 postgresql10-devel-10.7

WORKDIR /home/docker/
# Récupération des dépôt utiles
RUN git clone --depth=1 --branch=v2.3.1 https://github.com/OSGeo/gdal.git
RUN git clone --depth=1 --branch=3.7.0  https://github.com/libgeos/geos.git

# Installation de gdal
RUN scl enable devtoolset-8 bash && export CC=/opt/rh/devtoolset-8/root/usr/bin/gcc CXX=/opt/rh/devtoolset-8/root/usr/bin/g++ && cd gdal/gdal && ./configure && make && make install

# Installation de geos
RUN scl enable devtoolset-8 bash && export CC=/opt/rh/devtoolset-8/root/usr/bin/gcc CXX=/opt/rh/devtoolset-8/root/usr/bin/g++ && cd geos && mkdir build && cd build && cmake3 .. -DENABLE_MASON=ON -DCMAKE_CXX_COMPILER=/opt/rh/devtoolset-8/root/usr/bin/g++ && make && make install

# Installation de postgis
RUN yum -y install postgis25_10-2.5.1

# Installation de pgrouting
RUN yum -y install postgis25_10-client-2.5.1 pgrouting_10-2.6.1

# Copy
COPY docker/centos7/data/postgresql-setup /usr/pgsql-10.7/bin/postgresql107-setup

# Working directory
WORKDIR /var/lib/pgsql

# Run initdb
RUN /usr/pgsql-10.7/bin/postgresql107-setup initdb -d

# Copy config file
COPY docker/centos7/data/postgresql.conf /var/lib/pgsql/10/data/postgresql.conf
COPY docker/centos7/data/pg_hba.conf /var/lib/pgsql/10/data/pg_hba.conf
COPY docker/centos7/data/postgresql.sh /usr/local/bin/postgresql.sh
COPY docker/centos7/data/create_dbuser.sh /usr/local/bin/create_dbuser.sh
COPY docker/centos7/data/add_procedures.sh /usr/local/bin/add_procedures.sh

# Adding template sql procedure file
COPY sql_templates/*.sh /usr/local/bin/

# Modification du pg_hba.conf pour accepter les connexions depuis les ip données en paramètre du build
RUN echo "host    all             all             $ipRange            trust" >> /var/lib/pgsql/10/data/pg_hba.conf

RUN touch /etc/sudoers
# Change own user
RUN chown -R postgres:postgres /var/lib/pgsql/10/data/* && \
    chown postgres:postgres /usr/local/bin/ && \
    usermod -G wheel postgres && \
    sed -i 's/.*requiretty$/#Defaults requiretty/' /etc/sudoers && \
    chmod +x /usr/local/bin/postgresql.sh && \
    chmod +x /usr/local/bin/add_procedures.sh && \
    chmod +x /usr/local/bin/create_dbuser.sh && \
    chmod +x /usr/local/bin/generate_routeProcedures.sh && \
    chmod +x /usr/local/bin/generate_utilities.sh && \
    chmod +x /usr/local/bin/generate_isochroneProcedures.sh


#Set user
USER postgres

RUN DB_NAME=pivot create_dbuser.sh
RUN DB_NAME=pgrouting create_dbuser.sh
RUN DB_NAME=pgrouting add_procedures.sh

# Set volume
VOLUME ["/var/lib/pgsql"]

# Run PostgreSQL Server
CMD ["postgresql.sh"]

# Expose ports.
EXPOSE 5432
