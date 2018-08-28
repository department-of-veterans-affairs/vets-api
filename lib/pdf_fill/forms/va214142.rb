# frozen_string_literal: true

module PdfFill
  module Forms
    class Va214142 < FormBase
      include FormHelper
      
      KEY = {
        'veteranFullName' => {
          'first' => {
            key: 'F[0].Page_1[0].VeteranFirstName[0]',
            limit: 12,
            question_num: 1,
            question_text: "VETERAN/BENEFICIARY'S FIRST NAME"
          },
          'middleInitial' => {
            key: 'F[0].Page_1[0].VeteranMiddleInitial1[0]'
          },
          'last' => {
            key: 'F[0].Page_1[0].VeteranLastName[0]',
            limit: 18,
            question_num: 1,
            question_text: "VETERAN/BENEFICIARY'S LAST NAME"
          }
        },
        'veteranSocialSecurityNumber' => {
          'first' => {
            key: 'F[0].Page_1[0].ClaimantsSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'F[0].Page_1[0].ClaimantsSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'F[0].Page_1[0].ClaimantsSocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        'vaFileNumber' => {
          key: 'F[0].Page_1[0].VAFileNumber[0]'
        },
        'veteranDateOfBirth' => {
          'month' => {
            key: 'F[0].Page_1[0].DOBmonth[0]'
          },
          'day' => {
            key: 'F[0].Page_1[0].DOBday[0]'
          },
          'year' => {
            key: 'F[0].Page_1[0].DOByear[0]'
          }
        },
        'veteranServiceNumber' => {
          key: 'F[0].Page_1[0].VeteransServiceNumber[0]'
        },
        'claimantAddress' => {
          question_num: 6,
          question_text: 'MAILING ADDRESS',

          'veteranAddressLine1' => {
            key: 'F[0].Page_1[0].CurrentMailingAddress_NumberAndStreet[0]',
            limit: 30,
            question_num: 6,
            question_suffix: 'A',
            question_text: 'Number and Street'
          },
          'apartmentOrUnitNumber' => {
            key: 'F[0].Page_1[0].CurrentMailingAddress_ApartmentOrUnitNumber[0]',
            limit: 5,
            question_num: 6,
            question_suffix: 'B',
            question_text: 'Apartment or Unit Number'
          },
          'city' => {
            key: 'F[0].Page_1[0].CurrentMailingAddress_City[0]',
            limit: 18,
            question_num: 6,
            question_suffix: 'C',
            question_text: 'City'
          },
          'state' => {
            key: 'F[0].Page_1[0].CurrentMailingAddress_StateOrProvince[0]'
          },
          'country' => {
            key: 'F[0].Page_1[0].CurrentMailingAddress_Country[0]',
            limit: 2
          },
          'postalCode' => {
            'firstFive' => {
              key: 'F[0].Page_1[0].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]'
            },
            'lastFour' => {
              key: 'F[0].Page_1[0].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]'
            }
          }
        },
        'claimantEmail' => {
          key: 'F[0].Page_1[0].EMAIL[0]'
        },
        'claimantPhone' => {
          key: 'F[0].Page_1[0].EMAIL[1]'
        },
        'veteranSocialSecurityNumber1' => {
          'first' => {
            key: 'F[0].#subform[1].VeteransSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'F[0].#subform[1].VeteransSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'F[0].#subform[1].VeteransSocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        'limitedConsent' => {
          key: 'F[0].#subform[1].InformationIsLimitedToWhatIsWrittenInThisSpace[0]'
        },
        'signature' => {
          key: 'F[0].#subform[1].CLAIMANT_SIGNATURE[0]'
        },
        'signatureDate' => {
          key: 'F[0].#subform[1].DateSigned_Month_Day_Year[0]'
        },
        'printedName' => {
          key: 'F[0].#subform[1].PrintedNameOfPersonAuthorizingDisclosure[0]'
        }
      }.freeze

      def merge_fields
        @form_data['vaFileNumber'] = FormHelper.extract_va_file_number(@form_data['vaFileNumber'])

        ssn = @form_data['veteranSocialSecurityNumber']
        ['', '1'].each do |suffix|
          @form_data["veteranSocialSecurityNumber#{suffix}"] = FormHelper.split_ssn(ssn)
        end

        @form_data['veteranFullName'] = FormHelper.extract_middle_i(@form_data, 'veteranFullName')

        expand_signature(@form_data['veteranFullName'])

        @form_data['printedName'] = @form_data['signature']

        @form_data['claimantAddress']['country'] = FormHelper.extract_country(@form_data['claimantAddress'])

        @form_data['claimantAddress']['postalCode'] = FormHelper.split_postal_code(@form_data['claimantAddress'])

        @form_data['veteranDateOfBirth'] = FormHelper.split_date(@form_data['veteranDateOfBirth'])

        @form_data
      end
    end
  end
end
