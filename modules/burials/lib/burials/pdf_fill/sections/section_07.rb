# frozen_string_literal: true

require_relative '../section'

module Burials
  module PdfFill
    # Section VII: Claim certification and signatures
    class Section7 < Section
      # Section configuration hash
      KEY = {
        # Claimant certification and signature (No question number))
        'hasProcessOption' => {
          key: 'form1[0].#subform[83].WantClaimFDCProcessedYes[0]'
        },
        'noProcessOption' => {
          key: 'form1[0].#subform[83].WantClaimFDCProcessedNo[0]'
        },
        # 25A
        'signature' => {
          key: 'form1[0].#subform[83].CLAIMANT_SIGNATURE[0]',
          limit: 45,
          question_num: 25,
          question_label: 'Signature Of Claimant',
          question_text: 'SIGNATURE OF CLAIMANT',
          question_suffix: 'A'
        },
        # 25B
        'claimantPrintedName' => {
          key: 'form1[0].#subform[83].ClaimantPrintedName[0]',
          limit: 45,
          question_num: 25,
          question_label: 'Printed Name Of Claimant',
          question_text: 'Printed Name of Claimant',
          question_suffix: 'B'
        },
        # 26A
        'firmNameAndAddr' => {
          key: 'form1[0].#subform[83].FirmNameAndAddress[0]',
          limit: 90,
          question_num: 26,
          question_suffix: 'B',
          question_label: 'Full Name And Address Of The Firm, Corporation, Or State Agency Filing As Claimant',
          question_text: 'FULL NAME AND ADDRESS OF THE FIRM, CORPORATION, OR STATE AGENCY FILING AS CLAIMANT'
        },
        # 26B
        'officialPosition' => {
          key: 'form1[0].#subform[83].OfficialPosition[0]',
          limit: 90,
          question_num: 26,
          question_suffix: 'B',
          question_label: 'Official Position Of Person Signing On Behalf Of Firm, Corporation Or State Agency',
          question_text: 'OFFICIAL POSITION OF PERSON SIGNING ON BEHALF OF FIRM, CORPORATION OR STATE AGENCY'
        },
        # Veteran's Social Security Number (No question number)
        'veteranSocialSecurityNumber3' => {
          'first' => {
            key: 'form1[0].#subform[83].#subform[84].VeteransSocialSecurityNumber_FirstThreeNumbers[2]'
          },
          'second' => {
            key: 'form1[0].#subform[83].#subform[84].VeteransSocialSecurityNumber_SecondTwoNumbers[2]'
          },
          'third' => {
            key: 'form1[0].#subform[83].#subform[84].VeteransSocialSecurityNumber_LastFourNumbers[2]'
          }
        }
      }.freeze

      ##
      # Expands the form data for Section 7.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        signature = combine_hash(form_data['claimantFullName'], %w[first last])
        form_data['signature'] = signature
        form_data['signatureDate'] = Time.zone.today.to_s if signature.present?
        expand_checkbox_in_place(form_data, 'processOption')
      end
    end
  end
end
