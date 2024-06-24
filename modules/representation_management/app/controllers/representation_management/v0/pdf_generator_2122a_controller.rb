# frozen_string_literal: true

module RepresentationManagement
  module V0
    class PdfGenerator2122aController < RepresentationManagement::V0::PdfGeneratorBaseController
      # service_tag 'lighthouse-veteran' # Is this the correct service tag?

      def create
        form = RepresentationManagement::Form2122aData.new(flatten_form_params(form_params))

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
          representative_params,
          veteran_params,
          :record_consent,
          :consent_address_change,
          { consent_limits: [],
            conditions_of_appointment: [] }
        ].flatten
      end

      def representative_params
        %i[
          representative_type
          representative_service_organization_name
          representative_first_name
          representative_middle_initial
          representative_last_name
          representative_address_line1
          representative_address_line2
          representative_city
          representative_country
          representative_state_code
          representative_zip_code
          representative_zip_code_suffix
          representative_area_code
          representative_phone_number
          representative_email_address
        ]
      end
    end
  end
end
