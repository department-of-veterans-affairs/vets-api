# frozen_string_literal: true

module AsyncTransaction
  class Base < ApplicationRecord
    self.table_name = 'async_transactions'

    REQUESTED = 'requested'
    COMPLETED = 'completed'
    DELETE_COMPLETED_AFTER = 1.month

    scope :stale, lambda {
      where('created_at < ?', DELETE_COMPLETED_AFTER.ago).where(status: COMPLETED)
    }

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
    validates :transaction_id,
              uniqueness: { scope: :source, message: 'Transaction ID must be unique within a source.' }
  end
end
