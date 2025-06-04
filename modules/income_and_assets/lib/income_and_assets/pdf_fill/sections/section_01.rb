# frozen_string_literal: true

require 'income_and_assets/pdf_fill/section'

module IncomeAndAssets
  module PdfFill
    # Section I: Veteran Informations
    class Section1 < Section
      # Section configuration hash
      # NOTE: `key` fields should follow the format:
      #   `<section_prefix>.<subsection>.<key>`
      # Example: 'Section1A.VeteranName.First'
      KEY = {
        # 1A
        'veteranFullName' => {
          # form allows up to 39 characters but validation limits to 30,
          # so no overflow is needed
          'first' => {
            key: generate_key('A', 'VeteranName.First')
          },
          'middle' => {
            key: generate_key('A', 'VeteranName.MI')
          },
          # form allows up to 34 characters but validation limits to 30,
          # so no overflow is needed
          'last' => {
            key: generate_key('A', 'VeteranName.Last')
          }
        },
        # 1B
        'veteranSocialSecurityNumber' => {
          key: generate_key('B', 'VeteranSSN')
        },
        # 1C
        'vaFileNumber' => {
          key: generate_key('C', 'VeteranFileNumber')
        }
      }.freeze

      ##
      # Expands the veteran's information by extracting and capitalizing the first letter of the middle name.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        veteran_middle_name = form_data['veteranFullName'].try(:[], 'middle')
        form_data['veteranFullName']['middle'] = veteran_middle_name.try(:[], 0)&.upcase
      end
    end
  end
end
