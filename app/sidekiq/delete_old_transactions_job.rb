# frozen_string_literal: true

require 'vets/shared_logging'

class DeleteOldTransactionsJob
  include Sidekiq::Job
  include Vets::SharedLogging

  # :nocov:
  def perform
    AsyncTransaction::Base
      .stale
      .find_each do |tx|
        tx.destroy!
    rescue ActiveRecord::RecordNotDestroyed => e
      log_message_to_sentry(
        'DeleteOldTransactionsJob raised an exception',
        :error,
        { model: self.class.to_s, transaction_id: tx.id, exception: e.message }
      )

      log_message_to_rails(
        'DeleteOldTransactionsJob raised an exception',
        :error,
        { model: self.class.to_s, transaction_id: tx.id, exception: e.message }
      )
      end
  end
  # :nocov:
end
