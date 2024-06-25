# frozen_string_literal: true

module RepresentationManagement
  module V0
    class PdfGeneratorBaseController < ApplicationController
      service_tag 'lighthouse-veteran' # Is this the correct service tag?
      before_action :feature_enabled

      skip_before_action :authenticate

      private

      def claimant_params
        %i[
          claimant_first_name
          claimant_middle_initial
          claimant_last_name
          claimant_address_line1
          claimant_address_line2
          claimant_city
          claimant_country
          claimant_state_code
          claimant_zip_code
          claimant_zip_code_suffix
          claimant_phone_number
          claimant_email
          claimant_relationship
          claimant_date_of_birth
        ]
      end

      def veteran_params
        %i[
          veteran_first_name veteran_middle_initial veteran_last_name
          veteran_social_security_number
          veteran_va_file_number
          veteran_date_of_birth
          veteran_address_line1
          veteran_address_line2
          veteran_city
          veteran_country
          veteran_state_code
          veteran_zip_code
          veteran_zip_code_suffix
          veteran_phone_number
          veteran_email
          veteran_service_number
          veteran_insurance_number
        ]
      end

      def feature_enabled
        routing_error unless Flipper.enabled?(:appoint_a_representative_enable_pdf)
      end
    end
  end
end
