# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
module PdfFill
  module Forms
    class Vba281900 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
=begin
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
=end
=begin
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
=end
=begin
        'main_phone' => {
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
        'cell_phone' => {
          'phone_area_code' => {
            key: 'VBA281900[0].#subform[0].TelephoneNumber_AreaCode[0]',
            limit: 3,
            question_num: 8,
            question_suffix: 'A',
            question_text: 'CELL PHONE NUMBER'
          },
          'phone_first_three_numbers' => {
            key: 'VBA281900[0].#subform[0].TelephoneNumber_FirstThreeNumbers[0]',
            limit: 3,
            question_num: 8,
            question_suffix: 'B',
            question_text: 'CELL PHONE NUMBER'
          },
          'phone_last_four_numbers' => {
            key: 'VBA281900[0].#subform[0].TelephoneNumber_LastFourNumbers[0]',
            limit: 4,
            question_num: 8,
            question_suffix: 'C',
            question_text: 'CELL PHONE NUMBER'
          }
        },
=end
=begin
        'new_address' => {
          'address_line1' => {
            key: '',
            limit: 30,
            question_num: 9,
            question_suffix: 'A',
            question_text: 'NEW ADDRESS IF MOVING WITHIN THE NEXT 30 DAYS'
          },
          'address_line2' => {
            key: '',
            limit: 5,
            question_num: 9,
            question_suffix: 'B',
            question_text: 'NEW ADDRESS IF MOVING WITHIN THE NEXT 30 DAYS'
          },
          'city' => {
            key: '',
            limit: 18,
            question_num: 9,
            question_suffix: 'C',
            question_text: 'NEW ADDRESS IF MOVING WITHIN THE NEXT 30 DAYS'
          },
          'state_code' => {
            key: '',
            limit: 2,
            question_num: 9,
            question_suffix: 'D',
            question_text: 'NEW ADDRESS IF MOVING WITHIN THE NEXT 30 DAYS'
          },
          'country_name' => {
            key: '',
            limit: 2,
            question_num: 9,
            question_suffix: 'E',
            question_text: 'NEW ADDRESS IF MOVING WITHIN THE NEXT 30 DAYS'
          },
          'zip_code' => {
            'firstFive' => {
              key: '',
              limit: 5,
              question_num: 9,
              question_suffix: 'F',
              question_text: 'NEW ADDRESS IF MOVING WITHIN THE NEXT 30 DAYS'
            },
            'lastFour' => {
              key: '',
              limit: 4,
              question_num: 9,
              question_suffix: 'G',
              question_text: 'NEW ADDRESS IF MOVING WITHIN THE NEXT 30 DAYS'
            }
          } # end zip_code
        }, # end new_address
=end
        # @TODO REMOVE ME
        # "is_moving" => true,
=begin
        'education_level' => {
          key: 'VBA281900[0].#subform[0].EducationYR[0]',
          limit: 2,
          question_num: 10,
          question_suffix: 'A',
          question_text: 'NUMBER OF YEARS OF EDUCATION'
        }
=end
        # @TODO
        # 11A. SIGNATURE OF CLAIMANT
        # 11B. DATE SIGNED (MM-DD-YYYY)
      }.freeze

    # {
    #   "vocational_readiness_employment_form" => {
    #     "education_level" => "BACHELORS",
    #     "is_moving" => true,
    #     "new_address" => {
    #       "country_name" => "USA", "address_line1" => "9417 Princess Palm", "city" => "Tampa", "state_code" => "FL", "zip_code" => "33928"
    #     },
    #     "veteran_address" => {
    #       "country_name" => "USA", "address_line1" => "9417 Princess Palm", "city" => "Tampa", "state_code" => "FL", "zip_code" => "33928"
    #     },
    #     "main_phone" => "5555555555",
    #     "email_address" => "cohnjesse@gmail.xom",
    #     "veteran_information" => {
    #       "full_name" => {
    #         "first" => "JERRY", "middle" => "M", "last" => "BROOKS"
    #       }, "dob" => "1947-09-25"
    #     }
    #   }
    # }
      def merge_fields
        # merge_veteran_helpers

        @form_data
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
