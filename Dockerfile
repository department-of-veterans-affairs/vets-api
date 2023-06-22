FROM ruby:3.2.2-slim-bullseye AS rubyimg
FROM rubyimg AS modules

WORKDIR /tmp

# Copy each module's Gemfile, gemspec, and version.rb files
COPY modules/ modules/
RUN find modules -type f ! \( -name Gemfile -o -name "*.gemspec" -o -path "*/lib/*/version.rb" \) -delete && \
    find modules -type d -empty -delete

FROM rubyimg

# Allow for setting ENV vars via --build-arg
ARG BUNDLE_ENTERPRISE__CONTRIBSYS__COM \
  RAILS_ENV=development \
  USER_ID=1000
ENV RAILS_ENV=$RAILS_ENV \
  BUNDLE_ENTERPRISE__CONTRIBSYS__COM=$BUNDLE_ENTERPRISE__CONTRIBSYS__COM \
  BUNDLER_VERSION=2.4.9

RUN groupadd --gid $USER_ID nonroot \
  && useradd --uid $USER_ID --gid nonroot --shell /bin/bash --create-home nonroot --home-dir /app

WORKDIR /app

RUN echo "deb http://ftp.debian.org/debian testing main contrib non-free" >> /etc/apt/sources.list
RUN apt-get update
RUN apt-get install -y -t testing poppler-utils
RUN apt-get install -y ca-certificates-java && dpkg --configure -a && apt-get install -y build-essential libpq-dev git imagemagick curl wget ca-certificates-java pdftk file \
  && apt-get clean \
  && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Relax ImageMagick PDF security. See https://stackoverflow.com/a/59193253.
RUN sed -i '/rights="none" pattern="PDF"/d' /etc/ImageMagick-6/policy.xml


# Install fwdproxy.crt into trust store
# Relies on update-ca-certificates being run in following step
COPY config/ca-trust/*.crt /usr/local/share/ca-certificates/

# Download VA Certs
COPY ./import-va-certs.sh .
RUN ./import-va-certs.sh

COPY config/clamd.conf /etc/clamav/clamd.conf

RUN mkdir -p /clamav_tmp && \
    chown -R nonroot:nonroot /clamav_tmp && \
    chmod 777 /clamav_tmp


ENV LANG=C.UTF-8 \
   BUNDLE_JOBS=4 \
   BUNDLE_PATH=/usr/local/bundle/cache \
   BUNDLE_RETRY=3

RUN gem install bundler:${BUNDLER_VERSION} --no-document

COPY --from=modules /tmp/modules modules/
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
