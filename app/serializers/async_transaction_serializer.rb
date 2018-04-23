# frozen_string_literal: true

class AsyncTransactionSerializer < ActiveModel::Serializer
  attribute :id
  # @TODO Do we actually need to serialize the rest of these?
  # Does the front end actually need to know this data?
  attribute :type
  attribute :user_uuid
  attribute :source_id
  attribute :source
  attribute :transaction_id
  attribute :transaction_status
end
