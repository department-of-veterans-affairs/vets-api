# frozen_string_literal: true

require 'evss/common_service'

module EVSS
  class CreateUserAccountJob
    include Sidekiq::Worker

    def perform(headers)
      Sentry::TagRainbows.tag
      client = EVSS::CommonService.new(headers)
      client.create_user_account
    rescue Common::Exceptions::BackendServiceException
      raise Sentry::IgnoredError
    end
  end
end
