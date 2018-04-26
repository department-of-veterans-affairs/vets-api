# frozen_string_literal: true

module AsyncTransaction
  class BaseSerializer < ActiveModel::Serializer
    attribute :transaction_id
    attribute :transaction_status
    attribute :type

    def id
      nil
    end

    delegate :type, to: :object
  end
end
