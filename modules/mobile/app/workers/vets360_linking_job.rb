
# frozen_string_literal: true

require 'sidekiq'

module Mobile
  class Vets360LinkingJob
    include Sidekiq::Worker

    sidekiq_options(retry: false)

    def perform(current_user)
      transaction = Mobile::V0::Profile::SyncUpdateService.new(current_user).await_vet360_account_link
      render json: transaction, serializer: AsyncTransaction::BaseSerializer
    end
  end
end
