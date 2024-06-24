# frozen_string_literal: true

module RepresentationManagement
  module V0
    class PdfGenerator2122Controller < RepresentationManagement::V0::PdfGeneratorBaseController
      # service_tag 'lighthouse-veteran' # Is this the correct service tag?

      def create
        form = RepresentationManagement::Form2122Data.new(flatten_form_params(form_params))

        if form.valid?
          render json: { message: 'Form is valid' }, status: :ok
        else
          render json: { errors: form.errors.full_messages }, status: :unprocessable_entity
        end
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
          service_organization_name
          service_organization_representative_name
          service_organization_job_title
          service_organization_email
          service_organization_appointment_date

        ]
      end
    end
  end
end
