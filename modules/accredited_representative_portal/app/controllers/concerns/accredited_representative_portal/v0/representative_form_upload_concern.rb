# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    module RepresentativeFormUploadConcern # rubocop:disable Metrics/ModuleLength
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
        @form_params ||= get_form_params
      end

      def get_metadata
        {
          veteran: {
            ssn: veteran_ssn,
            dateOfBirth: veteran_birth_date,
            postalCode: form_data['postalCode'],
            name: {
              first: veteran_first_name,
              last: veteran_last_name
            }
          },
          dependent: {
            ssn: claimant_ssn,
            dateOfBirth: claimant_birth_date,
            name: {
              first: claimant_first_name,
              last: claimant_last_name
            }
          }
        }
      end

      def get_form_params # rubocop:disable Metrics/MethodLength
        unwrapped_params =
          params.require(:representative_form_upload)

        param_filters = [
          :formName,
          :confirmationCode,
          { formData: [
            :veteranSsn,
            :postalCode,
            :veteranDateOfBirth,
            :formNumber,
            :email,
            :claimantDateOfBirth,
            :claimantSsn,
            { claimantFullName: %i[first last] },
            { veteranFullName: %i[first last] }
          ] }
        ]

        ##
        # TODO: Remove. This is a workaround while we're in the situation that
        # OliveBranch modifies our params on staging but not on localhost.
        # We'll have fixed that bug when it leaves our params alone in both
        # environments.
        #
        # This `blank?` check approach  should suffice to target this
        # situation without causing some other breakage.
        #
        if unwrapped_params[:formData].blank?
          ##
          # Manual snakification of `param_filters`. Not done programmatically
          # because the algorithm would be too long for throaway code.
          #
          param_filters = [
            :confirmation_code,
            :form_name,
            { form_data: [
              :veteran_ssn,
              :postal_code,
              :veteran_date_of_birth,
              :form_number,
              :email,
              :claimant_date_of_birth,
              :claimant_ssn,
              { claimant_full_name: %i[first last] },
              { veteran_full_name: %i[first last] }
            ] }
          ]
        end

        ##
        # TODO: Remove. This is a part of the same workaround above. Once we
        # have a fix, this transformation will be purely redundant.
        #
        unwrapped_params
          .permit(*param_filters)
          .deep_transform_keys do |k|
            k.camelize(:lower)
          end
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
        claimant_ssn.presence || veteran_ssn
      end

      def first_name
        claimant_first_name.presence || veteran_first_name
      end

      def last_name
        claimant_last_name.presence || veteran_last_name
      end

      def birth_date
        claimant_birth_date.presence || veteran_birth_date
      end
    end
  end
end
