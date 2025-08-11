# frozen_string_literal: true

require 'vets/model'

module DisabilityCompensation
  module ApiProvider
    class ControlInformation
      include Vets::Model

      attribute :can_update_address, Bool
      attribute :corp_avail_indicator, Bool
      attribute :corp_rec_found_indicator, Bool
      attribute :has_no_bdn_payments_indicator, Bool
      attribute :identity_indicator, Bool
      attribute :is_competent_indicator, Bool
      attribute :index_indicator, Bool
      attribute :no_fiduciary_assigned_indicator, Bool
      attribute :not_deceased_indicator, Bool
    end

    class PaymentAccount
      include Vets::Model

      attribute :account_type, String
      attribute :financial_institution_name, String
      attribute :account_number, String
      attribute :financial_institution_routing_number, String
    end

    class PaymentAddress
      include Vets::Model

      attribute :type, String
      attribute :address_effective_date, DateTime
      attribute :address_one, String
      attribute :address_two, String
      attribute :address_three, String
      attribute :city, String
      attribute :state_code, String
      attribute :zip_code, String
      attribute :zip_suffix, String
      attribute :country_name, String
      attribute :military_post_office_type_code, String
      attribute :military_state_code, String
    end

    # Used in conjunction with the PPIU/Direct Deposit Provider
    class PaymentInformation
      include Vets::Model

      attribute :control_information, DisabilityCompensation::ApiProvider::ControlInformation
      attribute :payment_account, DisabilityCompensation::ApiProvider::PaymentAccount
      attribute :payment_address, DisabilityCompensation::ApiProvider::PaymentAddress
      attribute :payment_type, String
    end

    class PaymentInformationResponse
      include Vets::Model

      attribute :responses, DisabilityCompensation::ApiProvider::PaymentInformation, array: true
    end
  end
end
