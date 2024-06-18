# frozen_string_literal: true

module RepresentationManagement
  module V0
    class PdfGenerator2122Controller < RepresentationManagement::V0::PdfGeneratorBaseController
      service_tag 'lighthouse-veteran' # Is this the correct service tag?
      before_action :verify_service_organization_name_required
      before_action :verify_service_organization_representative_name_optional
      before_action :verify_service_organization_name_representative_job_title_optional
      before_action :verify_service_organization_email_address_optional
      before_action :verify_service_organization_appointment_date_optional

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

      def service_organization_params
        %i[
          service_organization_poa_code
          service_organization_registration_number
          service_organization_job_title
          service_organization_email
          service_organization_appointment_date

        ]
      end

      def feature_enabled
        routing_error unless Flipper.enabled?(:appoint_a_representative_enable_pdf)
      end
    end
  end
end
