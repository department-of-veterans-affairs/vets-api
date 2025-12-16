# frozen_string_literal: true

require_relative '../section'

module Pensions
  module PdfFill
    # Section XII: Claim Certification and Signature
    class Section12 < Section
      # Section configuration hash
      KEY = {
        # 12a
        'noRapidProcessing' => {
          # rubocop:disable Layout/LineLength
          key: 'form1[0].#subform[54].CheckBox_I_Do_Not_Want_My_Claim_Considered_For_Rapid_Processing_Under_The_F_D_C_Program_Because_I_Plan_To_Submit_Further_Evidence_In_Support_Of_My_Claim[0]'
          # rubocop:enable Layout/LineLength
        },
        # 12b
        'statementOfTruthSignature' => {
          key: 'form1[0].#subform[54].SignatureField1[0]'
        },
        # 12c
        'signatureDate' => {
          'month' => {
            key: 'form1[0].#subform[54].Date_Signed_Month[0]'
          },
          'day' => {
            key: 'form1[0].#subform[54].Date_Signed_Day[0]'
          },
          'year' => {
            key: 'form1[0].#subform[54].Date_Signed_Year[0]'
          }
        }
      }.freeze

      ##
      # Processes the noRapidProcessing checkbox and splits the signature date into its components.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        form_data['noRapidProcessing'] = to_checkbox_on_off(form_data['noRapidProcessing'])
        # signed on provided date (generally SavedClaim.created_at) or default to today
        signature_date = form_data['signatureDate'] || Time.zone.now.strftime('%Y-%m-%d')
        form_data['signatureDate'] = split_date(signature_date)
      end
    end
  end
end
