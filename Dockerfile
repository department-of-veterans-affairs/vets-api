FROM ruby:2.7.6-slim-bullseye

# Allow for setting ENV vars via --build-arg
ARG BUNDLE_ENTERPRISE__CONTRIBSYS__COM \
  RAILS_ENV=development \
  USER_ID=1000
ENV RAILS_ENV=$RAILS_ENV \
  BUNDLE_ENTERPRISE__CONTRIBSYS__COM=$BUNDLE_ENTERPRISE__CONTRIBSYS__COM \
  BUNDLER_VERSION=2.1.4

RUN groupadd --gid $USER_ID nonroot \
  && useradd --uid $USER_ID --gid nonroot --shell /bin/bash --create-home nonroot --home-dir /app

WORKDIR /app

ARG userid=993
SHELL ["/bin/bash", "-c"]
RUN groupadd -g $userid -r vets-api && \
    useradd -u $userid -r -m -d /srv/vets-api -g vets-api vets-api
RUN echo 'APT::Default-Release "stable";' >> /etc/apt/apt.conf.d/99defaultrelease
RUN mv /etc/apt/sources.list /etc/apt/sources.list.d/stable.list
RUN echo "deb http://ftp.debian.org/debian testing main contrib non-free" >> /etc/apt/sources.list.d/testing.list
RUN echo "deb http://deb.debian.org/debian unstable main" >> /etc/apt/sources.list.d/unstable.list
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y -t stable \
    dumb-init imagemagick pdftk poppler-utils curl libpq5 vim libboost-all-dev
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y -t unstable \
    clamav clamdscan clamav-daemon
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y -t testing \
    poppler-utils

# Relax ImageMagick PDF security. See https://stackoverflow.com/a/59193253.
RUN sed -i '/rights="none" pattern="PDF"/d' /etc/ImageMagick-6/policy.xml


# Install fwdproxy.crt into trust store
# Relies on update-ca-certificates being run in following step
COPY config/ca-trust/*.crt /usr/local/share/ca-certificates/

# Download VA Certs
COPY ./import-va-certs.sh .
RUN ./import-va-certs.sh

COPY config/clamd.conf /etc/clamav/clamd.conf


ENV LANG=C.UTF-8 \
   BUNDLE_JOBS=4 \
   BUNDLE_PATH=/usr/local/bundle/cache \
   BUNDLE_RETRY=3

RUN gem install bundler:${BUNDLER_VERSION} --no-document

RUN wget -q https://vets-api-build-artifacts.s3-us-gov-west-1.amazonaws.com/bundle_cache.tar.bz2 -O - \
  | tar -xjf - -C /usr/local/bundle/
COPY modules ./modules
COPY Gemfile Gemfile.lock ./
RUN bundle install \
  && rm -rf /usr/local/bundle/cache/*.gem \
  && find /usr/local/bundle/gems/ -name "*.c" -delete \
  && find /usr/local/bundle/gems/ -name "*.o" -delete \
  && find /usr/local/bundle/gems/ -name ".git" -type d -prune -execdir rm -rf {} +
COPY --chown=nonroot:nonroot . .

EXPOSE 3000

USER nonroot

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
