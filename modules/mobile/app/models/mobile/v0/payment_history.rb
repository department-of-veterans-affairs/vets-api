# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class PaymentHistory < Common::Resource
      attribute :id, Types::String
      attribute :account, Types::String.optional
      attribute :amount, Types::Float
      attribute :bank, Types::String.optional
      attribute :date, Types::DateTime
      attribute :payment_method, Types::String
      attribute :payment_type, Types::String
    end
  end
end
