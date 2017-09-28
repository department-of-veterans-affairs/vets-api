# frozen_string_literal: true
module EVSS
  class CreateUserAccountJob
    include Sidekiq::Worker

    def perform(user_uuid)
      user = User.find(user_uuid)
      client = EVSS::EVSSCommon::Service.new(user)
      client.create_user_account
    end
  end
end
