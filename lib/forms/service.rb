# frozen_string_literal: true

require 'common/client/base'

module Forms
  class Service < Common::Client::Base
    STATSD_KEY_PREFIX = 'api.forms'

    configuration Forms::Configuration

    def get_all
      perform(:get, 'forms', nil)
    end

    def healthcheck
      perform(:get, 'healthcheck', nil)
    end

    private

    def results_url
      config.base_path
    end
  end
end
