# frozen_string_literal: true

require 'common/client/base'

module PagerDuty
  class Service < Common::Client::Base
    STATSD_KEY_PREFIX = 'api.pagerduty'

    def perform(method, path, body = nil)
      super(method, path, body, headers)
    end

    private

    def headers
      { 'Authorization' => "Token token=#{Settings.maintenance.pagerduty_api_token}" }
    end
  end
end
