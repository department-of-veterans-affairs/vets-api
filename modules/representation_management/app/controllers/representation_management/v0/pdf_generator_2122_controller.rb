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
          organization_representative_name
          organization_job_title
          organization_email
          organization_appointment_date

        ]
      end

      def flatten_form_params(params)
        {
          veteran_first_name: params.dig(:veteran, :name, :first),
          veteran_middle_initial: params.dig(:veteran, :name, :middle),
          veteran_last_name: params.dig(:veteran, :name, :last),
          veteran_social_security_number: params.dig(:veteran, :ssn),
          veteran_va_file_number: params.dig(:veteran, :vaFileNumber),
          veteran_date_of_birth: params.dig(:veteran, :dateOfBirth),
          veteran_service_number: params.dig(:veteran, :serviceNumber),
          veteran_insurance_numbers: params.dig(:veteran, :insuranceNumbers),
          veteran_address_line1: params.dig(:veteran, :address, :addressLine1),
          veteran_address_line2: params.dig(:veteran, :address, :addressLine2),
          veteran_city: params.dig(:veteran, :address, :city),
          veteran_state_code: params.dig(:veteran, :address, :stateCode),
          veteran_country: params.dig(:veteran, :address, :country),
          veteran_zip_code: params.dig(:veteran, :address, :zipCode),
          veteran_zip_code_suffix: params.dig(:veteran, :address, :zipCodeSuffix),
          veteran_phone: params.dig(:veteran, :phone),
          veteran_email: params.dig(:veteran, :email),
          claimant_first_name: params.dig(:claimant, :name, :first),
          claimant_middle_initial: params.dig(:claimant, :name, :middle),
          claimant_last_name: params.dig(:claimant, :name, :last),
          claimant_date_of_birth: params.dig(:claimant, :dateOfBirth),
          claimant_relationship: params.dig(:claimant, :relationship),
          # claimant_id: params.dig(:claimant, :claimantId),
          claimant_address_line1: params.dig(:claimant, :address, :addressLine1),
          claimant_address_line2: params.dig(:claimant, :address, :addressLine2),
          claimant_city: params.dig(:claimant, :address, :city),
          claimant_state_code: params.dig(:claimant, :address, :stateCode),
          claimant_country: params.dig(:claimant, :address, :country),
          claimant_zip_code: params.dig(:claimant, :address, :zipCode),
          claimant_zip_code_suffix: params.dig(:claimant, :address, :zipCodeSuffix),
          claimant_phone: params.dig(:claimant, :phone),
          claimant_email: params.dig(:claimant, :email),
          organization_name: params[:organizationName],
          record_consent: params[:recordConsent],
          consent_limits: params[:consentLimits],
          consent_address_change: params[:consentAddressChange]
        }
      end
    end
  end
end
