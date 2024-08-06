# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class PaymentInformation < Common::Resource
      attribute :id, Types::String
      attribute :account_control do
        attribute :can_update_address, Types::Bool
        attribute :corp_avail_indicator, Types::Bool
        attribute :corp_rec_found_indicator, Types::Bool
        attribute :has_no_bdn_payments_indicator, Types::Bool
        attribute :identity_indicator, Types::Bool
        attribute :is_competent_indicator, Types::Bool
        attribute :index_indicator, Types::Bool
        attribute :no_fiduciary_assigned_indicator, Types::Bool
        attribute :not_deceased_indicator, Types::Bool
        attribute :can_update_payment, Types::Bool
      end
      attribute :payment_account do
        attribute :account_type, Types::String
        attribute :financial_institution_name, Types::String
        attribute :account_number, Types::String
        attribute :financial_institution_routing_number, Types::String
      end
    end
  end
end
