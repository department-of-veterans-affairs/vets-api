# frozen_string_literal: true
require 'evss/common_service'

module EVSS
  class CreateUserAccountJob
    include Sidekiq::Worker

    def perform(user)
      auth_headers = EVSS::AuthHeaders.new(user).to_h
      client = EVSS::CommonService.new(auth_headers)
      client.create_user_account
    end
  end
end
