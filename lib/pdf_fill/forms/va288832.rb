# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
module PdfFill
  module Forms
    class Va288832 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'first_name' => {
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
        'last_name' => {
          key: 'F[0].Page_1[0].ClaimantsLastName[0]',
          limit: 18,
          question_num: 1,
          question_suffix: 'C',
          question_text: 'NAME OF CLAIMANT'
        },
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
        },
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
=begin
        'va_file_number' => {
          key: 'F[0].Page_1[0].VAFileNumber[0]',
          limit: 8,
          question_num: 1,
          question_suffix: 'A',
          question_text: 'VA FILE NUMBER'
        },
=end
        # email_address
        # gender
        # relationship
        # telephone number
          # U.S. 10-digit or International 15-digit)

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
        #

# F[0].Page_1[0].International_Number[0]

        'dependent_address' => {
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
        }
=begin
        , # end dependent_address
        'veteran_information' => {
          'full_name' => {
            'first' => {
              key: 'VBA281900[0].#subform[0].VeteransFirstName[0]',
              limit: 12,
              question_num: 1,
              question_suffix: 'A',
              question_text: 'NAME OF CLAIMANT'
            },
            'middleInitial' => {
              key: 'VBA281900[0].#subform[0].VeteransMiddleInitial1[0]',
              limit: 1,
              question_num: 1,
              question_suffix: 'B',
              question_text: 'NAME OF CLAIMANT'
            },
            'last' => {
              key: 'VBA281900[0].#subform[0].VeteransLastName[0]',
              limit: 18,
              question_num: 1,
              question_suffix: 'C',
              question_text: 'NAME OF CLAIMANT'
            }
          }, # end full_name
          'ssn' => {
            'first' => {
              key: 'VBA281900[0].#subform[0].VeteransSocialSecurityNumber_FirstThreeNumbers[0]',
              limit: 3,
              question_num: 2,
              question_suffix: 'A',
              question_text: 'SOCIAL SECURITY NUMBER'
            },
            'second' => {
              key: 'VBA281900[0].#subform[0].VeteransSocialSecurityNumber_SecondTwoNumbers[0]',
              limit: 2,
              question_num: 2,
              question_suffix: 'B',
              question_text: 'SOCIAL SECURITY NUMBER'
            },
            'third' => {
              key: 'VBA281900[0].#subform[0].VeteransSocialSecurityNumber_LastFourNumbers[0]',
              limit: 4,
              question_num: 2,
              question_suffix: 'C',
              question_text: 'SOCIAL SECURITY NUMBER'
            }
          },
          'va_file_number' => {
            key: 'VBA281900[0].#subform[0].VAFileNumber[0]',
            limit: 8,
            question_num: 3,
            question_suffix: 'A',
            question_text: 'VA FILE NUMBER'
          },
          'dob' => {
            'month' => {
              key: 'VBA281900[0].#subform[0].DOBmonth[0]',
              limit: 2,
              question_num: 4,
              question_suffix: 'A',
              question_text: 'DATE OF BIRTH'
            },
            'day' => {
              key: 'VBA281900[0].#subform[0].DOBday[0]',
              limit: 2,
              question_num: 4,
              question_suffix: 'B',
              question_text: 'DATE OF BIRTH'
            },
            'year' => {
              key: 'VBA281900[0].#subform[0].DOByear[0]',
              limit: 4,
              question_num: 4,
              question_suffix: 'C',
              question_text: 'DATE OF BIRTH'
            }
          }
        }, # end veteran_information
        'veteran_address' => {
          'address_line1' => {
            key: '',
            limit: 30,
            question_num: 5,
            question_suffix: 'A',
            question_text: 'MAILING ADDRESS'
          },
          'address_line2' => {
            key: '',
            limit: 5,
            question_num: 5,
            question_suffix: 'B',
            question_text: 'MAILING ADDRESS'
          },
          'city' => {
            key: '',
            limit: 18,
            question_num: 5,
            question_suffix: 'C',
            question_text: 'MAILING ADDRESS'
          },
          'state_code' => {
            key: '',
            limit: 2,
            question_num: 5,
            question_suffix: 'D',
            question_text: 'MAILING ADDRESS'
          },
          'country_name' => {
            key: '',
            limit: 2,
            question_num: 5,
            question_suffix: 'E',
            question_text: 'MAILING ADDRESS'
          },
          'zip_code' => {
            'firstFive' => {
              key: '',
              limit: 5,
              question_num: 5,
              question_suffix: 'F',
              question_text: 'MAILING ADDRESS'
            },
            'lastFour' => {
              key: '',
              limit: 4,
              question_num: 5,
              question_suffix: 'G',
              question_text: 'MAILING ADDRESS'
            }
          } # end zip_code
        }, # end veteran_address
        'phone' => {
          'phone_area_code' => {
            key: 'VBA281900[0].#subform[0].TelephoneNumber_AreaCode[1]',
            limit: 3,
            question_num: 6,
            question_suffix: 'A',
            question_text: 'MAIN TELEPHONE NUMBER'
          },
          'phone_first_three_numbers' => {
            key: 'VBA281900[0].#subform[0].TelephoneNumber_FirstThreeNumbers[1]',
            limit: 3,
            question_num: 6,
            question_suffix: 'B',
            question_text: 'MAIN TELEPHONE NUMBER'
          },
          'phone_last_four_numbers' => {
            key: 'VBA281900[0].#subform[0].TelephoneNumber_LastFourNumbers[1]',
            limit: 4,
            question_num: 6,
            question_suffix: 'C',
            question_text: 'MAIN TELEPHONE NUMBER'
          }
        },
        'email_address' => {
          key: 'VBA281900[0].#subform[0].EmailAddress[0]',
          limit: 30,
          question_num: 7,
          question_suffix: 'A',
          question_text: 'E-MAIL ADDRESS OF CLAIMANT'
        },
