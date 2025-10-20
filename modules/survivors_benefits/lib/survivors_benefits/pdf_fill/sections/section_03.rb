# frozen_string_literal: true

require 'survivors_benefits/pdf_fill/section'

module SurvivorsBenefits
  module PdfFill
    # Section 3: Veteran's Service Information
    class Section3 < Section
      include ::PdfFill::Forms::FormHelper
      include ::PdfFill::Forms::FormHelper::PhoneNumberFormatting
      include Helpers

      # The Index Iterator Key
      ITERATOR = ::PdfFill::HashConverter::ITERATOR

      SERVICE_BRANCH_MAPPING = {
        'army' => 'ARMY',
        'navy' => 'NAVY',
        'airForce' => 'AIR FORCE',
        'coastGuard' => 'COAST GUARD',
        'marineCorps' => 'MARINE CORPS',
        'spaceForce' => 'SPACE FORCE',
        'usphs' => 'USPHS',
        'noaa' => 'NOAA'
      }.freeze

      # Section configuration hash
      KEY = {
        'p11HeaderVeteranSocialSecurityNumber' => {
          'first' => {
            key: 'form1[0].#subform[208].VeteransSocialSecurityNumber_FirstThreeNumbers[1]'
          },
          'second' => {
            key: 'form1[0].#subform[208].VeteransSocialSecurityNumber_SecondTwoNumbers[1]'
          },
          'third' => {
            key: 'form1[0].#subform[208].VeteransSocialSecurityNumber_LastFourNumbers[1]'
          }
        },
        'veteranHasPreviousNames' => {
          key: 'form1[0].#subform[207].RadioButtonList[4]'
        },
        'veteranPreviousNames' => {
          limit: 2,
          first_key: 'first',
          'first' => {
            limit: 12,
            key: "form1[0].#subform[207].First_Name[#{ITERATOR}]"
          },
          'middle' => {
            limit: 1,
            key: "form1[0].#subform[207].Middle_Initial[#{ITERATOR}]"
          },
          'last' => {
            limit: 18,
            key: "form1[0].#subform[207].Last_Name[#{ITERATOR}]"
          }
        },
        'activeServiceDateRange' => {
          'from' => {
            'month' => {
              key: 'form1[0].#subform[208].Date_Veteran_Entered_Active_Duty_Month[0]'
            },
            'day' => {
              key: 'form1[0].#subform[208].Date_Veteran_Entered_Active_Duty_Day[0]'
            },
            'year' => {
              key: 'form1[0].#subform[208].Date_Veteran_Entered_Active_Duty_Year[0]'
            }
          },
          'to' => {
            'month' => {
              key: 'form1[0].#subform[208].Date_Veteran_Released_From_Active_Duty_Month[0]'
            },
            'day' => {
              key: 'form1[0].#subform[208].Date_Veteran_Released_From_Active_Duty_Day[0]'
            },
            'year' => {
              key: 'form1[0].#subform[208].Date_Veteran_Released_From_Active_Duty_Year[0]'
            }
          }
        },
        'serviceBranch' => {
          key: 'form1[0].#subform[208].RadioButtonList[16]'
        },
        'placeOfSeparation' => {
          key: 'form1[0].#subform[208].Place_Of_Last_Separation[0]'
        },
        'nationalGuardActivated' => {
          key: 'form1[0].#subform[208].RadioButtonList[5]'
        },
        'nationalGuardActivationDate' => {
          'month' => {
            key: 'form1[0].#subform[208].Date_Of_Activation_Month[0]'
          },
          'day' => {
            key: 'form1[0].#subform[208].Date_Of_Activation_Day[0]'
          },
          'year' => {
            key: 'form1[0].#subform[208].Date_Of_Activation_Year[0]'
          }
        },
        'unitNameAndAddress' => {
          'line_one' => {
            limit: 20,
            key: 'form1[0].#subform[208].Name_And_Address_Of_Veterans_Reserve_National_Guard_Unit[0]'
          },
          'line_two' => {
            limit: 20,
            key: 'form1[0].#subform[208].Name_And_Address_Of_Veterans_Reserve_National_Guard_Unit[1]'
          },
          'line_three' => {
            limit: 20,
            key: 'form1[0].#subform[208].Name_And_Address_Of_Veterans_Reserve_National_Guard_Unit[2]'
          }
        },
        'unitPhone' => {
          'phone_area_code' => {
            key: 'form1[0].#subform[208].Telephone_Number_Area_Code[0]'
          },
          'phone_first_three_numbers' => {
            key: 'form1[0].#subform[208].Telephone_Middle_Three_Numbers[0]'
          },
          'phone_last_four_numbers' => {
            key: 'form1[0].#subform[208].Telephone_Last_Four_Numbers[0]'
          }
        },
        'pow' => {
          key: 'form1[0].#subform[208].RadioButtonList[6]'
        },
        'powDateRange' => {
          'from' => {
            'month' => {
              key: 'form1[0].#subform[208].Date_Of_Confinement_Start_Month[0]'
            },
            'day' => {
              key: 'form1[0].#subform[208].Date_Of_Confinement_Day[0]'
            },
            'year' => {
              key: 'form1[0].#subform[208].Date_Of_Confinement_Year[0]'
            }
          },
          'to' => {
            'month' => {
              key: 'form1[0].#subform[208].Date_Of_Confinement_End_Month[0]'
            },
            'day' => {
              key: 'form1[0].#subform[208].Date_Of_Confinement_Day[1]'
            },
            'year' => {
              key: 'form1[0].#subform[208].Date_Of_Confinement_Year[1]'
            }
          }
        }
      }.freeze

      def expand(form_data = {})
        form_data['p11HeaderVeteranSocialSecurityNumber'] = split_ssn(form_data['veteranSocialSecurityNumber'])
        form_data['veteranPreviousNames'] ||= []
        form_data['veteranHasPreviousNames'] = to_radio_yes_no(form_data['veteranPreviousNames'].length.positive?)
        form_data['activeServiceDateRange'] = {
          'from' => split_date(form_data.dig('activeServiceDateRange', 'from')),
          'to' => split_date(form_data.dig('activeServiceDateRange', 'to'))
        }
        form_data['serviceBranch'] = service_to_radio(form_data['serviceBranch'])
        form_data['nationalGuardActivated'] = to_radio_yes_no(form_data['nationalGuardActivated'])
        form_data['nationalGuardActivationDate'] = split_date(form_data['nationalGuardActivationDate'])
        form_data['unitNameAndAddress'] = split_unit_into_lines(form_data['unitNameAndAddress'])
        form_data['unitPhone'] = expand_phone_number(form_data['unitPhone'])
        form_data['pow'] = to_radio_yes_no(form_data['pow'])
        form_data['powDateRange'] = {
          'from' => split_date(form_data.dig('powDateRange', 'from')),
          'to' => split_date(form_data.dig('powDateRange', 'to'))
        }
        form_data
      end

      def to_radio_yes_no(obj)
        case obj
        when true then 'YES'
        when false then 'NO'
        else 'OFF'
        end
      end

      def service_to_radio(service)
        if SERVICE_BRANCH_MAPPING.keys.include?(service)
          SERVICE_BRANCH_MAPPING[service]
        else
          'OFF'
        end
      end

      def split_unit_into_lines(unit_name_and_address)
        unit_name_and_address ||= ''
        parts = unit_name_and_address.scan(/.{1,20}/)
        {
          'line_one' => parts[0],
          'line_two' => parts[1],
          'line_three' => parts[2]
        }
      end
    end
  end
end
