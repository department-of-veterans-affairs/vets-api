# frozen_string_literal: true

require 'dependents_verification/pdf_fill/section'

module DependentsVerification
  module PdfFill
    # Section I: Veteran's Identification Information
    class SectionI < Section
      # Section configuration hash
      KEY = {
        # 1
        'veteranFullName' => {
          'first' => {
            key: 'SectionI1.VeteransName.First',
            limit: 12,
            question_num: 1,
            question_text: "VETERAN'S FIRST NAME"
          },
          'middleInitial' => {
            key: 'SectionI1.VeteransName.MI',
            question_num: 1,
            limit: 1,
            question_text: "VETERAN'S MIDDLE INITIAL"
          },
          'last' => {
            key: 'SectionI1.VeteransName.Last',
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
        expand_veteran_full_name(form_data)
      end

      ##
      # Extracts the veteran's full name from the form data and formats it by adding a middle initial.
      #
      # @param form_data [Hash]
      # @return [Hash] The formatted veteran's full name with middle initial
      #
      def expand_veteran_full_name(form_data)
        veteran_name = form_data.dig('dependencyVerification', 'veteranInformation', 'fullName') || {}
        veteran_middle_name = veteran_name.try(:[], 'middle')

        form_data['veteranFullName'] = {
          'first' => veteran_name['first'],
          # Use the first character of the middle name as the middle initial, or an empty string if not present
          'middleInitial' => veteran_middle_name.try(:[], 0)&.upcase || '',
          'last' => veteran_name['last']
        }
      end
    end
  end
end
