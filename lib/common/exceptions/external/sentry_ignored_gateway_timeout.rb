# frozen_string_literal: true

module Common
  module Exceptions
    class SentryIgnoredGatewayTimeout < GatewayTimeout; end
  end
end
