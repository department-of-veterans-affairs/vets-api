# frozen_string_literal: true

require 'common/client/base'

module Forms
  class Client < Common::Client::Base
    STATSD_KEY_PREFIX = 'api.forms'

    configuration Forms::Configuration

    def get_all
      raw_response = perform(:get, 'forms', nil)
      Forms::Responses::Response.new(raw_response.status, raw_response.body, 'forms')
    end

    private

    def results_url
      config.base_path
    end
  end
end
