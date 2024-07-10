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
          { name: name_params_permitted,
            address: address_params_permitted }
        ]
      end

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
            name: name_params_permitted,
            address: address_params_permitted }
        ]
      end

      def flatten_claimant_params(claimant_params)
        {
          claimant_first_name: claimant_params.dig(:claimant, :name, :first),
          claimant_middle_initial: claimant_params.dig(:claimant, :name, :middle),
          claimant_last_name: claimant_params.dig(:claimant, :name, :last),
          claimant_date_of_birth: claimant_params.dig(:claimant, :date_of_birth),
          claimant_relationship: claimant_params.dig(:claimant, :relationship),
          claimant_address_line1: claimant_params.dig(:claimant, :address, :address_line1),
          claimant_address_line2: claimant_params.dig(:claimant, :address, :address_line2),
          claimant_city: claimant_params.dig(:claimant, :address, :city),
          claimant_state_code: claimant_params.dig(:claimant, :address, :state_code),
          claimant_country: claimant_params.dig(:claimant, :address, :country),
          claimant_zip_code: claimant_params.dig(:claimant, :address, :zip_code),
          claimant_zip_code_suffix: claimant_params.dig(:claimant, :address, :zip_code_suffix),
          claimant_phone: claimant_params.dig(:claimant, :phone),
          claimant_email: claimant_params.dig(:claimant, :email)
        }
      end

      def flatten_veteran_params(veteran_params)
        {
          veteran_first_name: veteran_params.dig(:veteran, :name, :first),
          veteran_middle_initial: veteran_params.dig(:veteran, :name, :middle),
          veteran_last_name: veteran_params.dig(:veteran, :name, :last),
          veteran_social_security_number: veteran_params.dig(:veteran, :ssn),
          veteran_va_file_number: veteran_params.dig(:veteran, :va_file_number),
          veteran_date_of_birth: veteran_params.dig(:veteran, :date_of_birth),
          veteran_service_number: veteran_params.dig(:veteran, :service_number),
          veteran_address_line1: veteran_params.dig(:veteran, :address, :address_line1),
          veteran_address_line2: veteran_params.dig(:veteran, :address, :address_line2),
          veteran_city: veteran_params.dig(:veteran, :address, :city),
          veteran_state_code: veteran_params.dig(:veteran, :address, :state_code),
          veteran_country: veteran_params.dig(:veteran, :address, :country),
          veteran_zip_code: veteran_params.dig(:veteran, :address, :zip_code),
          veteran_zip_code_suffix: veteran_params.dig(:veteran, :address, :zip_code_suffix),
          veteran_phone: veteran_params.dig(:veteran, :phone),
          veteran_email: veteran_params.dig(:veteran, :email)
        }
      end

      def name_params_permitted
        %i[first middle last]
      end

      def address_params_permitted
        %i[
          address_line1
          address_line2
          city
          state_code
          country
          zip_code
          zip_code_suffix
        ]
      end

      def feature_enabled
        routing_error unless Flipper.enabled?(:appoint_a_representative_enable_pdf)
      end
    end
  end
end
