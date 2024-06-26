# frozen_string_literal: true

module RepresentationManagement
  module V0
    class PdfGenerator2122Controller < RepresentationManagement::V0::PdfGeneratorBaseController
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
        params.require(%i[veteran organization_name]).permit(all_params)
      end

      def all_params
        [
          claimant_params,
          organization_params,
          veteran_params,
          :record_consent,
          :consent_address_change,
          { consent_limits: [] }
        ].flatten
      end

      def organization_params
        %i[
          organization_name
        ]
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
        {
          veteran_first_name: params.dig(:veteran, :name, :first),
          veteran_middle_initial: params.dig(:veteran, :name, :middle),
          veteran_last_name: params.dig(:veteran, :name, :last),
          veteran_social_security_number: params.dig(:veteran, :ssn),
          veteran_va_file_number: params.dig(:veteran, :va_file_number),
          veteran_date_of_birth: params.dig(:veteran, :date_of_birth),
          veteran_service_number: params.dig(:veteran, :service_number),
          veteran_insurance_numbers: params.dig(:veteran, :insurance_numbers),
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

      def flatten_claimant_params(params)
        {
          claimant_first_name: params.dig(:claimant, :name, :first),
          claimant_middle_initial: params.dig(:claimant, :name, :middle),
          claimant_last_name: params.dig(:claimant, :name, :last),
          claimant_date_of_birth: params.dig(:claimant, :date_of_birth),
          claimant_relationship: params.dig(:claimant, :relationship),
          # claimant_id: params.dig(:claimant, :claimant_id),
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
    end
  end
end
