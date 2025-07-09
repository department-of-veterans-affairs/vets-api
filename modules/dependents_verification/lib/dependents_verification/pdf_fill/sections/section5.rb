# frozen_string_literal: true

require 'dependents_verification/pdf_fill/section'

module DependentsVerification
  module PdfFill
    # Section I: Veteran's Identification Information
    class Section5 < Section
      include ::PdfFill::Forms::FormHelper
      # Section configuration hash
      KEY = {
        # 5
        'signature' => {
          key: key_name(14, 'SignatureField')
        },
        'signature_date' => {
          'month' => {
            key: key_name(14, 'SignatureDate', 'Month')
          },
          'day' => {
            key: key_name(14, 'SignatureDate', 'Day')
          },
          'year' => {
            key: key_name(14, 'SignatureDate', 'Year')
          }
        }
      }.freeze

      ##
      # Expands the signature date.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        form_data['signature_date'] = split_date(form_data['signatureDate'])
        form_data
      end
    end
  end
end
