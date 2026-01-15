# frozen_string_literal: true

module PdfFill
  module Forms
    class Va281900 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'veteranInformation' => {
          'fullName' => {
            'first' => {
              key: 'form1[0].#subform[0].FirstName[0]',
              limit: 12,
              question_num: 1,
              question_suffix: 'A',
              question_text: "CLAIMANT'S NAME"
            },
            'middleInitial' => {
              key: 'form1[0].#subform[0].MiddleInitial[0]',
              limit: 1,
              question_num: 1,
              question_suffix: 'B',
              question_text: "CLAIMANT'S NAME"
            },
            'last' => {
              key: 'form1[0].#subform[0].LastName[0]',
              limit: 18,
              question_num: 1,
              question_suffix: 'C',
              question_text: "CLAIMANT'S NAME"
            }
          }, # end fullName
          'ssn' => {
            'first' => {
              key: 'form1[0].#subform[0].FirstThreeNumbers[0]',
              limit: 3,
              question_num: 2,
              question_suffix: 'A',
              question_text: 'SOCIAL SECURITY NUMBER'
            },
            'second' => {
              key: 'form1[0].#subform[0].SecondTwoNumbers[0]',
              limit: 2,
              question_num: 2,
              question_suffix: 'B',
              question_text: 'SOCIAL SECURITY NUMBER'
            },
            'third' => {
              key: 'form1[0].#subform[0].LastFourNumbers[0]',
              limit: 4,
              question_num: 2,
              question_suffix: 'C',
              question_text: 'SOCIAL SECURITY NUMBER'
            }
          },
          'VAFileNumber' => {
            key: 'form1[0].#subform[0].VA_File_Number[0]',
            limit: 9,
            question_num: 3,
            question_suffix: 'A',
            question_text: 'VA FILE NUMBER'
          },
          'dob' => {
            'month' => {
              key: 'form1[0].#subform[0].DOBMonth[0]',
              limit: 2,
              question_num: 4,
              question_suffix: 'A',
              question_text: 'DATE OF BIRTH'
            },
            'day' => {
              key: 'form1[0].#subform[0].DOBDay[0]',
              limit: 2,
              question_num: 4,
              question_suffix: 'B',
              question_text: 'DATE OF BIRTH'
            },
            'year' => {
              key: 'form1[0].#subform[0].DOBYear[0]',
              limit: 4,
              question_num: 4,
              question_suffix: 'C',
              question_text: 'DATE OF BIRTH'
            }
          }
        }, # end veteran_information
        'veteranAddress' => {
          question_num: 5,
          question_text: 'MAILING ADDRESS',

          'street' => {
            key: 'form1[0].#subform[0].CurrentMailingAddress_NumberAndStreet[0]',
            limit: 30
          },
          'unitNumber' => {
            key: 'form1[0].#subform[0].CurrentMailingAddress_ApartmentOrUnitNumber[0]',
            limit: 5
          },
          'city' => {
            key: 'form1[0].#subform[0].CurrentMailingAddress_City[0]',
            limit: 18
          },
          'state' => {
            key: 'form1[0].#subform[0].CurrentMailingAddress_StateOrProvince[0]',
            limit: 2
          },
          'country' => {
            key: 'form1[0].#subform[0].CurrentMailingAddress_Country[0]',
            limit: 2
          },
          'postalCode' => {
            'firstFive' => {
              key: 'form1[0].#subform[0].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]',
              limit: 5
            },
            'lastFour' => {
              key: 'form1[0].#subform[0].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]',
              limit: 4
            }
          }
        }, # end veteran_address
        'mainPhone' => {
          'phone_area_code' => {
            key: 'form1[0].#subform[0].AreaCode[0]',
            limit: 3,
            question_num: 6,
            question_suffix: 'A',
            question_text: 'MAIN TELEPHONE NUMBER'
          },
          'phone_first_three_numbers' => {
            key: 'form1[0].#subform[0].FirstThreeNumbers[1]',
            limit: 3,
            question_num: 6,
            question_suffix: 'B',
            question_text: 'MAIN TELEPHONE NUMBER'
          },
          'phone_last_four_numbers' => {
            key: 'form1[0].#subform[0].LastFourNumbers[1]',
            limit: 4,
            question_num: 6,
            question_suffix: 'C',
            question_text: 'MAIN TELEPHONE NUMBER'
          }
        },
        'cellPhone' => {
          'phone_area_code' => {
            key: 'form1[0].#subform[0].AreaCode[1]',
            limit: 3,
            question_num: 7,
            question_suffix: 'A',
            question_text: 'CELL PHONE NUMBER'
          },
          'phone_first_three_numbers' => {
            key: 'form1[0].#subform[0].FirstThreeNumbers[2]',
            limit: 3,
            question_num: 7,
            question_suffix: 'B',
            question_text: 'CELL PHONE NUMBER'
          },
          'phone_last_four_numbers' => {
            key: 'form1[0].#subform[0].LastFourNumbers[2]',
            limit: 4,
            question_num: 7,
            question_suffix: 'C',
            question_text: 'CELL PHONE NUMBER'
          }
        },
        'email' => {
          key: 'form1[0].#subform[0].Email_Address[0]',
          limit: 30,
          question_num: 8,
          question_suffix: 'A',
          question_text: 'E-MAIL ADDRESS OF CLAIMANT'
        },
        'newAddress' => {
          question_num: 9,
          question_text: 'IF YOU ARE MOVING WITHIN THE NEXT 30 DAYS, PROVIDE YOUR NEW ADDRESS BELOW.',

          'street' => {
            key: 'form1[0].#subform[0].NewAddress_NumberAndStreet[0]',
            limit: 30,
            question_num: 9,
            question_suffix: 'A'
          },
          'unitNumber' => {
            key: 'form1[0].#subform[0].NewAddress_ApartmentOrUnitNumber[0]',
            limit: 5,
            question_num: 9,
            question_suffix: 'B'
          },
          'city' => {
            key: 'form1[0].#subform[0].NewAddress_City[0]',
            limit: 18,
            question_num: 9,
            question_suffix: 'C'
          },
          'state' => {
            key: 'form1[0].#subform[0].NewAddress_StateOrProvince[0]',
            limit: 2,
            question_num: 9,
            question_suffix: 'D'
          },
          'country' => {
            key: 'form1[0].#subform[0].NewAddress_Country[0]',
            limit: 2,
            question_num: 9,
            question_suffix: 'E'
          },
          'postalCode' => {
            question_num: 9,
            question_suffix: 'F',

            'firstFive' => {
              key: 'form1[0].#subform[0].NewAddress_ZIPOrPostalCode_FirstFiveNumbers[0]',
              limit: 5
            },
            'lastFour' => {
              key: 'form1[0].#subform[0].NewAddress_ZIPOrPostalCode_LastFourNumbers[0]',
              limit: 4
            }
          }
        }, # end new_address
        'yearsOfEducation' => {
          key: 'form1[0].#subform[0].Number_Of_Years_Of_Education[0]',
          limit: 2,
          question_num: 10,
          question_suffix: 'A',
          question_text: 'NUMBER OF YEARS OF EDUCATION'
        },
        'privacyAgreementAccepted' => {
          key: 'form1[0].#subform[1].IfIDontGiveMyInfo[0]'
        },
        'signature' => {
          key: 'form1[0].#subform[1].SignatureField11[0]'
        },
        'signatureDate' => {
          'month' => {
            key: 'form1[0].#subform[1].DateSigned_Month[0]'
          },
          'day' => {
            key: 'form1[0].#subform[1].DateSigned_Day[0]'
          },
          'year' => {
            key: 'form1[0].#subform[1].DateSigned_Year[0]'
          }
        } # end date_signed
      }.freeze

      def merge_fields(_options = {})
        merge_veteran_helpers
        merge_address_helpers

        expand_signature(@form_data['veteranInformation']['fullName'], @form_data['signatureDate'] || Time.zone.today)
        @form_data['signatureDate'] = split_date(@form_data['signatureDate'])
        @form_data['privacyAgreementAccepted'] = select_checkbox(@form_data['privacyAgreementAccepted'])

        @form_data
      end

      def merge_veteran_helpers
        veteran_information = @form_data['veteranInformation']
        # extract middle initial
        veteran_information['fullName'] = extract_middle_i(veteran_information, 'fullName')

        # extract ssn
        ssn = veteran_information['ssn']
        if ssn.present?
          ssn = ssn.delete('-')
          veteran_information['ssn'] = split_ssn(ssn)
          va_file_number = veteran_information['VAFileNumber']

          veteran_information['VAFileNumber'] = '' if ssn == va_file_number
          @form_data['veteranInformation']['VAFileNumber'] = veteran_information['VAFileNumber']
        end

        # extract birth date
        veteran_information['dob'] = split_date(veteran_information['dob'])

        expand_phone_number('mainPhone')
        expand_phone_number('cellPhone')
      end

      def expand_phone_number(phone_type)
        phone_number = @form_data[phone_type] # ie. "main_phone", "cell_phone"
        if phone_number.present?
          phone_number = phone_number.delete('^0-9')
          @form_data[phone_type] = {
            'phone_area_code' => phone_number[0..2],
            'phone_first_three_numbers' => phone_number[3..5],
            'phone_last_four_numbers' => phone_number[6..9]
          }
        end
      end

      def merge_address_helpers
        veteran_address = @form_data.key?('veteranAddress') ? @form_data['veteranAddress'] : {}
        format_address(veteran_address) unless veteran_address.empty?
        format_address(@form_data['newAddress']) if @form_data['isMoving']
      end

      def format_address(address)
        address['country'] = extract_country(address)

        zip_code = split_postal_code(address)
        address['postalCode'] = {
          'firstFive' => zip_code['firstFive'],
          'lastFour' => zip_code['lastFour']
        }
      end
    end
  end
end
