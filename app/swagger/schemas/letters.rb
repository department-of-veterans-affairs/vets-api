# frozen_string_literal: true
module Swagger
  module Schemas
    class Letters
      include Swagger::Blocks

      swagger_schema :Letters do
        key :required, [:data, :meta]

        property :data, type: :object do
          property :attributes, type: :object do
            property :letters do
              key :type, :array
              items do
                key :'$ref', :Letter
              end
            end
          end
          property :id, type: :string, example: nil
          property :type, type: :string, example: 'evss_letters_letters_response'
        end

        property :meta, type: :object do
          property :address, type: :object do
            key :required, [:full_name, :address_line1, :address_line2, :address_line3, :city, :state, :country, :foreign_code, :zip_code]
            property :full_name, type: :string, example: 'Abraham Lincoln'
            property :address_line1, type: :string, example: '140 Rock Creek Church Rd NW'
            property :address_line2, type: :string, example: nil
            property :address_line3, type: :string, example: nil
            property :city, type: :string, example: 'Washington'
            property :state, type: :string, example: 'DC'
            property :country, type: :string, example: 'USA'
            property :foreign_code, type: :string, example: nil
            property :zip_code, type: :string, example: '20011'
          end
          property :status, type: :string, enum: %w(OK NOT_AUTHORIZED NOT_FOUND SERVER_ERROR), example: 'OK'
        end
      end

      swagger_schema :Letter do
        key :required, [:name, :letter_type]
        property :name, type: :string, example: 'Proof of Service Letter'
        property :letter_type, type: :string, enum: %w(
            commissary
            proof_of_service
            medicare_partd
            minimum_essential_coverage
            service_verification
            civil_service
            benefit_summary
            benefit_verification
            certificate_of_eligibility
          ),
          example: 'proof_of_service'
      end
    end
  end
end
