FROM centos:6

# Match the jenkins uid/gid on the host (504)
RUN groupadd --gid 504 jenkins \
  && useradd --uid 504 --gid jenkins --shell /bin/bash --create-home jenkins

RUN yum install -y git make gcc-c++ openssl-devel readline-devel zlib-devel sqlite-devel postgresql-devel socat timeout epel-release

# Install Red Hat SCI library for ruby packages
RUN yum install -y centos-release-scl-rh
RUN yum install -y rh-ruby23 rh-ruby23-ruby-devel rh-ruby23-rubygems
RUN echo "source /opt/rh/rh-ruby23/enable" > /etc/profile.d/rh-ruby23.sh
RUN ["/bin/bash", "--login", "-c", "gem install --no-doc bundler"]

# Install pdftk binary dependencies (see ansible/roles/pdftk/README.md)
RUN yum install -y libgcj
RUN curl https://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/pdftk-2.02-1.el6.x86_64.rpm > /tmp/pdftk-2.02-1.el6.x86_64.rpm && \
      rpm -i /tmp/pdftk-2.02-1.el6.x86_64.rpm && \
      rm /tmp/pdftk-2.02-1.el6.x86_64.rpm

# Install ImageMagick dependencies
RUN yum install -y ImageMagick ImageMagick-devel

# Install clamav dependencies
RUN yum install -y clamav clamav-scanner

# Configure vets-api application
RUN mkdir -p /src/vets-api && chown jenkins:jenkins /src/vets-api
WORKDIR /src/vets-api
USER jenkins

ADD Gemfile /src/vets-api/Gemfile
ADD Gemfile.lock /src/vets-api/Gemfile.lock
RUN ["/bin/bash", "--login", "-c", "bundle install -j4"]

ADD . /src/vets-api

RUN echo "source /opt/rh/rh-ruby23/enable" > /home/jenkjgg
