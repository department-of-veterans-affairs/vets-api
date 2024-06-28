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
          claimant: [
            :date_of_birth,
            :relationship,
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
          ],
          veteran: [
            :ssn,
            :va_file_number,
            :date_of_birth,
            :service_number,
            :service_branch,
            :service_branch_other,
            :phone,
            :email,
            {
              name: %i[
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
              ]
            }
          ],
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
        {
          veteran_first_name: params.dig(:veteran, :name, :first),
          veteran_middle_initial: params.dig(:veteran, :name, :middle),
          veteran_last_name: params.dig(:veteran, :name, :last),
          veteran_social_security_number: params.dig(:veteran, :ssn),
          veteran_va_file_number: params.dig(:veteran, :va_file_number),
          veteran_date_of_birth: params.dig(:veteran, :date_of_birth),
          veteran_service_number: params.dig(:veteran, :service_number),
          veteran_service_branch: params.dig(:veteran, :service_branch),
          veteran_service_branch_other: params.dig(:veteran, :service_branch_other),
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
    end
  end
end
