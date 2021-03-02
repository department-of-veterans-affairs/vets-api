# frozen_string_literal: true

require 'sidekiq'

module Mobile
  module V0
    class Vet360LinkingJob
      include Sidekiq::Worker

      sidekiq_options(retry: false)

      def perform(current_user)
        Mobile::V0::Profile::SyncUpdateService.new(current_user).await_vet360_account_link
      end
    end
  end
end
