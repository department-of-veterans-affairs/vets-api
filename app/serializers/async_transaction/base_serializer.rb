# frozen_string_literal: true

module AsyncTransaction
  class BaseSerializer < ActiveModel::Serializer
    attribute :transaction_id
    attribute :transaction_status
    attribute :type
    attribute :metadata

    def id
      nil
    end

    def metadata
      object.parsed_metadata
    end
  end
end
