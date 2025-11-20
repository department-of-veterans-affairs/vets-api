# frozen_string_literal: true

require 'dependents_verification/pdf_fill/section'

module DependentsVerification
  module PdfFill
    # Section I: Veteran's Identification Information
    class Section0 < Section
      include ::PdfFill::Forms::FormHelper
      # Section configuration hash
      KEY = {
        # 0
        'dateStamp' => {
          key: key_name('0', 'VaDateStamp')
        }
      }.freeze

      ##
      # Expands the datestamp box datetime.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        form_data['dateStamp'] = "Application Submitted on va.gov\n#{I18n.l(form_data['dateStamp'],
                                                                            format: :pdf_stamp_utc)}"
        form_data
      end
    end
  end
end
