# frozen_string_literal: true

module AsyncTransaction
  class Base < ActiveRecord::Base
    include SentryLogging

    self.table_name = 'async_transactions'

    REQUESTED = 'requested'
    COMPLETED = 'completed'
    DELETE_COMPLETED_AFTER = 1.month

    attr_encrypted :metadata, key: Settings.db_encryption_key

    before_save :serialize_metadata

    def serialize_metadata
      self.metadata = metadata.to_json unless metadata.is_a?(String)
    end

    def parsed_metadata
      JSON.parse(metadata)
    end

    validates :id, uniqueness: true
    validates :user_uuid, :source, :status, :transaction_id, presence: true
    validates :source_id, presence: true, unless: :initialize_person?
    validates :transaction_id,
              uniqueness: { scope: :source, message: 'Transaction ID must be unique within a source.' }

    def delete_stale!
      Base
        .where('created_at < ?', DELETE_COMPLETED_AFTER.ago)
        .where(status: Base::COMPLETED)
        .find_each do |tx|
          begin
            tx.destroy!
          rescue Exception => e
            log_message_to_sentry(
              'DeleteOldTransactionsJob raised an exception',
              :info,
              {
                model: self.class.to_s,
                transaction: tx,
                exception: e
              }
            )
          end
        end
    end

    private

    def initialize_person?
      type&.constantize == AsyncTransaction::Vet360::InitializePersonTransaction
    end
  end
end
