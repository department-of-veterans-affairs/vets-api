# frozen_string_literal: true
require 'common/client/base'
require 'evss/auth_headers'

module EVSS
  class Service < Common::Client::Base
    def headers_for_user(user)
      @headers_by_user ||= Hash.new do |h, key|
        h[key] = EVSS::AuthHeaders.new(user).to_h
      end
      @headers_by_user[user.uuid]
    end
  end
end

