# frozen_string_literal: true

require 'bid/configuration'
require 'common/client/base'

module BID
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring
    include SentryLogging
    SENTRY_TAG = { team: 'vfs-ebenefits' }.freeze

    def initialize(user)
      @user = user
    end
  end
end
