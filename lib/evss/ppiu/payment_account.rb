# frozen_string_literal: true

require 'common/models/base'

module EVSS
  module PPIU
    class PaymentAccount
      include Virtus.model

      attribute :account_type, String
      attribute :financial_institution_name, String
      attribute :account_number, String
      attribute :financial_institution_routing_number, String
    end
  end
end
