# frozen_string_literal: true

require 'evss/common_service'

module EVSS
  class CreateUserAccountJob
    include Sidekiq::Worker

    sidekiq_options(queue: 'critical', retry: 3)

    def perform(user_uuid)
      current_user = User.find(user_uuid) || IAMUser.find(user_uuid)
      return unless current_user

      headers = EVSS::AuthHeaders.new(current_user).to_h
      client = EVSS::CommonService.new(headers)
      client.create_user_account
    end
  end
end
