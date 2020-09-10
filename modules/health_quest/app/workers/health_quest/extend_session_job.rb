# frozen_string_literal: true

require 'sidekiq'

module HealthQuest
  class ExtendSessionJob
    include Sidekiq::Worker

    sidekiq_options(retry: false)

    def perform(account_uuid)
      HealthQuest::UserService.new.update_session_token(account_uuid)
    end
  end
end
