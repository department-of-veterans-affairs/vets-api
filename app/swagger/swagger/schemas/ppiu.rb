# frozen_string_literal: true

module Swagger
  module Schemas
    class PPIU
      include Swagger::Blocks

      swagger_schema :ControlInformation do
        property :can_update_address, type: :boolean, example: true
        property :corp_avail_indicator, type: :boolean, example: true
        property :corp_rec_found_indicator, type: :boolean, example: true
        property :has_no_bdn_payments_indicator, type: :boolean, example: true
        property :identity_indicator, type: :boolean, example: true
        property :index_indicator, type: :boolean, example: true
        property :is_competent_indicator, type: :boolean, example: true
        property :no_fiduciary_assigned_indicator, type: :boolean, example: true
        property :not_deceased_indicator, type: :boolean, example: true
      end

      swagger_schema :PaymentAccount do
        property :account_number, type: :string, example: '9876543211234'
        property :account_type, type: :string, example: 'Checking'
        property :financial_institution_name, type: :string, example: 'Comerica'
        property :financial_institution_routing_number, type: :string, example: '042102115'
      end

      swagger_schema :PaymentAddress do
        key :required, %i[
          type
          address_effective_date
          address_one
        ]
        property :address_effective_date, type: :string, example: '2018-06-07T22:47:21.873Z'
        property :address_one, type: :string, example: 'First street address line'
        property :address_two, type: %i[string null], example: 'Second street address line'
        property :address_three, type: %i[string null], example: 'Third street address line'
        property :city, type: %i[string null], example: 'AdHocville'
        property :state_code, type: %i[string null], example: 'OR'
        property :country_name, type: %i[string null], example: 'USA'
        property :military_post_office_type_code, type: %i[string null], example: 'Military PO'
        property :military_state_code, type: %i[string null], example: 'AP'
        property :zip_code, type: %i[string null], example: '12345'
        property :zip_suffix, type: %i[string null], example: '6789'
        property :type, type: %i[string null], example: 'Domestic'
      end

      swagger_schema :PPIU do
        property :data, type: :object do
          property :attributes, type: :object do
            key :required, %i[responses]
            property :responses, type: :array do
              items do
                key :required, %i[
                  control_information
                  payment_account
                  payment_address
                  payment_type
                ]
                property :control_information, type: :object do
                  key :'$ref', :ControlInformation
                end
                property :payment_account, type: :object do
                  key :'$ref', :PaymentAccount
                end
                property :payment_address, type: :object do
                  key :'$ref', :PaymentAddress
                end
                property :payment_type, type: :string, example: 'CNP'
              end
            end
          end
          property :id, type: :string, example: nil
          property :type, type: :string, example: 'evss_ppiu_payment_information_responses'
        end
      end
    end
  end
end
