FROM ruby:2.4.5-slim-stretch

ARG sidekiq_license
ENV BUNDLE_ENTERPRISE__CONTRIBSYS__COM=$sidekiq_license
ARG exclude_sidekiq_ent
ENV EXCLUDE_SIDEKIQ_ENTERPRISE=$exclude_sidekiq_ent
ENV APP_PATH /src/vets-api

RUN groupadd -r vets-api && \
useradd -r -g vets-api vets-api && \
apt-get update -qq && \
apt-get install -y build-essential \
git \
libpq-dev \
libgmp-dev \
clamav \
imagemagick \
pdftk \
poppler-utils && \
freshclam

WORKDIR $APP_PATH
ADD . /src/vets-api

COPY ./docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

ENV BUNDLE_PATH=/bundle \
    BUNDLE_BIN=/bundle/bin \
    GEM_HOME=/bundle
ENV PATH="${BUNDLE_BIN}:${PATH}"
