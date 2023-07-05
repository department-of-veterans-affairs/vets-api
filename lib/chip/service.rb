# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require_relative 'configuration'

module Chip
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring
    STATSD_KEY_PREFIX = 'api.chip'

    configuration Chip::Configuration
  end
end
