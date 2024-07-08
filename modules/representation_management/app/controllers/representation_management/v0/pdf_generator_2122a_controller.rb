# frozen_string_literal: true

module RepresentationManagement
  module V0
    class PdfGenerator2122aController < RepresentationManagement::V0::PdfGeneratorBaseController
      def create
        form = RepresentationManagement::Form2122aData.new(flatten_form_params(form_params))

        if form.valid?
          render json: { message: 'Form is valid' }, status: :created
        else
          render json: { errors: form.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      # rubocop:disable Metrics/MethodLength
      def form_params
        params.require(:pdf_generator2122a).permit(
          :record_consent,
          :consent_address_change,
          consent_limits: [],
          conditions_of_appointment: [],
          claimant: claimant_params_permitted,
          veteran: veteran_params_permitted,
          representative: [
            :type,
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
        )
      end
      # rubocop:enable Metrics/MethodLength

      def flatten_form_params(params)
        {
          record_consent: params[:record_consent],
          consent_limits: params[:consent_limits],
          consent_address_change: params[:consent_address_change],
          conditions_of_appointment: params[:conditions_of_appointment]
        }.merge(flatten_veteran_params(params))
          .merge(flatten_claimant_params(params))
          .merge(flatten_representative_params(params))
      end

      def flatten_veteran_params(params)
        super.merge(veteran_service_number: params.dig(:veteran, :service_number),
                    veteran_service_branch: params.dig(:veteran, :service_branch))
      end

      def flatten_representative_params(params)
        {
          representative_first_name: params.dig(:representative, :name, :first),
          representative_middle_initial: params.dig(:representative, :name, :middle),
          representative_last_name: params.dig(:representative, :name, :last),
          representative_type: params.dig(:representative, :type),
          representative_address_line1: params.dig(:representative, :address, :address_line1),
          representative_address_line2: params.dig(:representative, :address, :address_line2),
          representative_city: params.dig(:representative, :address, :city),
          representative_state_code: params.dig(:representative, :address, :state_code),
          representative_country: params.dig(:representative, :address, :country),
          representative_zip_code: params.dig(:representative, :address, :zip_code),
          representative_zip_code_suffix: params.dig(:representative, :address, :zip_code_suffix),
          representative_phone: params.dig(:representative, :phone),
          representative_email_address: params.dig(:representative, :email)
        }
      end

      def representative_params_permitted
        [
          :type,
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
    end
  end
end
