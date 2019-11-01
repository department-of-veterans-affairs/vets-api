# XXX: using stretch here for pdftk dep, which is not availible after
#      stretch (or in alpine) and is switched automatically to pdftk-java in buster
#      https://github.com/department-of-veterans-affairs/va.gov-team/issues/3032

###
# shared configs for all child images, reuse these layers yo
###
FROM ruby:2.4.9-slim-stretch AS base

RUN groupadd -r vets-api && \
    useradd -r -m -d /srv/vets-api -g vets-api vets-api
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    dumb-init clamav imagemagick pdftk curl poppler-utils
WORKDIR /srv/vets-api

###
# dev step; use --target=development to stop here
# you will need to mount your source to /srv/vets-api to do anything useful here
###
FROM base AS development

ARG sidekiq_license
ARG exclude_sidekiq_ent
ARG rails_env=development

ENV BUNDLE_ENTERPRISE__CONTRIBSYS__COM=$sidekiq_license
ENV EXCLUDE_SIDEKIQ_ENTERPRISE=$exclude_sidekiq_ent
ENV RAILS_ENV=$rails_env

# only extra dev/build opts go here, common packages go in base 🖕
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git build-essential libxml2-dev libxslt-dev libpq-dev
RUN curl -sSL -o /usr/local/bin/cc-test-reporter https://codeclimate.com/downloads/test-reporter/test-reporter-latest-linux-amd64 && \
    chmod +x /usr/local/bin/cc-test-reporter && \
    cc-test-reporter --version
RUN freshclam
COPY --chown=vets-api:vets-api docker-entrypoint.sh .
USER vets-api
ENTRYPOINT ["/usr/bin/dumb-init", "--", "./docker-entrypoint.sh"]

###
# build stage; use --target=builder to stop here
# This is basically development with the app copied in and built
###
FROM development AS builder
# XXX: move modules/ to seperate repos so we can only copy Gemfile* and install a slim layer
ARG bundler_opts
COPY --chown=vets-api:vets-api . .
RUN bundle install --binstubs="${BUNDLE_PATH}/bin" $bundler_opts

###
# prod stage; default if no target given
# to build prod you probably want options like below to get a good build
# --build-arg rails_env=production --build-arg bundler_opts="--without=dev --without=test --no-cache"
# prod
###
FROM base AS production

ENV RAILS_ENV=production
COPY --from=builder $BUNDLE_PATH $BUNDLE_PATH
COPY --from=builder /srv/vets-api ./
USER vets-api
ENTRYPOINT ["/usr/bin/dumb-init", "--", "./docker-entrypoint.sh"]
