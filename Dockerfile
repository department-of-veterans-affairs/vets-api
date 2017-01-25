FROM centos:7.2.1511

# Install Red Hat SCI library
RUN yum install -y centos-release-scl-rh
RUN yum install -y rh-ruby23 rh-ruby23-ruby-devel rh-ruby23-rubygems git make gcc-c++ openssl-devel readline-devel zlib-devel sqlite-devel postgresql-devel socat timeout
RUN echo "source /opt/rh/rh-ruby23/enable" > /etc/profile.d/rh-ruby23.sh

# Install bundler ( for some reason this isn't picking up the environmental variables )
RUN source /opt/rh/rh-ruby23/enable && gem install bundler


# Vets.gov API source
RUN mkdir -p /src/vets-api
ADD . /src/vets-api
WORKDIR /src/vets-api
RUN source /opt/rh/rh-ruby23/enable && bundle install
