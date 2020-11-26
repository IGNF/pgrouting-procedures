FROM centos:7.5.1804

ARG ipRange=""

ENV HOME=/usr/local/pgsql PGDATA=/usr/local/pgsql/data LD_LIBRARY_PATH=/usr/local/pgsql/lib/:/usr/local/lib/

# Update et dépendances
RUN yum -y update
RUN yum -y install yum-utils centos-release-scl epel-release
RUN yum-config-manager --enable rhel-server-rhscl-7-rpms
RUN yum -y install devtoolset-8
# https://yum.postgresql.org/repopackages.php
RUN rpm -Uvh https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
RUN yum -y install git cmake3 zlib-devel wget

# Installation de PostgreSQL
# Anciens paquets yum installés: postgresql10-10.7 postgresql10-server-10.7 postgresql10-libs-10.7 postgresql10-contrib-10.7 postgresql10-devel-10.7
WORKDIR /home/docker/postgresql
RUN yum install -y readline-devel
RUN wget -O postgresql-10.13.tar.gz https://ftp.postgresql.org/pub/source/v10.13/postgresql-10.13.tar.gz
RUN tar -xvzf postgresql-10.13.tar.gz && cd postgresql-10.13 && ./configure && make && make install
RUN cd postgresql-10.13/contrib/postgres_fdw/ && make && make install
RUN adduser postgres
# Run initdb
COPY docker/centos7/data/postgresql-setup /home/docker/postgresql/postgresql-setup
RUN /home/docker/postgresql/postgresql-setup initdb -d

WORKDIR /home/docker/
# Récupération des dépôt utiles
RUN git clone --depth=1 --branch=release/2.4 https://github.com/OSGeo/gdal.git
RUN git clone --depth=1 --branch=3.7.0  https://github.com/libgeos/geos.git

# Installation de gdal
RUN scl enable devtoolset-8 bash && export CC=/opt/rh/devtoolset-8/root/usr/bin/gcc CXX=/opt/rh/devtoolset-8/root/usr/bin/g++ && cd gdal/gdal && ./configure && make && make install

# Installation de geos
RUN scl enable devtoolset-8 bash && export CC=/opt/rh/devtoolset-8/root/usr/bin/gcc CXX=/opt/rh/devtoolset-8/root/usr/bin/g++ && cd geos && mkdir build && cd build && cmake3 .. -DENABLE_MASON=ON -DCMAKE_CXX_COMPILER=/opt/rh/devtoolset-8/root/usr/bin/g++ && make && make install

# # Installation de postgis
# ancien paquet installé: postgis25_10-2.5.1
WORKDIR /home/docker/postgis/
RUN yum install -y libxml2-devel json-c-devel proj-devel SFCGAL SFCGAL-devel
RUN wget -O postgis-2.5.4.tar.gz https://download.osgeo.org/postgis/source/postgis-2.5.4.tar.gz && tar -xvzf postgis-2.5.4.tar.gz
RUN cd postgis-2.5.4 && ./configure --with-pgconfig=/usr/local/pgsql/bin/pg_config \
    --with-geosconfig=/usr/local/bin/geos-config --with-gdalconfig=/usr/local/bin/gdal-config \
    --with-sfcgal=/usr/bin/sfcgal-config && \
    make && make install
RUN cd postgis-2.5.4/extensions/postgis && make clean && make && make install && \
    cd ../postgis_topology/ && make clean && make && make install && \
    cd ../postgis_sfcgal/ && make clean && make && make install
# Installation de pgrouting
# ancien paquets installés: postgis25_10-client-2.5.1 pgrouting_10-2.6.1
WORKDIR /home/docker/pgrouting/
RUN yum install -y boost-devel CGAL-devel perl-Data-Dumper
RUN wget -O pgrouting-2.6.3.tar.gz https://github.com/pgRouting/pgrouting/archive/v2.6.3.tar.gz && tar -xvzf pgrouting-2.6.3.tar.gz
RUN scl enable devtoolset-8 bash && \
    export CC=/opt/rh/devtoolset-8/root/usr/bin/gcc CXX=/opt/rh/devtoolset-8/root/usr/bin/g++ && \
    cd pgrouting-2.6.3 && mkdir build && cd build && \
    cmake3 -DPOSTGRESQL_PG_CONFIG=/usr/local/pgsql/bin/pg_config .. && make && make install

# Copy config file
COPY docker/centos7/data/postgresql.conf /usr/local/pgsql/data/postgresql.conf
COPY docker/centos7/data/pg_hba.conf /usr/local/pgsql/data/pg_hba.conf
COPY docker/centos7/data/postgresql.sh /usr/local/bin/postgresql.sh
COPY docker/centos7/data/create_dbuser.sh /usr/local/bin/create_dbuser.sh
COPY docker/centos7/data/add_procedures.sh /usr/local/bin/add_procedures.sh

# Adding template sql procedure file
COPY sql_templates/*.sh /usr/local/bin/

# Modification du pg_hba.conf pour accepter les connexions depuis les ip données en paramètre du build
RUN echo "host    all             all             $ipRange            trust" >> /usr/local/pgsql/data/pg_hba.conf

RUN touch /etc/sudoers
# Change own user
RUN chown -R postgres:postgres /usr/local/pgsql/data/* && \
    chown postgres:postgres /usr/local/bin/ && \
    usermod -G wheel postgres && \
    sed -i 's/.*requiretty$/#Defaults requiretty/' /etc/sudoers && \
    chmod +x /usr/local/bin/postgresql.sh && \
    chmod +x /usr/local/bin/add_procedures.sh && \
    chmod +x /usr/local/bin/create_dbuser.sh && \
    chmod +x /usr/local/bin/generate_routeProcedures.sh && \
    chmod +x /usr/local/bin/generate_utilities.sh && \
    chmod +x /usr/local/bin/generate_isochroneProcedures.sh


# Set user
USER postgres

# Create database and add pgr procedures
RUN DB_NAME=pivot create_dbuser.sh
RUN DB_NAME=pgrouting create_dbuser.sh
RUN DB_NAME=pgrouting add_procedures.sh


# Working directory
WORKDIR /usr/local/pgsql/

# Set volume
VOLUME ["/usr/local/pgsql/"]

# Run PostgreSQL Server
CMD ["postgresql.sh"]

# Expose ports.
EXPOSE 5432
