# frozen_string_literal: true

require 'common/client/base'

module Forms
  # Proxy Service for Forms API.
  #
  # @example Get all forms or filter by a wildcard query.
  #
  class Client < Common::Client::Base
    include SentryLogging
    include Common::Client::Monitoring

    configuration Forms::Configuration

    STATSD_KEY_PREFIX = 'api.forms'

    attr_reader :search_term

    def initialize(search_term)
      @search_term = search_term
    end

    # Get all forms with an optional query parameter "query" for wildcard filtering.
    #
    def get_all
      with_monitoring do
        raw_response = perform(:get, 'forms', query: search_term)
        Forms::Responses::Response.new(raw_response.status, raw_response.body, 'forms')
      end
    rescue => e
      handle_error(e)
    end

    private

    def handle_error(error)
      case error
      when Common::Client::Errors::ClientError
        save_error_details(error)
        raise_backend_exception('FORMS_502', self.class, error)
      else
        raise error
      end
    end

    def save_error_details(error)
      Raven.tags_context(
        external_service: self.class.to_s.underscore
      )

      Raven.extra_context(
        url: config.base_path,
        message: error.message,
        body: error.body
      )
    end
  end
end
