FROM ruby:2.3-slim-jessie

ARG sidekiq_license
ENV BUNDLE_ENTERPRISE__CONTRIBSYS__COM=$sidekiq_license
ARG exclude_sidekiq_ent
ENV EXCLUDE_SIDEKIQ_ENTERPRISE=$exclude_sidekiq_ent
ENV APP_PATH /src/vets-api

RUN groupadd -r vets-api && \
    useradd -r -g vets-api vets-api && \
    apt-get update -qq && \
    echo "deb http://apt.postgresql.org/pub/repos/apt/ jessie-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    apt-get install -y wget && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    apt-get update -qq && \
    apt-get install -y build-essential \
      git \
      libpq-dev \
      clamav \
      imagemagick \
      pdftk \
      postgresql-client-9.5

WORKDIR $APP_PATH
ADD Gemfile $APP_PATH
ADD Gemfile.lock $APP_PATH
ADD . /src/vets-api

RUN bundle install
