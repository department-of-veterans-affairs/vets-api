# frozen_string_literal: true

module RepresentationManagement
  module V0
    class PdfGenerator2122Controller < ApplicationController
      service_tag 'lighthouse-veteran' # Is this the correct service tag?
      before_action :feature_enabled
      skip_before_action :authenticate

      def create
        # We'll need a process here to check the params to make sure all the
        # required fields are present. If not, we'll need to return an error
        # with status: :unprocessable_entity.  If all fields are accounted for
        # we need to fill out the 2122 PDF with the data and return the file
        # to the front end.

        # This work probably belongs in the PDF Generation ticket.
        render json: {}, status: :unprocessable_entity
      end

      private

      def form_params
        params.permit(all_params)
      end

      def all_params
        [
          claimant_params,
          service_organization_params,
          veteran_params,
          :record_consent,
          :consent_address_change,
          { consent_limits: [] }
        ].flatten
      end

      def claimant_params
        %i[
          claimant_address_line1
          claimant_address_line2
          claimant_city
          claimant_country
          claimant_state_code
          claimant_zip_code
          claimant_zip_code_suffix
          claimant_area_code
          claimant_phone_number
          claimant_phone_number_ext
          claimant_email
          claimant_relationship
        ]
      end

      def service_organization_params
        %i[
          service_organization_poa_code
          service_organization_registration_number
          service_organization_job_title
          service_organization_email
          service_organization_appointment_date

        ]
      end

      def veteran_params
        %i[
          veteran_address_line1
          veteran_address_line2
          veteran_city
          veteran_country
          veteran_state_code
          veteran_zip_code
          veteran_zip_code_suffix
          veteran_area_code
          veteran_phone_number
          veteran_phone_number_ext
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
