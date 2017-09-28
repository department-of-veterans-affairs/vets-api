# frozen_string_literal: true
module EVSS
  class CreateUserAccountJob
    include Sidekiq::Worker

    def perform(headers)
      client = EVSS::CommonService.new(headers)
      client.create_user_account
    end
  end
end
