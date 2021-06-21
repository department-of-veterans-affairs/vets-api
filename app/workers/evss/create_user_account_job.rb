# frozen_string_literal: true

require 'evss/common_service'

module EVSS
  class CreateUserAccountJob
    include Sidekiq::Worker

    sidekiq_options queue: 'critical'

    def perform(headers)
      client = EVSS::CommonService.new(headers)
      client.create_user_account
    end
  end
end
