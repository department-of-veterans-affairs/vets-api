# frozen_string_literal: true

require 'common/client/base'

module Forms
  class Client < Common::Client::Base
    STATSD_KEY_PREFIX = 'api.forms'

    configuration Forms::Configuration

    attr_reader :query

    def initialize(query)
      @query = query
    end

    def get_all
      raw_response = perform(:get, 'forms', query_params)
      Forms::Responses::Response.new(raw_response.status, raw_response.body, 'forms')
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
  end
end
