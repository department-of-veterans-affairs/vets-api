# frozen_string_literal: true

module PdfFill
  module Forms
    class Va288832 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'claimant_information' => {
          'full_name' => {
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
            # suffix
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
          'date_of_birth' => {
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
          'va_file_number' => {
            key: 'F[0].Page_1[0].VAFileNumber[0]',
            limit: 8,
            question_num: 1,
            question_suffix: 'A',
            question_text: 'VA FILE NUMBER'
          }
        }, # end claimant_information
        'claimant_email_address' => {
          key: 'F[0].Page_1[0].Email_Address[0]',
          limit: 30,
          question_num: 2,
          question_suffix: 'A',
          question_text: 'APPLICANT\'S E-MAIL ADDRESS'
        },
        'relationship' => {
          key: 'F[0].Page_1[0].RadioButtonList[1]'
        }, # end relationship
        'phone_number' => {
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
        },
        'claimant_address' => {
          'address_line1' => {
            key: 'F[0].Page_1[0].CurrentMailingAddress_NumberAndStreet[0]',
            limit: 30,
            question_num: 3,
            question_suffix: 'A',
            question_text: 'MAILING ADDRESS'
          },
          'address_line2' => {
            key: 'F[0].Page_1[0].CurrentMailingAddress_ApartmentOrUnitNumber[0]',
            limit: 5,
            question_num: 3,
            question_suffix: 'B',
            question_text: 'MAILING ADDRESS'
          },
          'city' => {
            key: 'F[0].Page_1[0].CurrentMailingAddress_City[0]',
            limit: 18,
            question_num: 3,
            question_suffix: 'C',
            question_text: 'MAILING ADDRESS'
          },
          'state_code' => {
            key: 'F[0].Page_1[0].CurrentMailingAddress_StateOrProvince[0]',
            limit: 2,
            question_num: 3,
            question_suffix: 'D',
            question_text: 'MAILING ADDRESS'
          },
          'country_name' => {
            key: 'F[0].Page_1[0].CurrentMailingAddress_Country[0]',
            limit: 2,
            question_num: 3,
            question_suffix: 'E',
            question_text: 'MAILING ADDRESS'
          },
          'zip_code' => {
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
        'veteran_information' => {
          'full_name' => {
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
          'va_file_number' => {
            key: 'F[0].Page_1[0].VETERANS_VAFileNumber[0]',
            limit: 8,
            question_num: 6,
            question_suffix: 'A',
            question_text: 'VA FILE NUMBER'
          },
          'service_number' => {
            key: 'F[0].Page_1[0].VAFileNumber[2]',
            limit: 8,
            question_num: 9,
            question_suffix: 'A',
            question_text: 'SERVICE NUMBER'
          }
        }, # end veteran_information
        'veteran_ssn' => {
          'first' => { key: 'F[0].Page_2[0].VeteransSocialSecurityNumber_FirstThreeNumbers[0]' },
          'second' => { key: 'F[0].Page_2[0].VeteransSocialSecurityNumber_SecondTwoNumbers[0]' },
          'third' => { key: 'F[0].Page_2[0].VeteransSocialSecurityNumber_LastFourNumbers[0]' }
        },
        'signature' => {
          key: 'signature'
        },
        'signature_date' => {
          'month' => {
            key: 'F[0].Page_2[0].DOBmonth[0]'
          },
          'day' => {
            key: 'F[0].Page_2[0].DOBday[0]'
          },
          'year' => {
            key: 'F[0].Page_2[0].DOByear[0]'
          }
        } # end date_signed
      }.freeze

      def merge_fields(_options = {})
        merge_claimant_helpers
        merge_veteran_helpers

        expand_veteran_ssn

        expand_signature(@form_data['claimant_information']['full_name'])
        @form_data['signature_date'] = split_date(@form_data['signatureDate'])

        @form_data
      end

      def merge_claimant_helpers
        claimant_information = @form_data['claimant_information']

        # extract middle initial
        claimant_information['full_name'] = extract_middle_i(claimant_information, 'full_name')

        # extract ssn
        ssn = claimant_information['ssn']
        claimant_information['ssn'] = split_ssn(ssn.delete('-')) if ssn.present?

        # extract birth date
        claimant_information['date_of_birth'] = split_date(claimant_information['date_of_birth'])

        # extract relationship
        expand_relationship

        # extract phone_number
        expand_phone_number

        # extract postal code and country
        claimant_address = @form_data['claimant_address']
        claimant_address['zip_code'] = split_postal_code(claimant_address)
        claimant_address['country_name'] = extract_country(claimant_address)
      end

      def merge_veteran_helpers
        veteran_information = @form_data['veteran_information']
        return if veteran_information.blank?

        # extract middle initial
        veteran_information['full_name'] = extract_middle_i(veteran_information, 'full_name')

        # extract ssn
        ssn = veteran_information['ssn']
        veteran_information['ssn'] = split_ssn(ssn.delete('-')) if ssn.present?
      end

      def expand_relationship
        relationship = @form_data['status']
        @form_data['relationship'] =
          if relationship == 'isChild'
            '5'
          elsif relationship == 'isSpouse'
            '2'
          else
            '1'
          end
      end

      def expand_phone_number
        phone_number = @form_data['phone_number']
        if phone_number.present?
          phone_number = phone_number.delete('^0-9')
          @form_data['phone_number'] = {
            'phone_area_code' => phone_number[0..2],
            'phone_first_three_numbers' => phone_number[3..5],
            'phone_last_four_numbers' => phone_number[6..9]
          }
        end
      end

      def expand_veteran_ssn
        # veteran ssn is at the top of page 2
        veteran_information = @form_data['veteran_information']
        veteran_ssn =
          if veteran_information.blank?
            @form_data['claimant_information']['ssn']
          else
            @form_data['veteran_information']['ssn']
          end
        @form_data['veteran_ssn'] = veteran_ssn
      end
    end
  end
end
