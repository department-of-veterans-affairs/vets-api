# frozen_string_literal: true

module PowerOfAttorneyRequestService
  class Create
    class FormDataAdapter
      def initialize(data:, dependent: false, service_branch: nil)
        @data = data.transform_values(&:presence)
        @dependent = dependent
        @service_branch = service_branch
        @transformed_data = {}
      end

      def call
        build_authorizations

        if @dependent
          build_dependent
        else
          @transformed_data['dependent'] = nil
        end

        build_veteran

        validate_data

        {
          data: @transformed_data,
          errors: @errors
        }
      end

      private

      def build_authorizations
        @transformed_data['authorizations'] = {
          'recordDisclosure' => @data[:record_consent],
          'recordDisclosureLimitations' => @data[:consent_limits] || [],
          'addressChange' => @data[:consent_address_change]
        }
      end

      def build_dependent
        @transformed_data['dependent'] = {
          'name' => {
            'first' => @data[:claimant_first_name],
            'middle' => @data[:claimant_middle_initial],
            'last' => @data[:claimant_last_name]
          },
          'address' => build_dependent_address,
          'dateOfBirth' => @data[:claimant_date_of_birth],
          'relationship' => @data[:claimant_relationship],
          'phone' => @data[:claimant_phone],
          'email' => @data[:claimant_email]
        }
      end

      def build_dependent_address
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

      def build_veteran
        @transformed_data['veteran'] = {
          'name' => {
            'first' => @data[:veteran_first_name],
            'middle' => @data[:veteran_middle_initial],
            'last' => @data[:veteran_last_name]
          },
          'address' => build_veteran_address,
          'ssn' => @data[:veteran_social_security_number],
          'vaFileNumber' => @data[:veteran_va_file_number],
          'dateOfBirth' => @data[:veteran_date_of_birth],
          'serviceNumber' => @data[:veteran_service_number],
          'serviceBranch' => @service_branch,
          'phone' => @data[:veteran_phone],
          'email' => @data[:veteran_email]
        }
      end

      def build_veteran_address
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
        JSONSchemer.schema(AccreditedRepresentativePortal::PowerOfAttorneyForm::SCHEMA)
      end

      def validate_data
        @errors = if schemer.valid?(@transformed_data)
                    []
                  else
                    schemer.validate(@transformed_data).to_a.pluck('error')
                  end
      end
    end
  end
end
