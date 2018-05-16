# frozen_string_literal: true

module AsyncTransaction
  class Base < ActiveRecord::Base
    self.table_name = 'async_transactions'

    REQUESTED = 'requested'
    COMPLETED = 'completed'

    attr_encrypted :metadata, key: Settings.db_encryption_key

    before_save :serialize_metadata

    def serialize_metadata
      self.metadata = metadata.to_json unless metadata.is_a?(String)
    end

    validates :id, uniqueness: true
    validates :user_uuid, :source_id, :source, :status, :transaction_id, presence: true
    validates :transaction_id,
              uniqueness: { scope: :source, message: 'Transaction ID must be unique within a source.' }
  end
end
