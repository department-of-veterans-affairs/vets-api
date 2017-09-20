# frozen_string_literal: true
require 'common/client/base'
require 'evss/auth_headers'

module EVSS
  class Service < Common::Client::Base
    def headers_for_user(user)
      EVSS::AuthHeaders.new(user).to_h
    end
  end
end