=end

        # "status"=>"isSpouse"
        # @TODO
        # 11A. SIGNATURE OF CLAIMANT
        # 11B. DATE SIGNED (MM-DD-YYYY)
      }.freeze


    # {
    #   "education_career_counseling_claim"=>
    #   {
    #     "veteran_address"=>
    #     {
    #       "country_name"=>"USA", "address_line1"=>"111 Baker St", "city"=>"Baltimore", "state_code"=>"MD", "zip_code"=>"26042"
    #     },
    #     "phone"=>"5558675309",
    #     "email_address"=>"vet228@test.com",
    #     "veteran_information"=>
    #     {
    #       "full_name"=>
    #       {
    #         "first"=>"Mark", "last"=>"Webb"
    #       }
    #     },
    #     "dependent_address"=>
    #     {
    #       "country_name"=>"USA", "address_line1"=>"111 Baker St", "city"=>"Baltimore", "state_code"=>"MD", "zip_code"=>"26042"
    #     },
    #     "phone_number"=>"5558675309",
    #     "first_name"=>"Michelle",
    #     "last_name"=>"Davis",
    #     "ssn"=>"333224444",
    #     "date_of_birth"=>"1999-01-01",
    #     "status"=>"isSpouse"
    #   }
    # }



# F[0].Page_1[0].RadioButtonList[0]
# F[0].Page_1[0].RadioButtonList[1]
# F[0].Page_1[0].RadioButtonList[2]
# F[0].Page_1[0].RadioButtonList[3]
# F[0].Page_1[0].RadioButtonList[4]
# F[0].Page_1[0].RadioButtonList[5]
# F[0].Page_1[0].RadioButtonList[6]

#
#
# F[0].Page_1[0].Email_Address[0]


