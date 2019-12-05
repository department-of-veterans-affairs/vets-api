# frozen_string_literal: true

require 'common/client/base'

module VaForms
  class Service < Common::Client::Base
    STATSD_KEY_PREFIX = 'api.va_forms'

    configuration VaForms::Configuration

    def initialize
      # @query = query
      # @page = page.to_i
    end

    def get_all
      perform(:get, '', nil)
    end

    private

    def results_url
      config.base_path
    end
  end
end
