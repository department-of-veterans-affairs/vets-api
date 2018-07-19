# frozen_string_literal: true

require 'common/client/base'

module IHub
  class Service < Common::Client::Base
    STATSD_KEY_PREFIX = 'api.ihub'

    def initialize(user)
      @user = user
    end
  end
end
