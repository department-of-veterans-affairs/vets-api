# frozen_string_literal: true

require 'income_and_assets/pdf_fill/section'

module IncomeAndAssets
  module PdfFill
    # Section XIII: Statement of Truth
    class Section13 < Section
      # Section configuration hash
      KEY = {
        # 13a
        'statementOfTruthSignature' => { key: 'F[0].#subform[9].SignatureField11[0]' },
        # 13b
        'statementOfTruthSignatureDate' => {
          'month' => { key: 'F[0].DateSigned13bMonth[0]' },
          'day' => { key: 'F[0].DateSigned13bDay[0]' },
          'year' => { key: 'F[0].DateSigned13bYear[0]' }
        }
      }.freeze

      ##
      # Expands statement of truth section
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      # @note No overflow for this section
      #
      def expand(form_data)
        # We want today's date in the form 'YYYY-MM-DD' as that's the format it comes
        # back from vets-website in
        form_data['statementOfTruthSignatureDate'] = split_date(Date.current.iso8601)
      end
    end
  end
end
