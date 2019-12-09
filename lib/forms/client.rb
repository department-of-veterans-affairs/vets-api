# frozen_string_literal: true

require 'common/client/base'

module Forms
  class Client < Common::Client::Base
    include SentryLogging
    include Common::Client::Monitoring

    configuration Forms::Configuration

    STATSD_KEY_PREFIX = 'api.forms'

    attr_reader :query

    def initialize(query)
      @query = query
    end

    def get_all
      with_monitoring do
        raw_response = perform(:get, 'forms', query_params)
        Forms::Responses::Response.new(raw_response.status, raw_response.body, 'forms')
      end
    rescue => e
      handle_error(e)
    end

    private

    def query_params
      {
        query: query
      }
    end

    def results_url
      config.base_path
    end

    def parse_messages(error)
      error.body&.dig('errors')
    end

    def handle_error(error)
      case error
      when Common::Client::Errors::ClientError
        save_error_details(error.body)
        raise_backend_exception('FORMS_502', self.class, error)
      else
        raise error
      end
    end

    def save_error_details(error_message)
      Raven.extra_context(
        message: error_message,
        url: config.base_path
      )
      Raven.tags_context(search: 'general_forms_query_error')
    end
  end
end
