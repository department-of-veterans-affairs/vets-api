# frozen_string_literal: true

module VAOS
  class ExtendSession
    include Sidekiq::Worker

    sidekiq_options(retry: false)

    def perform(account_uuid)
      UserService.new.update_session_token(account_uuid)
    end
  end
end
