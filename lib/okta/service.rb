# frozen_string_literal: true

require 'common/client/base'

module Okta
  class Service < Common::Client::Base
    include Common::Client::Monitoring
  end
end
