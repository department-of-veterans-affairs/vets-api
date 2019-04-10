FROM ruby:2.3-slim-stretch

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
ADD Gemfile $APP_PATH
ADD Gemfile.lock $APP_PATH
ADD . /src/vets-api

RUN bundle install
