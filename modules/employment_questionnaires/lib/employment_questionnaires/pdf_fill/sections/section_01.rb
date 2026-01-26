# frozen_string_literal: true

require 'employment_questionnaires/pdf_fill/section'

module EmploymentQuestionnaires
  module PdfFill
    # Section I: Veteran's Identification Information
    class Section1 < Section
      include Helpers
      include ::PdfFill::Forms::FormHelper
      include ::PdfFill::Forms::FormHelper::PhoneNumberFormatting

      # Section configuration hash
      KEY = {
        'veteranFullName' => {
          'first' => {
            limit: 12,
            question_num: 1,
            key: 'F[0].Page_1[0].VeteranFirstName[0]'
          },
          'middle' => {
            limit: 1,
            question_num: 1,
            key: 'F[0].Page_1[0].VeteranMiddleInitial1[0]'
          },
          'last' => {
            limit: 18,
            question_num: 1,
            key: 'F[0].Page_1[0].VeteranLastName[0]'
          }
        },
        'veteranSocialSecurityNumber' => {
          'first' => {
            limit: 3,
            question_num: 2,
            key: 'F[0].Page_1[0].Veterans_Social_SecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            limit: 2,
            question_num: 2,
            key: 'F[0].Page_1[0].Veterans_Social_SecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            limit: 4,
            question_num: 2,
            key: 'F[0].Page_1[0].Veterans_Social_SecurityNumber_LastFourNumbers[0]'
          }
        },
        'vaFileNumber' => {
          question_num: 3,
          limit: 9,
          key: 'F[0].Page_1[0].VAFileNumber[0]'
        },
        'dateOfBirth' => {
          'month' => {
            limit: 2,
            question_num: 4,
            key: 'F[0].Page_1[0].DOBmonth[0]'
          },
          'day' => {
            limit: 2,
            question_num: 4,
            key: 'F[0].Page_1[0].DOBday[0]'
          },
          'year' => {
            limit: 4,
            question_num: 4,
            key: 'F[0].Page_1[0].DOByear[0]'
          }
        },
        'veteranServiceNumber' => {
          limit: 9,
          question_num: 5,
          key: 'F[0].Page_1[0].VeteransServiceNumber[0]'
        },
        'veteranContact' => {
          'email' => {
            limit: 50,
            question_num: 6,
            key: 'F[0].Page_1[0].E-Mail_Address[0]'
          },
          'primaryPhone' => {
            limit: 10,
            question_num: 7,
            key: 'F[0].Page_1[0].PrimaryTelephoneNumber[0]'
          },
          'alternatePhone' => {
            limit: 10,
            question_num: 8,
            key: 'F[0].Page_1[0].AlternateTelephoneNumber[0]'
          }
        },
        'veteranAddress' => {
          'street' => {
            limit: 30,
            question_num: 9,
            key: 'F[0].Page_1[0].CurrentMailingAddress_NumberAndStreet[0]'
          },
          'apartment' => {
            limit: 5,
            question_num: 9,
            key: 'F[0].Page_1[0].CurrentMailingAddress_ApartmentOrUnitNumber[0]'
          },
          'city' => {
            limit: 20,
            question_num: 9,
            key: 'F[0].Page_1[0].CurrentMailingAddress_City[0]'
          },
          'state' => {
            limit: 2,
            question_num: 9,
            key: 'F[0].Page_1[0].CurrentMailingAddress_StateOrProvince[0]'
          },
          'postalCode' => {
            'firstFive' => {
              limit: 5,
              question_num: 9,
              key: 'F[0].Page_1[0].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]'
            },
            'lastFour' => {
              limit: 5,
              question_num: 9,
              key: 'F[0].Page_1[0].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]'
            }
          },
          'country' => {
            limit: 20,
            question_num: 9,
            key: 'F[0].Page_1[0].CurrentMailingAddress_Country[0]'
          }
        }
      }.freeze

      def expand(form_data = {})
        split_data(form_data)

        form_data
      end

      def split_data(form_data)
        form_data['dateOfBirth'] = split_date(form_data['dateOfBirth'])
        form_data['veteranAddress']['postalCode'] = split_postal_code(form_data['veteranAddress'])
        form_data['veteranSocialSecurityNumber'] = split_ssn(form_data['veteranSocialSecurityNumber'])

        form_data
      end
    end
  end
end
