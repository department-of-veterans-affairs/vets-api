# frozen_string_literal: true

module AsyncTransaction
  class BaseSerializer < ActiveModel::Serializer
    attribute :status
    attribute :transaction_id
    attribute :type

    def id
      nil
    end

    def type
      object.transaction.type
    end

    def transaction_id
      object.transaction.id
    end

    def status
      object.transaction.status
    end
  end
end
