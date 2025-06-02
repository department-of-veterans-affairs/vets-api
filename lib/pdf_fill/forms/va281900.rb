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
              key: 'VBA281900[0].#subform[0].Claimants_First_Name[0]',
              limit: 12,
              question_num: 1,
              question_suffix: 'A',
              question_text: 'NAME OF CLAIMANT'
            },
            'middleInitial' => {
              key: 'VBA281900[0].#subform[0].Middle_Initial1[0]',
              limit: 1,
              question_num: 1,
              question_suffix: 'B',
              question_text: 'NAME OF CLAIMANT'
            },
            'last' => {
              key: 'VBA281900[0].#subform[0].Last_Name[0]',
              limit: 18,
              question_num: 1,
              question_suffix: 'C',
              question_text: 'NAME OF CLAIMANT'
            }
          }, # end fullName
          'ssn' => {
            'first' => {
              key: 'VBA281900[0].#subform[0].SocialSecurityNumber_FirstThreeNumbers[0]',
              limit: 3,
              question_num: 2,
              question_suffix: 'A',
              question_text: 'SOCIAL SECURITY NUMBER'
            },
            'second' => {
              key: 'VBA281900[0].#subform[0].SocialSecurityNumber_SecondTwoNumbers[0]',
              limit: 2,
              question_num: 2,
              question_suffix: 'B',
              question_text: 'SOCIAL SECURITY NUMBER'
            },
            'third' => {
              key: 'VBA281900[0].#subform[0].SocialSecurityNumber_LastFourNumbers[0]',
              limit: 4,
              question_num: 2,
              question_suffix: 'C',
              question_text: 'SOCIAL SECURITY NUMBER'
            }
          },
          'VAFileNumber' => {
            key: 'VBA281900[0].#subform[0].VA_File_Number[0]',
            limit: 9,
            question_num: 3,
            question_suffix: 'A',
            question_text: 'VA FILE NUMBER'
          },
          'dob' => {
            'month' => {
              key: 'VBA281900[0].#subform[0].DOB_Month[0]',
              limit: 2,
              question_num: 4,
              question_suffix: 'A',
              question_text: 'DATE OF BIRTH'
            },
            'day' => {
              key: 'VBA281900[0].#subform[0].DOB_Day[0]',
              limit: 2,
              question_num: 4,
              question_suffix: 'B',
              question_text: 'DATE OF BIRTH'
            },
            'year' => {
              key: 'VBA281900[0].#subform[0].DOB_Year[0]',
              limit: 4,
              question_num: 4,
              question_suffix: 'C',
              question_text: 'DATE OF BIRTH'
            }
          }
        }, # end veteran_information
        'veteranAddress' => {
          'addressLine1' => {
            key: 'VBA281900[0].#subform[0].Mailing_Address1[0]',
            limit: 30,
            question_num: 5,
            question_suffix: 'A',
            question_text: 'MAILING ADDRESS'
          },
          'addressLine2' => {
            key: 'VBA281900[0].#subform[0].Mailing_Address1[1]',
            limit: 30,
            question_num: 5,
            question_suffix: 'B',
            question_text: 'MAILING ADDRESS'
          },
          'addressLine3' => {
            key: 'VBA281900[0].#subform[0].Mailing_Address1[2]',
            limit: 30,
            question_num: 5,
            question_suffix: 'C',
            question_text: 'MAILING ADDRESS'
          }
        }, # end veteran_address
        'mainPhone' => {
          'phone_area_code' => {
            key: 'VBA281900[0].#subform[0].TelephoneNumber_AreaCode[0]',
            limit: 3,
            question_num: 6,
            question_suffix: 'A',
            question_text: 'MAIN TELEPHONE NUMBER'
          },
          'phone_first_three_numbers' => {
            key: 'VBA281900[0].#subform[0].TelephoneNumber_FirstThreeNumbers[0]',
            limit: 3,
            question_num: 6,
            question_suffix: 'B',
            question_text: 'MAIN TELEPHONE NUMBER'
          },
          'phone_last_four_numbers' => {
            key: 'VBA281900[0].#subform[0].TelephoneNumber_LastFourNumbers[0]',
            limit: 4,
            question_num: 6,
            question_suffix: 'C',
            question_text: 'MAIN TELEPHONE NUMBER'
          }
        },
        'email' => {
          key: 'VBA281900[0].#subform[0].Email_Address[0]',
          limit: 30,
          question_num: 7,
          question_suffix: 'A',
          question_text: 'E-MAIL ADDRESS OF CLAIMANT'
        },
        'cellPhone' => {
          'phone_area_code' => {
            key: 'VBA281900[0].#subform[0].Cell_Phone_Number_AreaCode[0]',
            limit: 3,
            question_num: 8,
            question_suffix: 'A',
            question_text: 'CELL PHONE NUMBER'
          },
          'phone_first_three_numbers' => {
            key: 'VBA281900[0].#subform[0].Cell_Phone_Number_FirstThreeNumbers[0]',
            limit: 3,
            question_num: 8,
            question_suffix: 'B',
            question_text: 'CELL PHONE NUMBER'
          },
          'phone_last_four_numbers' => {
            key: 'VBA281900[0].#subform[0].Cell_PhoneNumber_LastFourNumbers[0]',
            limit: 4,
            question_num: 8,
            question_suffix: 'C',
            question_text: 'CELL PHONE NUMBER'
          }
        },
        'newAddress' => {
          'addressLine1' => {
            key: 'VBA281900[0].#subform[0].Address1[0]',
            limit: 30,
            question_num: 9,
            question_suffix: 'A',
            question_text: 'NEW ADDRESS IF MOVING WITHIN THE NEXT 30 DAYS'
          },
          'addressLine2' => {
            key: 'VBA281900[0].#subform[0].Address1[1]',
            limit: 30,
            question_num: 9,
            question_suffix: 'B',
            question_text: 'NEW ADDRESS IF MOVING WITHIN THE NEXT 30 DAYS'
          },
          'addressLine3' => {
            key: 'VBA281900[0].#subform[0].Address1[2]',
            limit: 30,
            question_num: 9,
            question_suffix: 'C',
            question_text: 'NEW ADDRESS IF MOVING WITHIN THE NEXT 30 DAYS'
          }
        }, # end new_address
        'yearsOfEducation' => {
          key: 'VBA281900[0].#subform[0].Number_Of_Years_Of_Education[0]',
          limit: 2,
          question_num: 10,
          question_suffix: 'A',
          question_text: 'NUMBER OF YEARS OF EDUCATION'
        },
        'signature' => {
          key: 'SignatureField'
        },
        'date_signed' => {
          'month' => {
            key: 'VBA281900[0].#subform[0].Date_Signed_Month[0]'
          },
          'day' => {
            key: 'VBA281900[0].#subform[0].Date_Signed_Day[0]'
          },
          'year' => {
            key: 'VBA281900[0].#subform[0].Date_Signed_Year[0]'
          }
        }, # end date_signed
        'useEva' => {
          key: 'useEva'
        },
        'useTelecounseling' => {
          key: 'useTelecounseling'
        },
        'appointmentTimePreferences' => {
          key: 'appointmentTimePreferences'
        }
      }.freeze

      def merge_fields(options = {})
        merge_veteran_helpers
        merge_address_helpers
        merge_preferences_helpers if @form_data['useEva'].present?

        created_at = options[:created_at] if options[:created_at].present?
        expand_signature(@form_data['veteranInformation']['fullName'], created_at&.to_date || Time.zone.today)
        @form_data['date_signed'] = split_date(@form_data['signatureDate'])

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
        format_address(@form_data['veteranAddress'])
        format_address(@form_data['newAddress']) if @form_data['isMoving']
      end

      def format_address(address)
        street2 = address['street2'] || ''
        street3 = address['street3'] || ''
        state = address['state'] || ''

        address['addressLine1'] = "#{address['street']} #{street2} #{street3}"
        address['addressLine2'] = "#{address['city']} #{state} #{address['postalCode']}"
        address['addressLine3'] = address['country']
      end

      def merge_preferences_helpers
        @form_data['useEva'] = @form_data['useEva'] ? 'Yes' : 'No'
        @form_data['useTelecounseling'] = @form_data['useTelecounseling'] ? 'Yes' : 'No'
        @form_data['appointmentTimePreferences'] = set_appointment_time_preferences
      end

      def set_appointment_time_preferences
        times = @form_data['appointmentTimePreferences'] # ex. {'morning'=>true, 'mid_day'=>false, 'afternoon'=>false}
        counseling_hours = {
          'morning' => "Mornings 6:00 to 10:00 a.m.\n",
          'midday' => "Midday 10:00 a.m. to 2:00 p.m.\n",
          'afternoon' => "Afternoons 2:00 to 6:00 p.m.\n"
        }

        times.map { |time| counseling_hours[time] }.join
      end
    end
  end
end
