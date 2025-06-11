# frozen_string_literal: true

require 'dependents_verification/pdf_fill/section'

module DependentsVerification
  module PdfFill
    # Section I: Veteran's Identification Information
    class Section1 < Section
      # Section configuration hash
      KEY = {
        # 1
        'veteranFullName' => {
          'first' => {
            key: key_name('1', 'VeteranName', 'First'),
            limit: 12,
            question_num: 1,
            question_text: "VETERAN'S FIRST NAME"
          },
          'middleInitial' => {
            key: key_name('1', 'VeteranName', 'MI'),
            limit: 1,
            question_num: 1,
            question_text: "VETERAN'S MIDDLE INITIAL"
          },
          'last' => {
            key: key_name('1', 'VeteranName', 'Last'),
            limit: 18,
            question_num: 1,
            question_text: "VETERAN'S LAST NAME"
          }
        }
      }.freeze

      ##
      # Expands the veteran's information by extracting the full name and assigning it to the form data.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        veteran_information = form_data.dig('dependencyVerification', 'veteranInformation') || {}

        full_name = extract_middle_i(veteran_information, 'fullName') || {}
        full_name.delete('middle')

        form_data['veteranFullName'] = full_name
        form_data
      end
    end
  end
end
