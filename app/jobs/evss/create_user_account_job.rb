# frozen_string_literal: true
require_dependency 'evss/common_service'

module EVSS
  class CreateUserAccountJob < ActiveJob::Base
    queue_as :default

    def perform(headers)
      client = EVSS::CommonService.new(headers)
      client.create_user_account
    end
  end
end
