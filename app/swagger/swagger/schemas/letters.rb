# frozen_string_literal: true

module Swagger
  module Schemas
    class Letters
      include Swagger::Blocks

      swagger_schema :Letters do
        key :required, [:data]

        property :data, type: :object do
          property :attributes, type: :object do
            key :required, %i[letters full_name]
            property :letters do
              key :type, :array
              items do
                key :$ref, :Letter
              end
            end
            property :full_name, type: :string, example: 'Mark Webb'
          end
          property :id, type: :string, example: nil
          property :type, type: :string, example: 'evss_letters_letters_response'
        end
      end

      swagger_schema :Letter do
        key :required, %i[name letter_type]
        property :name, type: :string, example: 'Proof of Service Letter'
        property :letter_type, type: :string, enum: %w[
          commissary
          proof_of_service
          medicare_partd
          minimum_essential_coverage
          service_verification
          civil_service
          benefit_summary
          benefit_summary_dependent
          benefit_verification
          certificate_of_eligibility
          foreign_medical_program
        ], example: 'proof_of_service'
      end
    end
  end
end
