# frozen_string_literal: true

require 'common/client/base'

module Okta
  class Service < Common::Client::Base
    include Common::Client::Monitoring

    STATSD_KEY_PREFIX = 'api.okta'

    configuration Search::Configuration

    def initialize(url)
      @url = url
      connection
    end
  end
end
