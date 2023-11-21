# frozen_string_literal: true

module DisabilityCompensation
  module ApiProvider
    class ControlInformation
      include Virtus.model

      attribute :can_update_address, Boolean
      attribute :corp_avail_indicator, Boolean
      attribute :corp_rec_found_indicator, Boolean
      attribute :has_no_bdn_payments_indicator, Boolean
      attribute :identity_indicator, Boolean
      attribute :is_competent_indicator, Boolean
      attribute :index_indicator, Boolean
      attribute :no_fiduciary_assigned_indicator, Boolean
      attribute :not_deceased_indicator, Boolean
    end

    class PaymentAccount
      include Virtus.model
      include ActiveModel::Validations
      include ActiveModel::Serialization

      attribute :account_type, String
      attribute :financial_institution_name, String
      attribute :account_number, String
      attribute :financial_institution_routing_number, String
    end

    class PaymentAddress
      include Virtus.model

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
      include ActiveModel::Serialization
      include Virtus.model

      attribute :control_information, DisabilityCompensation::ApiProvider::ControlInformation
      attribute :payment_account, DisabilityCompensation::ApiProvider::PaymentAccount
      attribute :payment_address, DisabilityCompensation::ApiProvider::PaymentAddress
      attribute :payment_type, String
    end

    class PaymentInformationResponse
      include ActiveModel::Serialization
      include Virtus.model

      attribute :responses, Array[DisabilityCompensation::ApiProvider::PaymentInformation]
    end
  end
end
