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
        params.require(%i[veteran representative]).permit(all_params)
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
          representative_organization_name
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
          representative_phone_number
          representative_email_address
        ]
      end

      def flatten_form_params(params)
        {
          record_consent: params[:recordConsent],
          consent_limits: params[:consentLimits],
          consent_address_change: params[:consentAddressChange],
          conditions_of_appointment: params[:conditionsOfAppointment]
        }.merge(flatten_veteran_params(params))
          .merge(flatten_claimant_params(params))
          .merge(flatten_representative_params(params))
      end

      def flatten_veteran_params(params)
        {
          veteran_first_name: params.dig(:veteran, :name, :first),
          veteran_middle_initial: params.dig(:veteran, :name, :middle),
          veteran_last_name: params.dig(:veteran, :name, :last),
          veteran_social_security_number: params.dig(:veteran, :ssn),
          veteran_va_file_number: params.dig(:veteran, :vaFileNumber),
          veteran_date_of_birth: params.dig(:veteran, :dateOfBirth),
          veteran_service_number: params.dig(:veteran, :serviceNumber),
          # veteran_insurance_numbers: params.dig(:veteran, :insuranceNumbers),
          veteran_service_branch: params.dig(:veteran, :serviceBranch),
          veteran_service_branch_other: params.dig(:veteran, :serviceBranchOther),
          veteran_address_line1: params.dig(:veteran, :address, :addressLine1),
          veteran_address_line2: params.dig(:veteran, :address, :addressLine2),
          veteran_city: params.dig(:veteran, :address, :city),
          veteran_state_code: params.dig(:veteran, :address, :stateCode),
          veteran_country: params.dig(:veteran, :address, :country),
          veteran_zip_code: params.dig(:veteran, :address, :zipCode),
          veteran_zip_code_suffix: params.dig(:veteran, :address, :zipCodeSuffix),
          veteran_phone: params.dig(:veteran, :phone),
          veteran_email: params.dig(:veteran, :email)
        }
      end

      def flatten_claimant_params(params)
        {
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
          claimant_email: params.dig(:claimant, :email)
        }
      end

      def flatten_representative_params(params)
        {
          representative_first_name: params.dig(:representative, :name, :first),
          representative_middle_initial: params.dig(:representative, :name, :middle),
          representative_last_name: params.dig(:representative, :name, :last),
          representative_type: params.dig(:representative, :type),
          representative_address_line1: params.dig(:representative, :address, :addressLine1),
          representative_address_line2: params.dig(:representative, :address, :addressLine2),
          representative_city: params.dig(:representative, :address, :city),
          representative_state_code: params.dig(:representative, :address, :stateCode),
          representative_country: params.dig(:representative, :address, :country),
          representative_zip_code: params.dig(:representative, :address, :zipCode),
          representative_zip_code_suffix: params.dig(:representative, :address, :zipCodeSuffix),
          representative_phone_number: params.dig(:representative, :phone),
          representative_email_address: params.dig(:representative, :email)
        }
      end
    end
  end
end
