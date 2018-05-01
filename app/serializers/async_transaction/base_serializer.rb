# frozen_string_literal: true

module AsyncTransaction
  class BaseSerializer < ActiveModel::Serializer
    attribute :status
    attribute :transaction_id
    attribute :type

    def id
      nil
    end

    def status
      object.transaction_status
    end
  end
end
