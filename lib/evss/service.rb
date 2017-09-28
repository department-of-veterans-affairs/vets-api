# frozen_string_literal: true
require 'common/client/base'
require 'evss/auth_headers'

module EVSS
  class Service < Common::Client::Base
    def headers_for_user(user)
      EVSS::AuthHeaders.new(user).to_h
    end

    def perform_with_user_headers(method, path, body, headers = {}, &block)
      perform(
        method,
        path,
        body,
        headers_for_user(@current_user).merge(headers),
        &block
      )
    end
  end
end
