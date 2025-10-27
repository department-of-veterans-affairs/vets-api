# frozen_string_literal: true

require 'medical_expense_reports/pdf_fill/section'
require 'pdf_fill/forms/form_helper'

module MedicalExpenseReports
  module PdfFill
    # Section II: Claimant's Contact Information
    class Section2 < Section
      include ::PdfFill::Forms::FormHelper
      include ::PdfFill::Forms::FormHelper::PhoneNumberFormatting

      # Section configuration hash
      KEY = {
        # 2a
        'claimantFullName' => {
          'first' => {
            limit: 12,
            question_num: 2,
            question_suffix: 'A',
            question_label: "Claimant's First Name",
            question_text: 'CLAIMANT\'S FIRST NAME',
            key: 'form1[0].#subform[9].TextField1[3]'
          },
          'middle' => {
            limit: 1,
            question_num: 2,
            question_suffix: 'A',
            key: 'form1[0].#subform[9].TextField1[4]'
          },
          'last' => {
            limit: 18,
            question_num: 2,
            question_suffix: 'A',
            question_label: "Claimant's Last Name",
            question_text: 'CLAIMANT\'S LAST NAME',
            key: 'form1[0].#subform[9].TextField1[5]'
          }
        },
        # 2b
        'claimantAddress' => {
          'street' => {
            limit: 30,
            question_num: 2,
            question_suffix: 'B',
            question_label: 'Mailing Address Number And Street',
            question_text: 'MAILING ADDRESS NUMBER AND STREET',
            key: 'form1[0].#subform[9].TextField1[7]'
          },
          'street2' => {
            limit: 5,
            question_num: 2,
            question_suffix: 'B',
            question_label: 'Mailing Address Apt/Unit',
            question_text: 'MAILING ADDRESS APT/UNIT',
            key: 'form1[0].#subform[9].TextField1[6]'
          },
          'city' => {
            limit: 18,
            question_num: 2,
            question_suffix: 'B',
            question_label: 'Mailing Address City',
            question_text: 'MAILING ADDRESS CITY',
            key: 'form1[0].#subform[9].TextField1[8]'
          },
          'state' => {
            key: 'form1[0].#subform[9].TextField1[9]'
          },
          'country' => {
            key: 'form1[0].#subform[9].TextField1[10]'
          },
          'postalCode' => {
            key: 'form1[0].#subform[9].TextField1[11]'
          }
        },
        # 2c
        'primaryPhone' => {
          'phone_area_code' => {
            key: 'form1[0].#subform[9].Telephone_Number_First_Three_Numbers[0]'
          },
          'phone_first_three_numbers' => {
            key: 'form1[0].#subform[9].Telephone_Number_Second_Three_Numbers[0]'
          },
          'phone_last_four_numbers' => {
            key: 'form1[0].#subform[9].Telephone_Number_Last_Four_Numbers[0]'
          }
        },
        'internationalPhone' => {
          key: 'form1[0].#subform[9].International_Phone_Number[0]'
        },
        # 2d
        'claimantEmail' => {
          key: 'form1[0].#subform[9].Claimants_E_Mail_Address[0]'
        }
      }.freeze

      # expand claimant information
      def expand(form_data = {})
        form_data['claimantFullName'] ||= {}
        form_data['claimantFullName']['first'] = form_data.dig('claimantFullName', 'first')&.titleize
        form_data['claimantFullName']['middle'] = form_data.dig('claimantFullName', 'middle')&.first&.capitalize
        form_data['claimantFullName']['last'] = form_data.dig('claimantFullName', 'last')&.titleize
        form_data['claimantAddress'] ||= {}
        form_data['primaryPhone'] ||= {}
        if form_data['primaryPhone']['countryCode'] == 'US'
          form_data['primaryPhone'] = expand_phone_number(form_data['primaryPhone']['contact'].to_s)
        else
          form_data['internationalPhone'] = form_data['primaryPhone']['contact']
        end
        form_data['claimantEmail'] = form_data['email']
        form_data
      end
    end
  end
end
