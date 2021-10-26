# frozen_string_literal: true

module PdfFill
  module Forms
    class Va288832 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'claimantInformation' => {
          'fullName' => {
            'first' => {
              key: 'F[0].Page_1[0].ClaimantsFirstName[0]',
              limit: 12,
              question_num: 1,
              question_suffix: 'A',
              question_text: 'NAME OF CLAIMANT'
            },
            'middleInitial' => {
              key: 'F[0].Page_1[0].ClaimantsMiddleInitial[0]',
              limit: 1,
              question_num: 1,
              question_suffix: 'B',
              question_text: 'NAME OF CLAIMANT'
            },
            'last' => {
              key: 'F[0].Page_1[0].ClaimantsLastName[0]',
              limit: 18,
              question_num: 1,
              question_suffix: 'C',
              question_text: 'NAME OF CLAIMANT'
            }
          }, # end full_name
          'ssn' => {
            'first' => {
              key: 'F[0].Page_1[0].SocialSecurityNumber_FirstThreeNumbers[0]',
              limit: 3,
              question_num: 1,
              question_suffix: 'A',
              question_text: 'SOCIAL SECURITY NUMBER OF APPLICANT'
            },
            'second' => {
              key: 'F[0].Page_1[0].SocialSecurityNumber_SecondTwoNumbers[0]',
              limit: 2,
              question_num: 1,
              question_suffix: 'B',
              question_text: 'SOCIAL SECURITY NUMBER OF APPLICANT'
            },
            'third' => {
              key: 'F[0].Page_1[0].SocialSecurityNumber_LastFourNumbers[0]',
              limit: 4,
              question_num: 1,
              question_suffix: 'C',
              question_text: 'SOCIAL SECURITY NUMBER OF APPLICANT'
            }
          }, # end ssn
          'dateOfBirth' => {
            'month' => {
              key: 'F[0].Page_1[0].DOBmonth[0]',
              limit: 2,
              question_num: 1,
              question_suffix: 'A',
              question_text: 'DATE OF BIRTH'
            },
            'day' => {
              key: 'F[0].Page_1[0].DOBday[0]',
              limit: 2,
              question_num: 1,
              question_suffix: 'B',
              question_text: 'DATE OF BIRTH'
            },
            'year' => {
              key: 'F[0].Page_1[0].DOByear[0]',
              limit: 4,
              question_num: 1,
              question_suffix: 'C',
              question_text: 'DATE OF BIRTH'
            }
          },
          'vaFileNumber' => {
            key: 'F[0].Page_1[0].VAFileNumber[0]',
            limit: 8,
            question_num: 1,
            question_suffix: 'A',
            question_text: 'VA FILE NUMBER'
          },
          'emailAddress' => {
            key: 'F[0].Page_1[0].Email_Address[0]',
            limit: 30,
            question_num: 2,
            question_suffix: 'A',
            question_text: 'APPLICANT\'S E-MAIL ADDRESS'
          },
          'phoneNumber' => {
            'phone_area_code' => {
              key: 'F[0].Page_1[0].TelephoneNumber_AreaCode[0]',
              limit: 3,
              question_num: 3,
              question_suffix: 'A',
              question_text: 'TELEPHONE NUMBER'
            },
            'phone_first_three_numbers' => {
              key: 'F[0].Page_1[0].TelephoneNumber_FirstThreeNumbers[0]',
              limit: 3,
              question_num: 3,
              question_suffix: 'B',
              question_text: 'TELEPHONE NUMBER'
            },
            'phone_last_four_numbers' => {
              key: 'F[0].Page_1[0].TelephoneNumber_LastFourNumbers[0]',
              limit: 4,
              question_num: 3,
              question_suffix: 'C',
              question_text: 'TELEPHONE NUMBER'
            }
          }
        }, # end claimantInformation
        'claimantAddress' => {
          'street' => {
            key: 'F[0].Page_1[0].CurrentMailingAddress_NumberAndStreet[0]',
            limit: 30,
            question_num: 3,
            question_suffix: 'A',
            question_text: 'MAILING ADDRESS'
          },
          'city' => {
            key: 'F[0].Page_1[0].CurrentMailingAddress_City[0]',
            limit: 18,
            question_num: 3,
            question_suffix: 'C',
            question_text: 'MAILING ADDRESS'
          },
          'state' => {
            key: 'F[0].Page_1[0].CurrentMailingAddress_StateOrProvince[0]',
            limit: 2,
            question_num: 3,
            question_suffix: 'D',
            question_text: 'MAILING ADDRESS'
          },
          'country' => {
            key: 'F[0].Page_1[0].CurrentMailingAddress_Country[0]',
            limit: 2,
            question_num: 3,
            question_suffix: 'E',
            question_text: 'MAILING ADDRESS'
          },
          'postalCode' => {
            'firstFive' => {
              key: 'F[0].Page_1[0].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]',
              limit: 5,
              question_num: 3,
              question_suffix: 'F',
              question_text: 'MAILING ADDRESS'
            },
            'lastFour' => {
              key: 'F[0].Page_1[0].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]',
              limit: 4,
              question_num: 3,
              question_suffix: 'G',
              question_text: 'MAILING ADDRESS'
            }
          } # end zip_code
        }, # end dependent_address
        'relationship' => {
          key: 'F[0].Page_1[0].RadioButtonList[1]'
        }, # end relationship
        'veteranFullName' => {
          'first' => {
            key: 'F[0].Page_1[0].ClaimantsFirstName[1]',
            limit: 12,
            question_num: 6,
            question_suffix: 'A',
            question_text: 'NAME OF VETERAN OR INDIVIDUAL ON ACTIVE DUTY ON WHOSE ACCOUNT BENEFITS ARE CLAIMED'
          },
          'middleInitial' => {
            key: 'F[0].Page_1[0].ClaimantsMiddleInitial[1]',
            limit: 1,
            question_num: 6,
            question_suffix: 'B',
            question_text: 'NAME OF VETERAN OR INDIVIDUAL ON ACTIVE DUTY ON WHOSE ACCOUNT BENEFITS ARE CLAIMED'
          },
          'last' => {
            key: 'F[0].Page_1[0].ClaimantsLastName[1]',
            limit: 18,
            question_num: 6,
            question_suffix: 'C',
            question_text: 'NAME OF VETERAN OR INDIVIDUAL ON ACTIVE DUTY ON WHOSE ACCOUNT BENEFITS ARE CLAIMED'
          }
          # suffix
        }, # end full_name
        'ssn' => {
          'first' => {
            key: 'F[0].Page_1[0].VeteransSocialSecurityNumber_FirstThreeNumbers[0]',
            limit: 3,
            question_num: 6,
            question_suffix: 'A',
            question_text: 'SOCIAL SECURITY NUMBER'
          },
          'second' => {
            key: 'F[0].Page_1[0].VeteransSocialSecurityNumber_SecondTwoNumbers[0]',
            limit: 2,
            question_num: 6,
            question_suffix: 'B',
            question_text: 'SOCIAL SECURITY NUMBER'
          },
          'third' => {
            key: 'F[0].Page_1[0].VeteransSocialSecurityNumber_LastFourNumbers[0]',
            limit: 4,
            question_num: 6,
            question_suffix: 'C',
            question_text: 'SOCIAL SECURITY NUMBER'
          }
        },
        'dob' => {
          'month' => {
            key: 'F[0].Page_1[0].DOBmonth[1]',
            limit: 2,
            question_num: 7,
            question_suffix: 'A',
            question_text: 'DATE OF BIRTH'
          },
          'day' => {
            key: 'F[0].Page_1[0].DOBday[1]',
            limit: 2,
            question_num: 7,
            question_suffix: 'B',
            question_text: 'DATE OF BIRTH'
          },
          'year' => {
            key: 'F[0].Page_1[0].DOByear[1]',
            limit: 4,
            question_num: 7,
            question_suffix: 'C',
            question_text: 'DATE OF BIRTH'
          }
        },
        'vaFileNumber' => {
          key: 'F[0].Page_1[0].VETERANS_VAFileNumber[0]',
          limit: 8,
          question_num: 6,
          question_suffix: 'A',
          question_text: 'VA FILE NUMBER'
        },
        'serviceNumber' => {
          key: 'F[0].Page_1[0].VAFileNumber[2]',
          limit: 8,
          question_num: 9,
          question_suffix: 'A',
          question_text: 'SERVICE NUMBER'
        },
        'veteranSsn' => {
          'first' => { key: 'F[0].Page_2[0].VeteransSocialSecurityNumber_FirstThreeNumbers[0]' },
          'second' => { key: 'F[0].Page_2[0].VeteransSocialSecurityNumber_SecondTwoNumbers[0]' },
          'third' => { key: 'F[0].Page_2[0].VeteransSocialSecurityNumber_LastFourNumbers[0]' }
        },
        'signature' => {
          key: 'signature'
        },
        'signatureDate' => {
          'month' => {
            key: 'F[0].Page_2[0].DOBmonth[0]'
          },
          'day' => {
            key: 'F[0].Page_2[0].DOBday[0]'
          },
          'year' => {
            key: 'F[0].Page_2[0].DOByear[0]'
          }
        }, # end date_signed
        'claimantName' => { key: 'claimantName' },
        'claimantSsn' => { key: 'claimantSsn' },
        'claimantDob' => { key: 'claimantDob' },
        'claimantVaFileNumber' => { key: 'claimantVaFileNumber' },
        'claimantEmail' => { key: 'claimantEmail' },
        'claimantRelationship' => { key: 'claimantRelationship' },
        'claimantTelephone' => { key: 'claimantTelephone' },
        'claimantMailingAddress' => { key: 'claimantMailingAddress' },
        'veteranName' => { key: 'veteranName' },
        'veteranSocialSecurityNumber' => { key: 'veteranSocialSecurityNumber' },
        'veteranVaFileNumber' => { key: 'veteranVaFileNumber' }
      }.freeze

      def merge_fields(_options = {})
        merge_addendum_helpers
        merge_claimant_helpers
        merge_veteran_helpers

        expand_veteran_ssn

        expand_signature(@form_data['claimantInformation']['fullName'])
        @form_data['signatureDate'] = split_date(@form_data['signatureDate'])

        @form_data
      end

      def merge_claimant_helpers
        claimant_information = @form_data['claimantInformation']

        # extract middle initial
        claimant_information['fullName'] = extract_middle_i(claimant_information, 'fullName')

        # extract ssn
        ssn = claimant_information['ssn']
        claimant_information['ssn'] = split_ssn(ssn.delete('-')) if ssn.present?

        # extract birth date
        claimant_information['dateOfBirth'] = split_date(claimant_information['dateOfBirth'])

        # extract relationship
        expand_relationship

        # extract phone_number
        expand_phone_number

        # extract postal code and country
        claimant_addr = @form_data['claimantAddress']
        claimant_addr['postalCode'] = split_postal_code(claimant_addr)
        claimant_addr['country'] = extract_country(claimant_addr)

        claimant_addr['street'] = "#{claimant_addr['street']} #{claimant_addr['street2']} #{claimant_addr['street3']}"
      end

      def merge_veteran_helpers
        return if @form_data['veteranFullName'].blank?

        # extract middle initial
        @form_data['veteranFullName'] = extract_middle_i(@form_data, 'veteranFullName')

        # extract ssn
        ssn = @form_data['veteranSocialSecurityNumber']
        @form_data['ssn'] = split_ssn(ssn.delete('-')) if ssn.present?
      end

      def expand_relationship
        relationship = @form_data['status']
        @form_data['relationship'] =
          case relationship
          when 'isChild'
            '5'
          when 'isSpouse'
            '2'
          else
            '1'
          end
      end

      def expand_phone_number
        phone_number = @form_data['claimantInformation']['phoneNumber']
        if phone_number.present?
          phone_number = phone_number.delete('^0-9')
          @form_data['claimantInformation']['phoneNumber'] = {
            'phone_area_code' => phone_number[0..2],
            'phone_first_three_numbers' => phone_number[3..5],
            'phone_last_four_numbers' => phone_number[6..9]
          }
        end
      end

      def expand_veteran_ssn
        # veteran ssn is at the top of page 2
        # Not sure what the purpose of this is
        ssn = @form_data['veteranSocialSecurityNumber']
        return @form_data['veteranSsn'] = split_ssn(ssn.delete('-')) if ssn.present?

        @form_data['veteranSsn'] = @form_data.dig('claimantInformation', 'ssn')
      end

      def merge_addendum_helpers
        @form_data['claimantName'] = combine_full_name(@form_data.dig('claimantInformation', 'fullName'))
        @form_data['claimantSsn'] = @form_data.dig('claimantInformation', 'ssn')
        @form_data['claimantDob'] = @form_data.dig('claimantInformation', 'dateOfBirth')
        @form_data['claimantVaFileNumber'] = @form_data.dig('claimantInformation', 'vaFileNumber')
        # possible values for relationship: ['isActiveDuty', 'isVeteran', 'isSpouse', 'isChild']
        # on the PDF we want to remove the 'is' from the beginning of each of those values
        @form_data['claimantRelationship'] = @form_data['status'][2..]
        @form_data['claimantEmail'] = @form_data.dig('claimantInformation', 'emailAddress')
        @form_data['claimantTelephone'] = @form_data.dig('claimantInformation', 'phoneNumber')
        @form_data['claimantMailingAddress'] = combine_full_address(@form_data['claimantAddress'])
        @form_data['veteranName'] = combine_full_name(@form_data['veteranFullName'])
        @form_data['veteranVaFileNumber'] = @form_data['vaFileNumber']
      end
    end
  end
end
