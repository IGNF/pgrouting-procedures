FROM centos:7.5.1804

ARG proxy="http://proxy.ign.fr:3128/"

ENV http_proxy=$proxy https_proxy=$proxy HTTP_PROXY=$proxy HTTPS_PROXY=$proxy

ENV HOME=/var/lib/pgsql PGDATA=/var/lib/pgsql/10/data

RUN NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) && \
 yum -y update && \
 yum -y install yum-utils centos-release-scl epel-release && \
 yum-config-manager --enable rhel-server-rhscl-7-rpms && \
 yum -y install devtoolset-6 && \
 rpm -Uvh https://yum.postgresql.org/10/redhat/rhel-7-x86_64/pgdg-centos10-10-2.noarch.rpm && \
 scl enable devtoolset-6 bash && \
 yum -y install git cmake3 zlib-devel postgresql10-10.6 postgresql10-server-10.6 postgresql10-libs-10.6 postgresql10-contrib-10.6 postgresql10-devel-10.6 && \
 export CC=/opt/rh/devtoolset-6/root/usr/bin/gcc CXX=/opt/rh/devtoolset-6/root/usr/bin/g++ && \
 git clone --depth=1 --branch=v2.3.1 https://github.com/OSGeo/gdal.git && \
 cd gdal/gdal && \
 ./configure && \
 make -j${NPROC} && \
 make -j${NPROC} install && \
 cd .. && \
 git clone --depth=1 --branch=3.7.0  https://github.com/libgeos/geos.git && \
 cd geos && \
 mkdir build && \
 cd build && \
 cmake3 .. -DENABLE_MASON=ON -DCMAKE_CXX_COMPILER=/opt/rh/devtoolset-6/root/usr/bin/g++ && \
 make -j${NPROC} && \
 make -j${NPROC} install && \
 cd .. && \
 yum -y install postgis25_10-2.5.1 && \
 yum -y install postgis25_10-client-2.5.1 pgrouting_10-2.6.1

# Copy
COPY data/postgresql-setup /usr/pgsql-10.6/bin/postgresql106-setup

# Working directory
WORKDIR /var/lib/pgsql

# Run initdb
RUN /usr/pgsql-10.6/bin/postgresql106-setup initdb

# Copy config file
COPY data/postgresql.conf /var/lib/pgsql/10/data/postgresql.conf
COPY data/pg_hba.conf /var/lib/pgsql/10/data/pg_hba.conf
COPY data/postgresql.sh /usr/local/bin/postgresql.sh

RUN touch /etc/sudoers
# Change own user
RUN chown -R postgres:postgres /var/lib/pgsql/10/data/* && \
    usermod -G wheel postgres && \
    sed -i 's/.*requiretty$/#Defaults requiretty/' /etc/sudoers && \
    chmod +x /usr/local/bin/postgresql.sh

# Set volume
VOLUME ["/var/lib/pgsql"]

# Set username
USER postgres

# Run PostgreSQL Server
CMD ["/bin/bash", "/usr/local/bin/postgresql.sh"]

# Expose ports.
EXPOSE 5432
