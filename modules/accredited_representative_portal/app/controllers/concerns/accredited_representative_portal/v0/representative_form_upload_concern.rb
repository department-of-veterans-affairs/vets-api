# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    module RepresentativeFormUploadConcern
      extend ActiveSupport::Concern

      def validated_metadata
        {
          'veteranFirstName' => veteran_first_name,
          'veteranLastName' => veteran_last_name,
          'fileNumber' => veteran_ssn,
          'zipCode' => form_params.dig('formData', 'postalCode'),
          'source' => 'VA Platform Digital Forms',
          'docType' => form_data['formNumber'],
          'businessLine' => 'CMP'
        }
      end

      def create_new_form_data
        {
          'ssn' => ssn,
          'postalCode' => form_data['postalCode'],
          'full_name' => {
            'first' => first_name,
            'last' => last_name
          },
          'email' => form_data['email'],
          'veteranDateOfBirth' => birth_date
        }
      end

      def form_params
        params.require(:representative_form_upload).permit(
          :confirmationCode,
          :location,
          :formNumber,
          :formName,
          formData: [
            :veteranSsn,
            :formNumber,
            :postalCode,
            :veteranDateOfBirth,
            :email,
            :postal_code,
            :claimantDateOfBirth,
            :claimantSsn,
            { claimantFullName: %i[first last] },
            { veteranFullName: %i[first last] }
          ]
        )
      end

      def form_data
        form_params['formData'] || {}
      end

      def veteran_ssn
        form_params.dig('formData', 'veteranSsn')
      end

      def veteran_first_name
        form_params.dig('formData', 'veteranFullName', 'first')
      end

      def veteran_last_name
        form_params.dig('formData', 'veteranFullName', 'last')
      end

      def veteran_birth_date
        form_params.dig('formData', 'veteranDateOfBirth')
      end

      def claimant_ssn
        form_params.dig('formData', 'claimantSsn')
      end

      def claimant_first_name
        form_params.dig('formData', 'claimantFullName', 'first')
      end

      def claimant_last_name
        form_params.dig('formData', 'claimantFullName', 'last')
      end

      def claimant_birth_date
        form_params.dig('formData', 'claimantDateOfBirth')
      end

      def ssn
        claimant_ssn || veteran_ssn
      end

      def first_name
        claimant_first_name || veteran_first_name
      end

      def last_name
        claimant_last_name || veteran_last_name
      end

      def birth_date
        claimant_birth_date || veteran_birth_date
      end
    end
  end
end
