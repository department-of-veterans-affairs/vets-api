# frozen_string_literal: true

require_relative '../section'

module Burials
  module PdfFill
    # Section VIII: Claim certification and signatures
    class Section8V2 < Section
      # Section configuration hash
      KEY = {
        # 32A
        'signature' => {
          key: 'form1[0].#subform[83].CLAIMANT_SIGNATURE[0]',
          limit: 45,
          question_num: 32,
          question_label: 'Signature Of Claimant',
          question_text: 'SIGNATURE OF CLAIMANT',
          question_suffix: 'A'
        },
        # 32B
        'claimantPrintedName' => {
          key: 'form1[0].#subform[83].ClaimantPrintedName[0]',
          limit: 45,
          question_num: 32,
          question_label: 'Printed Name Of Claimant',
          question_text: 'Printed Name of Claimant',
          question_suffix: 'B'
        },
        # 32C date
        'signatureDate' => {
          key: 'form1[0].#subform[96].Date_Signed[0]',
          limit: 10,
          question_num: 32,
          question_label: 'Date Signed',
          question_text: 'DATE SIGNED',
          question_suffix: 'C'
        },
        # Veteran's Social Security Number (No question number)
        'veteranSocialSecurityNumber3' => {
          'first' => {
            key: 'form1[0].#subform[82].VeteransSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'form1[0].#subform[82].VeteransSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[82].VeteransSocialSecurityNumber_LastFourNumbers[0]'
          }
        }
      }.freeze

      ##
      # Expands the form data for Section 8.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        signature = combine_hash(form_data['claimantFullName'], %w[first last])
        form_data['signature'] = signature
        form_data['claimantPrintedName'] = signature
        form_data['signatureDate'] = Time.zone.today.to_s if signature.present?
      end
    end
  end
end
