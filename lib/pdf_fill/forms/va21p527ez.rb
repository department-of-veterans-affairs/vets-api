# frozen_string_literal: true

require 'pdf_fill/hash_converter'
require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'string_helpers'

# rubocop:disable Metrics/ClassLength
module PdfFill
  module Forms
    class Va21p527ez < FormBase
      include FormHelper
      include FormHelper::PhoneNumberFormatting
      KEY = {
        # 1a
        'veteranFullName' => {
          'first' => {
            limit: 12,
            question_num: 1,
            question_suffix: 'A',
            question_text: 'VETERAN\'S FIRST NAME',
            key: 'form1[0].#subform[48].VeteransFirstName[0]'
          },
          'middle' => {
            key: 'form1[0].#subform[48].VeteransMiddleInitial1[0]'
          },
          'last' => {
            limit: 18,
            question_num: 1,
            question_suffix: 'A',
            question_text: 'VETERAN\'S LAST NAME',
            key: 'form1[0].#subform[48].VeteransLastName[0]'
          }
        },
        # 1b
        'veteranSocialSecurityNumber' => {
          'first' => {
            key: 'form1[0].#subform[48].VeteransSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'form1[0].#subform[48].VeteransSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[48].VeteransSocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        # 1c
        'veteranDateOfBirth' => {
          'month' => {
            key: 'form1[0].#subform[48].DOBmonth[0]'
          },
          'day' => {
            key: 'form1[0].#subform[48].DOBday[0]'
          },
          'year' => {
            key: 'form1[0].#subform[48].DOByear[0]'
          }
        },
        # 1d
        'vaPreviouslyFiled' => {
          key: 'form1[0].#subform[48].RadioButtonList[0]'
        },
        # 1e
        'vaFileNumber' => {
          key: 'form1[0].#subform[48].VAFileNumber[0]'
        },
        # 2a
        'veteranAddress' => {
          'street' => {
            limit: 30,
            question_num: 2,
            question_suffix: 'A',
            question_text: 'MAILING ADDRESS NUMBER AND STREET',
            key: 'form1[0].#subform[48].NumberStreet[0]'
          },
          'street2' => {
            limit: 5,
            question_num: 2,
            question_suffix: 'A',
            question_text: 'MAILING ADDRESS APT/UNIT',
            key: 'form1[0].#subform[48].Apt_Or_Unit_Number[0]'
          },
          'city' => {
            limit: 18,
            question_num: 2,
            question_suffix: 'A',
            question_text: 'MAILING ADDRESS CITY',
            key: 'form1[0].#subform[48].City[0]'
          },
          'state' => {
            key: 'form1[0].#subform[48].State[0]'
          },
          'country' => {
            key: 'form1[0].#subform[48].Country[0]'
          },
          'postalCode' => {
            'firstFive' => {
              key: 'form1[0].#subform[48].Zip_Postal_Code[0]'
            },
            'lastFour' => {
              key: 'form1[0].#subform[48].Zip_Postal_Code[1]'
            }
          }
        },
        # 2b
        'mobilePhone' => {
          'phone_area_code' => {
            key: 'form1[0].#subform[48].Telephone_Number_First_Three_Numbers[0]'
          },
          'phone_first_three_numbers' => {
            key: 'form1[0].#subform[48].Telephone_Number_Second_Three_Numbers[0]'
          },
          'phone_last_four_numbers' => {
            key: 'form1[0].#subform[48].Telephone_Number_Last_Four_Numbers[0]'
          }
        },
        'internationalPhone' => {
          limit: 30,
          question_num: 2,
          question_suffix: 'C',
          question_text: 'International Phone Number',
          key: 'form1[0].#subform[48].International_Phone_Number[0]'
        },
        # 2c
        'email' => {
          limit: 32,
          question_num: 2,
          question_suffix: 'C',
          question_text: 'VETERAN\'S E-MAIL ADDRESS',
          key: 'form1[0].#subform[48].Veterans_Email_Address_Optional[0]'
        },
        # 3a
        'previousNames' => {
          limit: 1,
          first_key: 'first',
          'first' => {
            limit: 12,
            question_num: 3,
            question_suffix: 'A',
            question_text: 'OTHER FIRST NAME',
            key: 'form1[0].#subform[48].Other_Name_You_Served_Under_First_Name[0]'
          },
          'last' => {
            limit: 18,
            question_num: 3,
            question_suffix: 'A',
            question_text: 'OTHER LAST NAME',
            key: 'form1[0].#subform[48].Other_Name_You_Served_Under_Last_Name[0]'
          }
        },
        # 3b
        'activeServiceDateRange' => {
          'from' => {
            'month' => {
              key: 'form1[0].#subform[48].Date_Entered_Active_Duty_Month[0]'
            },
            'day' => {
              key: 'form1[0].#subform[48].Date_Entered_Active_Duty_Day[0]'
            },
            'year' => {
              key: 'form1[0].#subform[48].Date_Entered_Active_Duty_Year[0]'
            }
          },
          'to' => {
            'month' => {
              key: 'form1[0].#subform[48].Date_Of_Release_From_Active_Duty_Month[0]'
            },
            'day' => {
              key: 'form1[0].#subform[48].Date_Of_Release_From_Active_Duty_Day[0]'
            },
            'year' => {
              key: 'form1[0].#subform[48].Date_Of_Release_From_Active_Duty_Year[0]'
            }
          }
        },
        # 3e
        'serviceBranch' => {
          'army' => {
            key: 'form1[0].#subform[48].Army[0]'
          },
          'navy' => {
            key: 'form1[0].#subform[48].Navy[0]'
          },
          'airForce' => {
            key: 'form1[0].#subform[48].Air_Force[0]'
          },
          'coastGuard' => {
            key: 'form1[0].#subform[48].Coast_Guard[0]'
          },
          'marineCorps' => {
            key: 'form1[0].#subform[48].Marine_Corps[0]'
          },
          'spaceForce' => {
            key: 'form1[0].#subform[48].Space_Force[0]'
          },
          'usphs' => {
            key: 'form1[0].#subform[48].USPHS[0]'
          },
          'noaa' => {
            key: 'form1[0].#subform[48].NOAA[0]'
          }
        },
        # 3d
        'serviceNumber' => {
          limit: 12,
          question_num: 3,
          question_suffix: 'D',
          question_text: 'YOUR SERVICE NUMBER',
          key: 'form1[0].#subform[48].Your_Service_Number[0]'
        },
        # 3f
        'placeOfSeparationLineOne' => {
          limit: 18,
          question_num: 3,
          question_suffix: 'F',
          question_text: 'PLACE OF YOUR LAST SEPARATION.',
          key: 'form1[0].#subform[48].Place_Of_Your_Last_Separation[1]'
        },
        'placeOfSeparationLineTwo' => {
          key: 'form1[0].#subform[48].Place_Of_Your_Last_Separation[0]'
        },
        # 3g
        'pow' => {
          key: 'form1[0].#subform[48].RadioButtonList[1]'
        },
        # 3h
        'powDateRange' => {
          'from' => {
            'month' => {
              key: 'form1[0].#subform[48].Date_Confinement_Started_Month[1]'
            },
            'day' => {
              key: 'form1[0].#subform[48].Date_Confinement_Started_Day[1]'
            },
            'year' => {
              key: 'form1[0].#subform[48].Date_Confinement_Started_Year[1]'
            }
          },
          'to' => {
            'month' => {
              key: 'form1[0].#subform[48].Date_Confinement_Ended_Month[1]'
            },
            'day' => {
              key: 'form1[0].#subform[48].Date_Confinement_Ended_Day[1]'
            },
            'year' => {
              key: 'form1[0].#subform[48].Date_Confinement_Ended_Year[1]'
            }
          }
        },
        # 4a
        'socialSecurityDisability' => {
          key: 'form1[0].#subform[48].RadioButtonList[2]'
        },
        # 4b
        'medicalCondition' => {
          key: 'form1[0].#subform[48].RadioButtonList[3]'
        },
        # 4c
        'nursingHome' => {
          key: 'form1[0].#subform[48].RadioButtonList[4]'
        },
        # 4d
        'medicaidStatus' => {
          key: 'form1[0].#subform[48].RadioButtonList[5]'
        },
        # 4e
        'specialMonthlyPension' => {
          key: 'form1[0].#subform[48].RadioButtonList[6]'
        },
        # 4f
        'vaTreatmentHistory' => {
          key: 'form1[0].#subform[49].RadioButtonList[7]'
        },
        'vaMedicalCenters' => {
          limit: 1,
          first_key: 'medicalCenter',
          'medicalCenter' => {
            limit: 33,
            question_num: 4,
            question_suffix: 'F',
            question_text: 'Specify VA Facility',
            key: 'form1[0].#subform[49].Facility[0]'
          }
        },
        # 4g
        'federalTreatmentHistory' => {
          key: 'form1[0].#subform[49].RadioButtonList[8]'
        },
        'federalMedicalCenters' => {
          limit: 1,
          first_key: 'medicalCenter',
          'medicalCenter' => {
            limit: 44,
            question_num: 4,
            question_suffix: 'G',
            question_text: 'Specify Federal Facility',
            key: 'form1[0].#subform[49].Facility[1]'
          }
        },
        # 5a
        'currentEmployment' => {
          key: 'form1[0].#subform[49].RadioButtonList[9]'
        },
        'currentEmployers' => {
          limit: 1,
          first_key: 'jobType',
          # 5b
          'jobType' => {
            limit: 35,
            question_num: 5,
            question_suffix: 'B',
            question_text: 'WHAT KIND OF WORK ARE YOU CURRENTLY DOING',
            key: 'form1[0].#subform[49].What_Kind_Of_Work_Are_You_Currently_Doing[0]'
          },
          # 5c
          'jobHoursWeek' => {
            limit: 3,
            question_num: 5,
            question_suffix: 'B',
            question_text: 'HOW MANY HOURS PER WEEK DO YOU AVERAGE',
            key: 'form1[0].#subform[49].How_Many_Hours_Per_Week_Do_You_Average[0]'
          }
        },
        'previousEmployers' => {
          limit: 1,
          first_key: 'jobTitle',
          # 5d
          'jobDate' => {
            'month' => {
              key: 'form1[0].#subform[49].Date_You_Last_Worked_Month[0]'
            },
            'day' => {
              key: 'form1[0].#subform[49].Date_You_Last_Worked_Day[0]'
            },
            'year' => {
              key: 'form1[0].#subform[49].Date_You_Last_Worked_Year[0]'
            }
          },
          'jobDateOverflow' => {
            question_num: 5,
            question_suffix: 'D',
            question_text: 'WHEN DID YOU LAST WORK'
          },
          # 5e
          'jobHoursWeek' => {
            limit: 3,
            question_num: 5,
            question_suffix: 'E',
            question_text: 'HOW MANY HOURS PER WEEK DID YOU AVERAGE',
            key: 'form1[0].#subform[49].How_Many_Hours_Per_Week_Did_You_Average[0]'
          },
          # 5f
          'jobTitle' => {
            limit: 30,
            question_num: 5,
            question_suffix: 'F',
            question_text: 'WHAT WAS YOUR JOB TITLE',
            key: 'form1[0].#subform[49].What_Was_Your_Job_Title[0]'
          },
          # 5g
          'jobType' => {
            limit: 27,
            question_num: 5,
            question_suffix: 'G',
            question_text: 'WHAT KIND OF WORK DID YOU DO',
            key: 'form1[0].#subform[49].What_Kind_Of_Work_Did_You_Do[0]'
          }
        },
        # 6a
        'maritalStatus' => {
          key: 'form1[0].#subform[49].RadioButtonList[10]'
        },
        'currentMarriage' => {
          # 6b
          'spouseFullName' => {
            'first' => {
              limit: 12,
              question_num: 6,
              question_suffix: 'B',
              question_text: 'SPOUSE\'S CURRENT FIRST NAME',
              key: 'form1[0].#subform[49].Spouses_Current_Legal_Name_First_Name[0]'
            },
            'middle' => {
              key: 'form1[0].#subform[49].Spouses_Middle_Initial1[0]'
            },
            'last' => {
              limit: 18,
              question_num: 6,
              question_suffix: 'B',
              question_text: 'SPOUSE\'S CURRENT LAST NAME',
              key: 'form1[0].#subform[49].Spouses_Last_Name[0]'
            }
          },
          # 6e
          'dateOfMarriage' => {
            'month' => {
              key: 'form1[0].#subform[49].Date_Of_Marriage_Month[0]'
            },
            'day' => {
              key: 'form1[0].#subform[49].Date_Of_Marriage_Day[0]'
            },
            'year' => {
              key: 'form1[0].#subform[49].Date_Of_Marriage_Year[0]'
            }
          },
          'locationOfMarriage' => {
            limit: 22,
            question_num: 6,
            question_suffix: 'E',
            question_text: 'PLACE OF MARRIAGE CITY AND STATE OR COUNTRY',
            key: 'form1[0].#subform[49].Place_Of_Marriage_City_And_State_Or_Country[0]'
          },
          # 6f
          'marriageType' => {
            key: 'form1[0].#subform[49].RadioButtonList[11]'
          },
          'otherExplanation' => {
            limit: 22,
            question_num: 6,
            question_suffix: 'F',
            question_text: 'SPECIFY TYPE OF MARRIAGE',
            key: 'form1[0].#subform[49].Other_Specify[0]'
          }
        },
        # 6c
        'spouseDateOfBirth' => {
          'month' => {
            key: 'form1[0].#subform[49].DOB_Month[0]'
          },
          'day' => {
            key: 'form1[0].#subform[49].DOB_Day[0]'
          },
          'year' => {
            key: 'form1[0].#subform[49].DOB_Year[0]'
          }
        },
        # 6d
        'spouseSocialSecurityNumber' => {
          'first' => {
            key: 'form1[0].#subform[49].Spouses_SocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'form1[0].#subform[49].Spouses_SocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[49].Spouses_SocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        # 6g
        'spouseIsVeteran' => {
          key: 'form1[0].#subform[49].RadioButtonList[12]'
        },
        # 6h
        'spouseVaFileNumber' => {
          key: 'form1[0].#subform[49].Spouses_VAFileNumber_If_Any[0]'
        },
        # 6i
        'reasonForCurrentSeparation' => {
          key: 'form1[0].#subform[49].RadioButtonList[13]'
        },
        'otherExplanation' => {
          limit: 39,
          question_num: 6,
          question_suffix: 'I',
          question_text: '',
          key: 'form1[0].#subform[49].Other_Specify[1]'
        },
        # 6j
        'spouseAddress' => {
          'street' => {
            limit: 30,
            question_num: 6,
            question_suffix: 'J',
            question_text: 'SPOUSE MAILING ADDRESS STREET',
            key: 'form1[0].#subform[49].Number_And_Street[0]'
          },
          'street2' => {
            limit: 5,
            question_num: 6,
            question_suffix: 'J',
            question_text: 'SPOUSE MAILING ADDRESS APT NUMBER',
            key: 'form1[0].#subform[49].Apt_Or_Unit_Number[1]'
          },
          'city' => {
            limit: 18,
            question_num: 6,
            question_suffix: 'J',
            question_text: 'SPOUSE MAILING ADDRESS CITY',
            key: 'form1[0].#subform[49].City[1]'
          },
          'state' => {
            key: 'form1[0].#subform[49].State_Or_Province[0]'
          },
          'country' => {
            key: 'form1[0].#subform[49].Country[1]'
          },
          'postalCode' => {
            'firstFive' => {
              key: 'form1[0].#subform[49].Zip_Postal_Code[2]'
            },
            'lastFour' => {
              key: 'form1[0].#subform[49].Zip_Postal_Code[3]'
            }
          }
        },
        # 6k
        'currentSpouseMonthlySupport' => {
          'part_two' => {
            key: 'form1[0].#subform[49].Monthly_Amount[0]'
          },
          'part_one' => {
            key: 'form1[0].#subform[49].Monthly_Amount[1]'
          },
          'part_cents' => {
            key: 'form1[0].#subform[49].Monthly_Amount[2]'
          }
        },
        'bankAccount' => {
          # 11a
          'bankName' => {
            limit: 30,
            question_num: 11,
            question_suffix: 'A',
            question_text: 'NAME OF FINANCIAL INSTITUTION',
            key: 'form1[0].#subform[54].Name_Of_Financial_Institution[0]'
          },
          # 11b
          'accountType' => {
            key: 'form1[0].#subform[54].RadioButtonList[55]'
          },
          # 11c
          'routingNumber' => {
            limit: 9,
            question_num: 11,
            question_suffix: 'C',
            question_text: 'ROUTING NUMBER',
            key: 'form1[0].#subform[54].Routing_Number[0]'
          },
          # 11d
          'accountNumber' => {
            limit: 15,
            question_num: 11,
            question_suffix: 'D',
            question_text: 'ACCOUNT NUMBER',
            key: 'form1[0].#subform[54].Account_Number[0]'
          }
        },
        # 12a
        'noRapidProcessing' => {
          # rubocop:disable Layout/LineLength
          key: 'form1[0].#subform[54].CheckBox_I_Do_Not_Want_My_Claim_Considered_For_Rapid_Processing_Under_The_F_D_C_Program_Because_I_Plan_To_Submit_Further_Evidence_In_Support_Of_My_Claim[0]'
          # rubocop:enable Layout/LineLength
        },
        # 12b
        'statementOfTruthSignature' => {
          key: 'form1[0].#subform[54].SignatureField1[0]'
        },
        # 12c
        'signatureDate' => {
          'month' => {
            key: 'form1[0].#subform[54].Date_Signed_Month[0]'
          },
          'day' => {
            key: 'form1[0].#subform[54].Date_Signed_Day[0]'
          },
          'year' => {
            key: 'form1[0].#subform[54].Date_Signed_Year[0]'
          }
        }
      }.freeze

      def merge_fields(_options = {})
        expand_veteran_identification_information
        expand_veteran_contact_information
        expand_veteran_service_information
        expand_pension_information
        expand_employment_history
        expand_marital_status
        expand_direct_deposit_information
        expand_claim_certification_and_signature

        @form_data
      end

      # SECTION I: VETERAN'S IDENTIFICATION INFORMATION
      def expand_veteran_identification_information
        @form_data['veteranFullName'] ||= {}
        @form_data['veteranFullName']['first'] = @form_data.dig('veteranFullName', 'first')&.titleize
        @form_data['veteranFullName']['middle'] = @form_data.dig('veteranFullName', 'middle')&.titleize
        @form_data['veteranFullName']['last'] = @form_data.dig('veteranFullName', 'last')&.titleize
        @form_data['veteranSocialSecurityNumber'] = split_ssn(@form_data['veteranSocialSecurityNumber'])
        @form_data['veteranDateOfBirth'] = split_date(@form_data['veteranDateOfBirth'])
        @form_data['vaPreviouslyFiled'] = to_radio_yes_no(@form_data['vaFileNumber'].present?)
      end

      # SECTION II: VETERAN'S CONTACT INFORMATION
      def expand_veteran_contact_information
        @form_data['veteranAddress'] ||= {}
        @form_data['veteranAddress']['postalCode'] =
          split_postal_code(@form_data['veteranAddress'])
        @form_data['mobilePhone'] = expand_phone_number(@form_data['mobilePhone'].to_s)
      end

      # SECTION III: VETERAN'S SERVICE INFORMATION
      def expand_veteran_service_information
        @form_data['activeServiceDateRange'] = {
          'from' => split_date(@form_data.dig('activeServiceDateRange', 'from')),
          'to' => split_date(@form_data.dig('activeServiceDateRange', 'to'))
        }
        @form_data['serviceBranch'] = @form_data['serviceBranch']&.select { |_, value| value == true }

        @form_data['pow'] = to_radio_yes_no(@form_data['powDateRange'].present?)
        if @form_data['pow'].zero?
          @form_data['powDateRange'] ||= {}
          @form_data['powDateRange']['from'] = split_date(@form_data.dig('powDateRange', 'from'))
          @form_data['powDateRange']['to'] = split_date(@form_data.dig('powDateRange', 'to'))
        end

        place_of_separation = @form_data['placeOfSeparation'].to_s

        if place_of_separation.length <= 36 # split lines
          @form_data['placeOfSeparationLineOne'] = place_of_separation[0..17]
          @form_data['placeOfSeparationLineTwo'] = place_of_separation[18..]
        else # overflow
          @form_data['placeOfSeparationLineOne'] = place_of_separation
        end
      end

      # SECTION IV: PENSION INFORMATION
      def expand_pension_information
        @form_data['nursingHome'] = to_radio_yes_no(@form_data['nursingHome'])
        @form_data['medicaidStatus'] = to_radio_yes_no(@form_data['medicaidStatus'])
        @form_data['specialMonthlyPension'] = to_radio_yes_no(@form_data['specialMonthlyPension'])
        @form_data['medicalCondition'] = to_radio_yes_no(@form_data['medicalCondition'])
        @form_data['socialSecurityDisability'] = to_radio_yes_no(@form_data['socialSecurityDisability'])

        # If "YES," skip question 4B
        @form_data['medicalCondition'] = 'Off' if @form_data['socialSecurityDisability'].zero?

        # If "NO," skip question 4D
        @form_data['medicaidStatus'] = 'Off' if @form_data['nursingHome'] == 1

        @form_data['vaTreatmentHistory'] = to_radio_yes_no(@form_data['vaTreatmentHistory'])
        @form_data['federalTreatmentHistory'] = to_radio_yes_no(@form_data['federalTreatmentHistory'])
      end

      # SECTION V: EMPLOYMENT HISTORY
      def expand_employment_history
        @form_data['currentEmployment'] = to_radio_yes_no(@form_data['currentEmployment'])

        @form_data['previousEmployers'] = @form_data['previousEmployers']&.map do |pe|
          pe.merge({
                     'jobDate' => split_date(pe['jobDate']),
                     'jobDateOverflow' => pe['jobDate']
                   })
        end

        @form_data['currentEmployers'] = nil if @form_data['currentEmployment'] == 1
      end

      # SECTION VI: MARITAL STATUS
      def expand_marital_status
        @form_data['maritalStatus'] = marital_status_to_radio(@form_data['maritalStatus'])
        @form_data['currentMarriage'] = get_current_marriage(@form_data['marriages'])
        @form_data['spouseDateOfBirth'] = split_date(@form_data['spouseDateOfBirth'])
        @form_data['spouseSocialSecurityNumber'] = split_ssn(@form_data['spouseSocialSecurityNumber'])
        @form_data['spouseIsVeteran'] = to_radio_yes_no(@form_data['spouseIsVeteran'])
        @form_data['spouseAddress'] ||= {}
        @form_data['spouseAddress']['postalCode'] = split_postal_code(@form_data['spouseAddress'])
        @form_data['currentSpouseMonthlySupport'] = split_currency_amount(@form_data['currentSpouseMonthlySupport'])
        @form_data['reasonForCurrentSeparation'] =
          reason_for_current_separation_to_radio(@form_data['reasonForCurrentSeparation'])
      end

      def marital_status_to_radio(marital_status)
        case marital_status
        when 'Married' then 0
        when 'Separated' then 1
        else 2
        end
      end

      def get_current_marriage(marriages)
        current_marriage = marriages&.find { |marriage| !marriage.key?('dateOfSeparation') } || {}
        return current_marriage if current_marriage.empty?

        marriage_type = current_marriage['marriageType']
        current_marriage['marriageType'] =
          marriage_type == 'In a civil or religious ceremony with an officiant who signed my marriage license' ? 0 : 1
        current_marriage['dateOfMarriage'] =
          split_date(current_marriage['dateOfMarriage'])
        current_marriage
      end

      def reason_for_current_separation_to_radio(reason_for_separation)
        case reason_for_separation
        when 'MEDICAL_CARE' then 0
        when 'RELATIONSHIP' then 1
        when 'LOCATION' then 2
        when 'OTHER' then 3
        else 'Off'
        end
      end

      # SECTION XI: DIRECT DEPOSIT INFORMATION
      def expand_direct_deposit_information
        account_type = @form_data.dig('bankAccount', 'accountType')

        @form_data['bankAccount'] = @form_data['bankAccount'].to_h.merge(
          'accountType' => case account_type
                           when 'checking' then 0
                           when 'savings' then 1
                           else 2 if @form_data['bankAccount'].nil?
                           end
        )
      end

      # SECTION XII: CLAIM CERTIFICATION AND SIGNATURE
      def expand_claim_certification_and_signature
        @form_data['noRapidProcessing'] = to_checkbox_on_off(@form_data['noRapidProcessing'])
        # form was signed today
        @form_data['signatureDate'] = split_date(Time.zone.now.strftime('%Y-%m-%d'))
      end

      def split_currency_amount(amount)
        return {} if amount.nil? || amount.negative? || amount >= 10_000_000

        number_map = {
          1 => 'one',
          2 => 'two',
          3 => 'three'
        }

        arr = ActiveSupport::NumberHelper.number_to_currency(amount).to_s.split(/[,.$]/).reject(&:empty?)
        split_hash = { 'part_cents' => arr.last }
        arr.pop
        arr.each_with_index { |x, i| split_hash["part_#{number_map[arr.length - i]}"] = x }
        split_hash
      end

      def to_radio_yes_no(obj)
        obj ? 0 : 1
      end

      def to_checkbox_on_off(obj)
        obj ? 1 : 'Off'
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
