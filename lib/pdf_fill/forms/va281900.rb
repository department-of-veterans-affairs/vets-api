# frozen_string_literal: true

module PdfFill
  module Forms
    class Va281900 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
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
          'birth_date' => {
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
            key: 'VBA281900[0].#subform[0].Address1[1]',
            limit: 30,
            question_num: 5,
            question_suffix: 'A',
            question_text: 'MAILING ADDRESS'
          },
          'address_line2' => {
            key: 'VBA281900[0].#subform[0].Address2[1]',
            limit: 30,
            question_num: 5,
            question_suffix: 'B',
            question_text: 'MAILING ADDRESS'
          },
          'address_line3' => {
            key: 'VBA281900[0].#subform[0].Address3[1]',
            limit: 30,
            question_num: 5,
            question_suffix: 'C',
            question_text: 'MAILING ADDRESS'
          }
        }, # end veteran_address
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
        'email' => {
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
        'new_address' => {
          'address_line1' => {
            key: 'VBA281900[0].#subform[0].Address1[0]',
            limit: 30,
            question_num: 9,
            question_suffix: 'A',
            question_text: 'NEW ADDRESS IF MOVING WITHIN THE NEXT 30 DAYS'
          },
          'address_line2' => {
            key: 'VBA281900[0].#subform[0].Address2[0]',
            limit: 30,
            question_num: 9,
            question_suffix: 'B',
            question_text: 'NEW ADDRESS IF MOVING WITHIN THE NEXT 30 DAYS'
          },
          'address_line3' => {
            key: 'VBA281900[0].#subform[0].Address3[0]',
            limit: 30,
            question_num: 9,
            question_suffix: 'C',
            question_text: 'NEW ADDRESS IF MOVING WITHIN THE NEXT 30 DAYS'
          }
        }, # end new_address
        'years_of_education' => {
          key: 'VBA281900[0].#subform[0].EducationYR[0]',
          limit: 2,
          question_num: 10,
          question_suffix: 'A',
          question_text: 'NUMBER OF YEARS OF EDUCATION'
        },
        'signature' => {
          key: 'signature'
        },
        'date_signed' => {
          'month' => {
            key: 'VBA281900[0].#subform[0].DOBmonth[1]'
          },
          'day' => {
            key: 'VBA281900[0].#subform[0].DOBday[1]'
          },
          'year' => {
            key: 'VBA281900[0].#subform[0].DOByear[1]'
          }
        }, # end date_signed
        'use_eva' => {
          key: 'useEva'
        },
        'use_telecounseling' => {
          key: 'useTelecounseling'
        },
        'appointment_time_preferences' => {
          key: 'appointmentTimePreferences'
        }
      }.freeze

      def merge_fields(_options = {})
        merge_veteran_helpers
        merge_address_helpers
        merge_preferences_helpers

        expand_signature(@form_data['veteran_information']['full_name'])
        @form_data['date_signed'] = split_date(@form_data['signatureDate'])

        @form_data
      end

      def merge_veteran_helpers
        veteran_information = @form_data['veteran_information']

        # extract middle initial
        veteran_information['full_name'] = extract_middle_i(veteran_information, 'full_name')

        # extract ssn
        ssn = veteran_information['ssn']
        if ssn.present?
          ssn = ssn.delete('-')
          veteran_information['ssn'] = split_ssn(ssn)
          va_file_number = veteran_information['va_file_number']
          veteran_information['va_file_number'] = '' if ssn == va_file_number
        end

        # extract birth date
        veteran_information['birth_date'] = split_date(veteran_information['birth_date'])

        expand_phone_number('main_phone')
        expand_phone_number('cell_phone')
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
        format_address(@form_data['veteran_address'])
        format_address(@form_data['new_address']) if @form_data['is_moving']
      end

      def format_address(address)
        street2 = address['street2'] || ''
        street3 = address['street3'] || ''
        state = address['state'] || ''

        address['address_line1'] = address['street'] + ' ' + street2 + ' ' + street3
        address['address_line2'] = address['city'] + ' ' + state + ' ' + address['postal_code']
        address['address_line3'] = address['country']
      end

      def merge_preferences_helpers
        @form_data['use_eva'] = @form_data['use_eva'] ? 'Yes' : 'No'
        @form_data['use_telecounseling'] = @form_data['use_telecounseling'] ? 'Yes' : 'No'
        @form_data['appointment_time_preferences'] = set_appointment_time_preferences
      end

      def set_appointment_time_preferences
        times = @form_data['appointment_time_preferences'] # ex. {'morning'=>true, 'mid_day'=>false, 'afternoon'=>false}
        counseling_hours = {
          'morning' => "Mornings 6:00 to 10:00 a.m.\n",
          'mid_day' => "Midday 10:00 a.m. to 2:00 p.m.\n",
          'afternoon' => "Afternoons 2:00 to 6:00 p.m.\n"
        }
        time_preferences = ''
        times.each do |time, does_prefer|
          time_preferences += counseling_hours[time] if does_prefer
        end
        time_preferences
      end
    end
  end
end
