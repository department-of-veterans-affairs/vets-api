# frozen_string_literal: true

require 'dependents_verification/pdf_fill/section'

module DependentsVerification
  module PdfFill
    # Section I: Veteran's Identification Information
    class Section2 < Section
      include ::PdfFill::Forms::FormHelper
      include ::PdfFill::Forms::FormHelper::PhoneNumberFormatting
      # Section configuration hash
      KEY = {
        # 8
        'hasDependentsStatusChanged' => {
          key: key_name('8', 'StatusChange')
        }
      }.freeze

      ##
      # Expands the boolean values and assigning it to the form data.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        dependents_status = form_data['hasDependentsStatusChanged']
        form_data['hasDependentsStatusChanged'] = select_radio_button(dependents_status)

        form_data
      end

      def select_radio_button(value)
        value == 'Y' ? '0' : '1'
      end
    end
  end
end
