# frozen_string_literal: true

module EVSS
  class NewCreateUserAccountJob
    include Sidekiq::Worker

    def perform(user_uuid)
      user = User.find(user_uuid)
      EVSS::EVSSCommon::Service.new(user).create_user_account
    end
  end
end
