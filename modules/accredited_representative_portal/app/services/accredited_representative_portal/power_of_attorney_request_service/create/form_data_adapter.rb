# frozen_string_literal: true

module AccreditedRepresentativePortal
  module PowerOfAttorneyRequestService
    class Create
      class FormDataAdapter
        def initialize(data:, dependent: false, service_branch: nil)
          @data = data.transform_values do |value|
            value == '' ? nil : value
          end
          @dependent = dependent
          @service_branch = service_branch
        end

        def call
          {
            data: transformed_data,
            errors:
          }
        end

        private

        def transformed_data
          @transformed_data ||= {
            'authorizations' => authorizations,
            'dependent' => dependent,
            'veteran' => veteran
          }
        end

        def authorizations
          {
            'recordDisclosureLimitations' => @data[:consent_limits] || [],
            'addressChange' => @data[:consent_address_change]
          }
        end

        def dependent
          return nil unless @dependent

          {
            'name' => {
              'first' => @data[:claimant_first_name],
              'middle' => @data[:claimant_middle_initial],
              'last' => @data[:claimant_last_name]
            },
            'address' => dependent_address,
            'dateOfBirth' => @data[:claimant_date_of_birth],
            'relationship' => @data[:claimant_relationship],
            'phone' => sanitize_phone_number(@data[:claimant_phone]),
            'email' => @data[:claimant_email]
          }
        end

        def dependent_address
          {
            'addressLine1' => @data[:claimant_address_line1],
            'addressLine2' => @data[:claimant_address_line2],
            'city' => @data[:claimant_city],
            'stateCode' => @data[:claimant_state_code],
            'country' => @data[:claimant_country],
            'zipCode' => @data[:claimant_zip_code],
            'zipCodeSuffix' => @data[:claimant_zip_code_suffix]
          }
        end

        def veteran
          {
            'name' => {
              'first' => @data[:veteran_first_name],
              'middle' => @data[:veteran_middle_initial],
              'last' => @data[:veteran_last_name]
            },
            'address' => veteran_address,
            'ssn' => @data[:veteran_social_security_number],
            'vaFileNumber' => @data[:veteran_va_file_number],
            'dateOfBirth' => @data[:veteran_date_of_birth],
            'serviceNumber' => @data[:veteran_service_number],
            'serviceBranch' => @service_branch,
            'phone' => sanitize_phone_number(@data[:veteran_phone]),
            'email' => @data[:veteran_email]
          }
        end

        def veteran_address
          {
            'addressLine1' => @data[:veteran_address_line1],
            'addressLine2' => @data[:veteran_address_line2],
            'city' => @data[:veteran_city],
            'stateCode' => @data[:veteran_state_code],
            'country' => @data[:veteran_country],
            'zipCode' => @data[:veteran_zip_code],
            'zipCodeSuffix' => @data[:veteran_zip_code_suffix]
          }
        end

        def schemer
          JSONSchemer.schema(PowerOfAttorneyForm::SCHEMA)
        end

        # removes all non-digit characters from the phone number
        def sanitize_phone_number(phone_number)
          return nil if phone_number.blank?

          phone_number.gsub(/\D/, '').presence
        end

        def errors
          if schemer.valid?(transformed_data)
            []
          else
            schemer.validate(transformed_data).to_a.pluck('error')
          end
        end
      end
    end
  end
end
