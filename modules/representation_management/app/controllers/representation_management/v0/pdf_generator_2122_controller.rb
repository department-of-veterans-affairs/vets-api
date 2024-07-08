# frozen_string_literal: true

module RepresentationManagement
  module V0
    class PdfGenerator2122Controller < RepresentationManagement::V0::PdfGeneratorBaseController
      def create
        form = RepresentationManagement::Form2122Data.new(flatten_form_params(form_params))

        if form.valid?
          render json: { message: 'Form is valid' }, status: :created
        else
          render json: { errors: form.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def form_params
        params.require(:pdf_generator2122).permit(
          params_permitted.unshift(:organization_name)
        )
      end

      def flatten_form_params(params)
        {
          organization_name: params[:organization_name],
          record_consent: params[:record_consent],
          consent_limits: params[:consent_limits],
          consent_address_change: params[:consent_address_change]
        }.merge(flatten_veteran_params(params))
          .merge(flatten_claimant_params(params))
      end

      def flatten_veteran_params(params)
        super.merge(veteran_insurance_numbers: params.dig(:veteran, :insurance_numbers))
      end
    end
  end
end
