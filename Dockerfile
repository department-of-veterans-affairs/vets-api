FROM public.ecr.aws/docker/library/ruby:3.3.9-slim-bookworm AS rubyimg

# Update all packages to reduce vulnerabilities (repeat after FROM to ensure latest security patches)
RUN apt-get update && apt-get upgrade -y && apt-get dist-upgrade -y && apt-get clean && rm -rf /var/lib/apt/lists/*

# Allow for setting ENV vars via --build-arg
ARG BUNDLE_ENTERPRISE__CONTRIBSYS__COM \
  RAILS_ENV=development \
  USER_ID=1000
ENV RAILS_ENV=$RAILS_ENV \
  BUNDLE_ENTERPRISE__CONTRIBSYS__COM=$BUNDLE_ENTERPRISE__CONTRIBSYS__COM \
  BUNDLER_VERSION=2.5.23 \
  LANG=C.UTF-8 \
  BUNDLE_JOBS=4 \
  BUNDLE_PATH=/usr/local/bundle/cache \
  BUNDLE_RETRY=3

WORKDIR /app

# Install dependencies and clean up in a single layer
RUN apt-get update --fix-missing && \
    apt-get install -y --no-install-recommends poppler-utils build-essential libpq-dev libffi-dev libyaml-dev git curl wget unzip ca-certificates-java file \
    imagemagick pdftk tesseract-ocr && \
    apt-get upgrade -y && \
    apt-get dist-upgrade -y && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    sed -i '/rights="none" pattern="PDF"/d' /etc/ImageMagick-6/policy.xml && \
    groupadd --gid $USER_ID nonroot && \
    useradd --uid $USER_ID --gid nonroot --shell /bin/bash --create-home nonroot --home-dir /app && \
    mkdir -p /clamav_tmp && \
    chown -R nonroot:nonroot /clamav_tmp && \
    chmod 777 /clamav_tmp && \
    gem install bundler:${BUNDLER_VERSION} --no-document

# Copy configuration files
COPY config/ca-trust/*.crt /usr/local/share/ca-certificates/
COPY config/clamd.conf /etc/clamav/clamd.conf
COPY ./import-va-certs.sh .
RUN ./import-va-certs.sh

# Install dependencies
COPY Gemfile Gemfile.lock ./
COPY modules/ modules/
RUN bundle install && \
    rm -rf /usr/local/bundle/cache/*.gem && \
    find /usr/local/bundle/gems/ -name "*.c" -delete && \
    find /usr/local/bundle/gems/ -name "*.o" -delete && \
    find /usr/local/bundle/gems/ -name ".git" -type d -prune -execdir rm -rf {} + && \
    for d in /usr/local/bundle/gems/nokogiri-*; do \
      if [ -d "$d" ]; then \
        find "$d" -type f -exec chmod a+r {} \; && \
        find "$d" -type d -exec chmod a+rx {} \; ; \
      fi \
    done

# Copy application code with security considerations
COPY --chown=app:app . /app