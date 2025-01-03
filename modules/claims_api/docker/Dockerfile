FROM public.ecr.aws/docker/library/ruby:3.3.6-slim-bookworm

RUN apt-get update --fix-missing
RUN apt-get install -y poppler-utils build-essential libpq-dev git curl wget ca-certificates-java file \
  imagemagick pdftk tesseract-ocr postgresql-client \
  && apt-get clean \
  && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /app
COPY app/models/mpi_data.rb spec/dummy/app/models/mpi_data.rb
COPY modules/claims_api/ .
COPY modules/claims_api/docker/Gemfile Gemfile
COPY modules/claims_api/docker/Gemfile.lock Gemfile.lock
COPY lib/sentry_logging.rb lib/sentry_logging.rb
COPY lib/common lib/common
COPY lib/evss lib/evss
COPY lib/formatters lib/formatters
COPY lib/identity lib/identity
COPY lib/json_schema lib/json_schema
COPY lib/lighthouse lib/lighthouse
COPY lib/mpi lib/mpi
COPY lib/token_validation lib/token_validation
RUN chmod +x spec/dummy/bin/rails

RUN bundle install

EXPOSE 3000

COPY modules/claims_api/docker/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["rails", "server", "-b", "0.0.0.0"]