# F[0].Page_1[0].ClaimantsLastName[1]
# F[0].Page_1[0].ClaimantsMiddleInitial[1]
# F[0].Page_1[0].ClaimantsFirstName[1]
# F[0].Page_1[0].VeteransSocialSecurityNumber_LastFourNumbers[0]
# F[0].Page_1[0].VeteransSocialSecurityNumber_SecondTwoNumbers[0]
# F[0].Page_1[0].VeteransSocialSecurityNumber_FirstThreeNumbers[0]
# F[0].Page_1[0].DOByear[1]
# F[0].Page_1[0].DOBday[1]
# F[0].Page_1[0].DOBmonth[1]
# F[0].Page_1[0].VETERANS_VAFileNumber[0]
# F[0].Page_1[0].VAFileNumber[1]
# F[0].Page_1[0].VAFileNumber[2]
# F[0].Page_1[0].DOByear[2]
# F[0].Page_1[0].DOBday[2]
# F[0].Page_1[0].DOBmonth[2]
# F[0].Page_1[0].Age[0]
# F[0].Page_2[0].Date_Active_Duty_1[0]
# F[0].Page_2[0].Date_Active_Duty_2[0]
# F[0].Page_2[0].Date_Active_Duty_3[0]
# F[0].Page_2[0].Date_Active_Duty_4[0]
# F[0].Page_2[0].Date_Active_Duty_5[0]
# F[0].Page_2[0].Date_Separated_5[0]
# F[0].Page_2[0].Date_Separated_4[0]
# F[0].Page_2[0].Date_Separated_3[0]
# F[0].Page_2[0].Date_Separated_2[0]
# F[0].Page_2[0].Date_Separated_1[0]
# F[0].Page_2[0].Branch_Of_Service_1[0]
# F[0].Page_2[0].Branch_Of_Service_2[0]
# F[0].Page_2[0].Branch_Of_Service_3[0]
# F[0].Page_2[0].Branch_Of_Service_4[0]
# F[0].Page_2[0].Branch_Of_Service_5[0]
# F[0].Page_2[0].Character_Of_Discharge_1[0]
# F[0].Page_2[0].Character_Of_Discharge_2[0]
# F[0].Page_2[0].Character_Of_Discharge_3[0]
# F[0].Page_2[0].Character_Of_Discharge_4[0]
# F[0].Page_2[0].Character_Of_Discharge_5[0]
# F[0].Page_2[0].RadioButtonList[0]
# F[0].Page_2[0].RadioButtonList[1]
# F[0].Page_2[0].Digital_Signature[0]
# F[0].Page_2[0].Digital_Signature[1]
# F[0].Page_2[0].DOByear[0]
# F[0].Page_2[0].DOBday[0]
# F[0].Page_2[0].DOBmonth[0]
# F[0].Page_2[0].ClaimantsLastName[0]
# F[0].Page_2[0].ClaimantsMiddleInitial[0]
# F[0].Page_2[0].ClaimantsFirstName[0]
# F[0].Page_2[0].OTHER_Specify[0]
# F[0].Page_2[0].OTHER_Specify[1]
# F[0].Page_2[0].Name_Of_Veteran[0]
# F[0].Page_2[0].VAFileNumber[0]
# F[0].Page_2[0].Remarks[0]
# F[0].Page_2[0].DateSignedYYYY[0]
# F[0].Page_2[0].DateSignedDD[0]
# F[0].Page_2[0].DateSignedMM[0]
# F[0].Page_2[0].DateSignedYYYY[1]
# F[0].Page_2[0].DateSignedDD[1]
# F[0].Page_2[0].DateSignedMM[1]
# F[0].Page_2[0].TelephoneNumber_LastFourNumbers[0]
# F[0].Page_2[0].TelephoneNumber_FirstThreeNumbers[0]
# F[0].Page_2[0].TelephoneNumber_AreaCode[0]
# F[0].Page_2[0].VeteransSocialSecurityNumber_LastFourNumbers[0]
# F[0].Page_2[0].VeteransSocialSecurityNumber_SecondTwoNumbers[0]
# F[0].Page_2[0].VeteransSocialSecurityNumber_FirstThreeNumbers[0]
# F[0].Page_2[0].RadioButtonList[2]
# F[0]

      def merge_fields
        merge_claimant_helpers
        #merge_veteran_helpers

        @form_data
      end

      def merge_claimant_helpers
        # extract ssn
        ssn = @form_data['ssn']
        @form_data['ssn'] = split_ssn(ssn.delete('-')) if ssn.present?

        # extract birth date
        @form_data['date_of_birth'] = split_date(@form_data['date_of_birth'])

        # extract phone_number
        expand_phone_number('phone_number')

        # extract postal code and country
        @form_data['dependent_address']['zip_code'] =
          split_postal_code(@form_data['dependent_address'])
        @form_data['dependent_address']['country_name'] =
          extract_country(@form_data['dependent_address'])
      end

      def merge_veteran_helpers
        veteran_information = @form_data['veteran_information']

        # extract ssn
        ssn = veteran_information['ssn']
        veteran_information['ssn'] = split_ssn(ssn.delete('-')) if ssn.present?

        # extract birth date
        veteran_information['dob'] = split_date(veteran_information['dob'])

        expand_phone_number('main_phone')
        expand_phone_number('cell_phone')
      end

      def expand_phone_number(phone_type)
        phone_number = @form_data[phone_type]
        if phone_number.present?
          phone_number = phone_number.delete('^0-9')
          @form_data[phone_type] = {
            'phone_area_code' => phone_number[0..2],
            'phone_first_three_numbers' => phone_number[3..5],
            'phone_last_four_numbers' => phone_number[6..9]
          }
        end
      end
    end
  end
end
