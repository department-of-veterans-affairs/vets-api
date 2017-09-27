# frozen_string_literal: true
require 'common/client/base'
require 'evss/auth_headers'

module EVSS
  class Service < Common::Client::Base
    def headers_for_user(user)
      EVSS::AuthHeaders.new(user).to_h
    end

    def perform_with_user_headers(method, path, params)
      perform(method, path, params, headers_for_user(@current_user))
    end
  end
end
