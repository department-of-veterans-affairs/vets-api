# frozen_string_literal: true

module RepresentationManagement
  module V0
    class PdfGenerator2122aController < RepresentationManagement::V0::PdfGeneratorBaseController
      def create
        form = RepresentationManagement::Form2122aData.new(flatten_form_params)

        if form.valid?
          Tempfile.create do |tempfile|
            tempfile.binmode
            RepresentationManagement::V0::PdfConstructor::Form2122a.new(tempfile).construct(form)
            send_data tempfile.read,
                      filename: '21-22a.pdf',
                      type: 'application/pdf',
                      disposition: 'attachment',
                      status: :ok
          end
          # The Tempfile is automatically deleted after the block ends
        else
          render json: { errors: form.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def form_params
        params.require(:pdf_generator2122a).permit(
          params_permitted << { representative: representative_params_permitted }
        )
      end

      def representative_params_permitted
        [
          :type,
          :phone,
          :email,
          { name: name_params_permitted,
            address: address_params_permitted }
        ]
      end

      def flatten_form_params
        {
          record_consent: form_params[:record_consent],
          consent_limits: form_params[:consent_limits],
          consent_address_change: form_params[:consent_address_change],
          conditions_of_appointment: form_params[:conditions_of_appointment]
        }.merge(flatten_veteran_params(form_params))
          .merge(flatten_claimant_params(form_params))
          .merge(flatten_representative_params(form_params))
      end

      def flatten_veteran_params(veteran_params)
        super.merge(veteran_service_number: veteran_params.dig(:veteran, :service_number),
                    veteran_service_branch: veteran_params.dig(:veteran, :service_branch))
      end

      def flatten_representative_params(representative_params)
        {
          representative_first_name: representative_params.dig(:representative, :name, :first),
          representative_middle_initial: representative_params.dig(:representative, :name, :middle),
          representative_last_name: representative_params.dig(:representative, :name, :last),
          representative_type: representative_params.dig(:representative, :type),
          representative_address_line1: representative_params.dig(:representative, :address, :address_line1),
          representative_address_line2: representative_params.dig(:representative, :address, :address_line2),
          representative_city: representative_params.dig(:representative, :address, :city),
          representative_state_code: representative_params.dig(:representative, :address, :state_code),
          representative_country: representative_params.dig(:representative, :address, :country),
          representative_zip_code: representative_params.dig(:representative, :address, :zip_code),
          representative_zip_code_suffix: representative_params.dig(:representative, :address, :zip_code_suffix),
          representative_phone: representative_params.dig(:representative, :phone),
          representative_email_address: representative_params.dig(:representative, :email)
        }
      end
    end
  end
end
