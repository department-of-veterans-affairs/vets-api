# frozen_string_literal: true

require 'bid/configuration'
require 'common/client/base'
require 'vets/shared_logging'

module BID
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring
    include Vets::SharedLogging
    SENTRY_TAG = { team: 'vfs-ebenefits' }.freeze

    def initialize(user)
      @user = user
    end
  end
end
