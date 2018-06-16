# frozen_string_literal: true

class DeleteOldTransactionsJob
  include Sidekiq::Worker
  include SentryLogging

  # :nocov:
  def perform
    AsyncTransaction::Base
      .stale
      .find_each do |tx|
        begin
          tx.destroy!
        rescue RecordNotDestroyed => e
          log_message_to_sentry(
            'DeleteOldTransactionsJob raised an exception',
            :info,
            model: self.class.to_s,
            transaction_id: tx.id,
            exception: e
          )
        end
      end
  end
  # :nocov:
end
