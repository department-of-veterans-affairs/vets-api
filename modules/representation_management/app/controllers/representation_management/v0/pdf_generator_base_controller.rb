# frozen_string_literal: true

module RepresentationManagement
  module V0
    class PdfGeneratorBaseController < ApplicationController
      service_tag 'representation-management'
      skip_before_action :authenticate
      before_action :feature_enabled

      private

      def params_permitted
        [
          :record_consent,
          :consent_address_change,
          { consent_limits: [],
            conditions_of_appointment: [],
            claimant: claimant_params_permitted,
            veteran: veteran_params_permitted }
        ]
      end

      def claimant_params_permitted
        [
          :date_of_birth,
          :relationship,
          :phone,
          :email,
          { name: %i[
              first
              middle
              last
            ],
            address: %i[
              address_line1
              address_line2
              city
              state_code
              country
              zip_code
              zip_code_suffix
            ] }
        ]
      end

      # rubocop:disable Metrics/MethodLength
      def veteran_params_permitted
        [
          :ssn,
          :va_file_number,
          :date_of_birth,
          :service_number,
          :service_branch,
          :service_branch_other,
          :phone,
          :email,
          { insurance_numbers: [],
            name: %i[
              first
              middle
              last
            ],
            address: %i[
              address_line1
              address_line2
              city
              state_code
              country
              zip_code
              zip_code_suffix
            ] }
        ]
      end

      # rubocop:enable Metrics/MethodLength
      def flatten_claimant_params(params)
        {
          claimant_first_name: params.dig(:claimant, :name, :first),
          claimant_middle_initial: params.dig(:claimant, :name, :middle),
          claimant_last_name: params.dig(:claimant, :name, :last),
          claimant_date_of_birth: params.dig(:claimant, :date_of_birth),
          claimant_relationship: params.dig(:claimant, :relationship),
          claimant_address_line1: params.dig(:claimant, :address, :address_line1),
          claimant_address_line2: params.dig(:claimant, :address, :address_line2),
          claimant_city: params.dig(:claimant, :address, :city),
          claimant_state_code: params.dig(:claimant, :address, :state_code),
          claimant_country: params.dig(:claimant, :address, :country),
          claimant_zip_code: params.dig(:claimant, :address, :zip_code),
          claimant_zip_code_suffix: params.dig(:claimant, :address, :zip_code_suffix),
          claimant_phone: params.dig(:claimant, :phone),
          claimant_email: params.dig(:claimant, :email)
        }
      end

      def flatten_veteran_params(params)
        {
          veteran_first_name: params.dig(:veteran, :name, :first),
          veteran_middle_initial: params.dig(:veteran, :name, :middle),
          veteran_last_name: params.dig(:veteran, :name, :last),
          veteran_social_security_number: params.dig(:veteran, :ssn),
          veteran_va_file_number: params.dig(:veteran, :va_file_number),
          veteran_date_of_birth: params.dig(:veteran, :date_of_birth),
          veteran_service_number: params.dig(:veteran, :service_number),
          veteran_address_line1: params.dig(:veteran, :address, :address_line1),
          veteran_address_line2: params.dig(:veteran, :address, :address_line2),
          veteran_city: params.dig(:veteran, :address, :city),
          veteran_state_code: params.dig(:veteran, :address, :state_code),
          veteran_country: params.dig(:veteran, :address, :country),
          veteran_zip_code: params.dig(:veteran, :address, :zip_code),
          veteran_zip_code_suffix: params.dig(:veteran, :address, :zip_code_suffix),
          veteran_phone: params.dig(:veteran, :phone),
          veteran_email: params.dig(:veteran, :email)
        }
      end

      def feature_enabled
        routing_error unless Flipper.enabled?(:appoint_a_representative_enable_pdf)
      end
    end
  end
end
