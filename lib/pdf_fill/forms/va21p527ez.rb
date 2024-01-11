# frozen_string_literal: true

require 'pdf_fill/hash_converter'
require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'string_helpers'

module PdfFill
  module Forms
    class Va21p527ez < FormBase
      include FormHelper
      include FormHelper::PhoneNumberFormatting

      ITERATOR = PdfFill::HashConverter::ITERATOR

      RECIPIENTS = {
        'VETERAN' => 0,
        'SPOUSE' => 1,
        'CHILD' => 2
      }.freeze

      INCOME_TYPES = {
        'SOCIAL_SECURITY' => 0,
        'INTEREST_DIVIDEND' => 1,
        'RETIREMENT' => 2,
        'PENSION' => 3,
        'OTHER' => 4
      }.freeze

      CARE_TYPES = {
        'CARE_FACILITY' => 0,
        'IN_HOME_CARE_PROVIDER' => 1
      }.freeze

      PAYMENT_FREQUENCY = {
        'ONCE_MONTH' => 0,
        'ONCE_YEAR' => 1,
        'ONE_TIME' => 2
      }.freeze

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
        'vaClaimsHistory' => {
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
          'ARMY' => {
            key: 'form1[0].#subform[48].Army[0]'
          },
          'NAVY' => {
            key: 'form1[0].#subform[48].Navy[0]'
          },
          'AIR_FORCE' => {
            key: 'form1[0].#subform[48].Air_Force[0]'
          },
          'COAST_GUARD' => {
            key: 'form1[0].#subform[48].Coast_Guard[0]'
          },
          'MARINE_CORPS' => {
            key: 'form1[0].#subform[48].Marine_Corps[0]'
          },
          'SPACE_FORCE' => {
            key: 'form1[0].#subform[48].Space_Force[0]'
          },
          'USPHS' => {
            key: 'form1[0].#subform[48].USPHS[0]'
          },
          'NOAA' => {
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
        # 9a
        'totalNetWorth' => {
          key: 'form1[0].#subform[51].RadioButtonList[21]'
        },
        'netWorthEstimation' => {
          'lastThree' => {
            key: 'form1[0].#subform[51].Total_Value_Of_Assets_Amount[0]'
          },
          'firstTwo' => {
            key: 'form1[0].#subform[51].Total_Value_Of_Assets_Amount[1]'
          }
        },
        # 9b
        'transferredAssets' => {
          key: 'form1[0].#subform[51].RadioButtonList[22]'
        },
        # 9c
        'homeOwnership' => {
          key: 'form1[0].#subform[51].RadioButtonList[23]'
        },
        # 9d
        'homeAcreageMoreThanTwo' => {
          key: 'form1[0].#subform[51].RadioButtonList[24]'
        },
        # 9e
        'homeAcreageValue' => {
          'part_one' => {
            key: 'form1[0].#subform[51].Value_Of_Land_Over_Two_Acres_Amount[0]'
          },
          'part_three' => {
            key: 'form1[0].#subform[51].Value_Of_Land_Over_Two_Acres_Amount[1]'
          },
          'part_two' => {
            key: 'form1[0].#subform[51].Value_Of_Land_Over_Two_Acres_Amount[2]'
          }
        },
        # 9f
        'landMarketable' => {
          key: 'form1[0].#subform[51].RadioButtonList[25]'
        },
        # 9g
        'moreThanFourIncomeSources' => {
          key: 'form1[0].#subform[51].RadioButtonList[26]'
        },
        # 9h-k
        'incomeSources' => {
          limit: 4,
          first_key: 'childName',
          # (1) Recipient
          'receiver' => {
            key: "Income_Recipient[#{ITERATOR}]",
          },
          'receiverOverflow' => {
            question_num: 9,
            question_suffix: '(1)',
            question_text: 'INCOME RECIPIENT',
          },
          'childName' => {
            key: "Income_Recipient_Child[#{ITERATOR}]",
            limit: 29,
            question_num: 9,
            question_suffix: '(1)',
            question_text: 'CHILD NAME',
          },
          # (2) Income Type
          'typeOfIncome' => {
            key: "Income_Type[#{ITERATOR}]",
          },
          'typeOfIncomeOverflow' => {
            question_num: 9,
            question_suffix: '(2)',
            question_text: 'INCOME TYPE',
          },
          'otherTypeExplanation' => {
            key: "Other_Specify_Type_Of_Income[#{ITERATOR}]",
            limit: 31,
            question_num: 9,
            question_suffix: '(2)',
            question_text: 'OTHER INCOME TYPE EXPLANATION',
          },
          # (3) Income Payer
          'payer' => {
            key: "Name_Of_Income_Payer[#{ITERATOR}]",
            limit: 25,
            question_num: 9,
            question_suffix: '(3)',
            question_text: 'PAYER NAME',
          },
          # (4) Gross Monthly Income
          'amount' => {
            'part_two' => {
              key: "Income_Monthly_Amount_First_Three[#{ITERATOR}]"
            },
            'part_one' => {
              key: "Income_Monthly_Amount_Last_Three[#{ITERATOR}]"
            },
            'part_cents' => {
              key: "Income_Monthly_Amount_Cents[#{ITERATOR}]"
            }
          },
          'amountOverflow' => {
            question_num: 9,
            question_suffix: '(4)',
            question_text: 'CURRENT GROSS MONTHLY INCOME',
          }
        },
        # 10a
        'hasAnyExpenses' => {
          key: 'Has_Any_Expenses_Yes_No'
        },
        # 10b-d
        'careExpenses' => {
          limit: 3,
          first_key: 'childName',
          # (1) Recipient
          'recipients' => {
            key: "Care_Expenses.Recipient[#{ITERATOR}]",
          },
          'recipientsOverflow' => {
            question_num: 10,
            question_suffix: '(1)',
            question_text: 'CARE EXPENSE RECIPIENT',
          },
          'childName' => {
            key: "Care_Expenses.Child_Specify[#{ITERATOR}]",
            limit: 45,
            question_num: 10,
            question_suffix: '(1)',
            question_text: 'CARE EXPENSE CHILD NAME',
          },
          # (2) Provider
          'provider' => {
            key: "Care_Expenses.Name_Of_Provider[#{ITERATOR}]",
            limit: 70,
            question_num: 10,
            question_suffix: '(2)',
            question_text: 'CARE EXPENSE PROVIDER NAME',
          },
          'careType' => {
            key: "Care_Expenses.Care_Type[#{ITERATOR}]"
          },
          'careTypeOverflow' => {
            question_num: 10,
            question_suffix: '(2)',
            question_text: 'CARE TYPE',
          },
          # (3) Rate Per Hour
          'ratePerHour' => {
            'part_one' => {
              key: "Care_Expenses.Rate_Per_Hour_Amount[#{ITERATOR}]"
            },
            'part_cents' => {
              key: "Care_Expenses.Rate_Per_Hour_Amount_Cents[#{ITERATOR}]"
            }
          },
          'ratePerHourOverflow' => {
            question_num: 10,
            question_suffix: '(3)',
            question_text: 'CARE EXPENSE RATE PER HOUR',
          },
          'hoursPerWeek' => {
            limit: 3,
            question_num: 10,
            question_suffix: '(3)',
            question_text: 'HOURS PER WEEK CARE RECEIVED',
            key: "Care_Expenses.Hours_Worked_Per_Week[#{ITERATOR}]"
          },
          # (4) Provider Start/End Dates
          'careDateRange' => {
            'from' => {
              'month' => {
                key: "Care_Expenses.Provider_Start_Date_Month[#{ITERATOR}]"
              },
              'day' => {
                key: "Care_Expenses.Provider_Start_Date_Day[#{ITERATOR}]"
              },
              'year' => {
                key: "Care_Expenses.Provider_Start_Date_Year[#{ITERATOR}]"
              }
            },
            'to' => {
              'month' => {
                key: "Care_Expenses.Provider_End_Date_Month[#{ITERATOR}]"
              },
              'day' => {
                key: "Care_Expenses.Provider_End_Date_Day[#{ITERATOR}]"
              },
              'year' => {
                key: "Care_Expenses.Provider_End_Date_Year[#{ITERATOR}]"
              }
            }
          },
          'careDateRangeOverflow' => {
            question_num: 10,
            question_suffix: '(4)',
            question_text: 'DATE RANGE CARE RECEIVED',
          },
          'noCareEndDate' => {
            key: "Care_Expenses.CheckBox_No_End_Date[#{ITERATOR}]"
          },
          # (5) Payment Frequency
          'paymentFrequency' => {
            key: "Care_Expenses.Payment_Frequency[#{ITERATOR}]"
          },
          'paymentFrequencyOverflow' => {
            question_num: 10,
            question_suffix: '(5)',
            question_text: 'CARE EXPENSE PAYMENT FREQUENCY',
          },
          # (6) Rate Per Frequency
          'paymentAmount' => {
            'part_two' => {
              key: "Care_Expenses.Rate_Per_Frequency_Amount_First_Three[#{ITERATOR}]"
            },
            'part_one' => {
              key: "Care_Expenses.Rate_Per_Frequency_Amount_Last_Three[#{ITERATOR}]"
            },
            'part_cents' => {
              key: "Care_Expenses.Rate_Per_Frequency_Amount_Cents[#{ITERATOR}]"
            }
          },
          'paymentAmountOverflow' => {
            question_num: 10,
            question_suffix: '(6)',
            question_text: 'CARE EXPENSE PAYMENT AMOUNT',
          }
        },
        # 10e-j
        'medicalExpenses' => {
          limit: 3,
          first_key: 'childName',
          # (1) Recipient
          'recipients' => {
            key: "Med_Expenses.Recipient[#{ITERATOR}]",
          },
          'recipientsOverflow' => {
            question_num: 9,
            question_suffix: '(1)',
            question_text: 'MEDICAL EXPENSE RECIPIENT',
          },
          'childName' => {
            key: "Med_Expenses.Child_Specify[#{ITERATOR}]",
            limit: 45,
            question_num: 10,
            question_suffix: '(1)',
            question_text: 'MEDICAL EXPENSE CHILD NAME',
          },
          # (2) Provider
          'provider' => {
            key: "Med_Expenses.Paid_To[#{ITERATOR}]",
            limit: 108,
            question_num: 10,
            question_suffix: '(2)',
            question_text: 'MEDICAL EXPENSE PROVIDER NAME',
          },
          # (3) Purpose
          'purpose' => {
            key: "Med_Expenses.Purpose[#{ITERATOR}]",
            limit: 108,
            question_num: 10,
            question_suffix: '(3)',
            question_text: 'MEDICAL EXPENSE PURPOSE',
          },
          # (4) Payment Date
          'paymentDate' => {
            'month' => {
              key: "Med_Expenses.Date_Costs_Incurred_Month[#{ITERATOR}]"
            },
            'day' => {
              key: "Med_Expenses.Date_Costs_Incurred_Day[#{ITERATOR}]"
            },
            'year' => {
              key: "Med_Expenses.Date_Costs_Incurred_Year[#{ITERATOR}]"
            }
          },
          'paymentDateOverflow' => {
            question_num: 10,
            question_suffix: '(4)',
            question_text: 'MEDICAL EXPENSE PAYMENT DATE',
          },
          # (5) Payment Frequency
          'paymentFrequency' => {
            key: "Med_Expenses.Payment_Frequency[#{ITERATOR}]"
          },
          'paymentFrequencyOverflow' => {
            question_num: 10,
            question_suffix: '(5)',
            question_text: 'MEDICAL EXPENSE PAYMENT FREQUENCY',
          },
          # (6) Rate Per Frequency
          'paymentAmount' => {
            'part_two' => {
              limit: 2,
              key: "Med_Expenses.Amount_First_Two[#{ITERATOR}]"
            },
            'part_one' => {
              key: "Med_Expenses.Amount_Last_Three[#{ITERATOR}]"
            },
            'part_cents' => {
              key: "Med_Expenses.Amount_Cents[#{ITERATOR}]"
            }
          },
          'paymentAmountOverflow' => {
            question_num: 10,
            question_suffix: '(6)',
            question_text: 'MEDICAL EXPENSE PAYMENT AMOUNT',
          }
        }
      }.freeze

      def merge_fields(_options = {})
        expand_veteran_identification_information
        expand_veteran_contact_information
        expand_veteran_service_information
        expand_pension_information
        expand_employment_history
        expand_income
        expand_expenses

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
        @form_data['vaClaimsHistory'] = to_radio_yes_no(@form_data['vaClaimsHistory'])
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

      # SECTION IX: INCOME AND ASSETS
      def expand_income
        @form_data['totalNetWorth'] = to_radio_yes_no(@form_data['totalNetWorth'])
        @form_data['netWorthEstimation'] = split_currency_amount(@form_data['netWorthEstimation']) if @form_data['netWorthEstimation']
        @form_data['transferredAssets'] = to_radio_yes_no(@form_data['transferredAssets'])
        @form_data['homeOwnership'] = to_radio_yes_no(@form_data['homeOwnership'])
        @form_data['homeAcreageMoreThanTwo'] = to_radio_yes_no(@form_data['homeAcreageMoreThanTwo'])
        @form_data['homeAcreageValue'] = split_currency_amount(@form_data['homeAcreageValue']) if @form_data['homeAcreageValue'].present?
        @form_data['landMarketable'] = to_radio_yes_no(@form_data['landMarketable'])
        @form_data['moreThanFourIncomeSources'] = to_radio_yes_no(@form_data['incomeSources'].length > 4)
        @form_data['incomeSources'] = @form_data['incomeSources']&.map do |is|
          is.merge({
                     'receiver' => 0, # TODO: Update this once the front-end is updated post MVP
                     'receiverOverflow' => 'VETERAN', # TODO: Update this once the front-end is updated post MVP
                     'typeOfIncome' => INCOME_TYPES.dig(is['typeOfIncome']),
                     'typeOfIncomeOverflow' => is['typeOfIncome'],
                     'amount' => split_currency_amount(is.dig('amount')),
                     'amountOverflow' => ActiveSupport::NumberHelper.number_to_currency(is.dig('amount'))
                   })
        end
      end

      # SECTION X: CARE/MEDICAL EXPENSES
      def expand_expenses
        @form_data['hasAnyExpenses'] = to_radio_yes_no(@form_data['hasCareExpenses'] || @form_data['hasMedicalExpenses'])
        @form_data['careExpenses'] = @form_data['careExpenses']&.map do |ce|
          ce.merge({
                     'recipients' => RECIPIENTS.dig(ce['recipients']),
                     'recipientsOverflow' => ce['recipients']&.humanize,
                     'careType' => CARE_TYPES.dig(ce['careType']),
                     'careTypeOverflow' => ce['careType']&.humanize,
                     'ratePerHour' => split_currency_amount(ce.dig('ratePerHour')),
                     'ratePerHourOverflow' => ActiveSupport::NumberHelper.number_to_currency(ce.dig('ratePerHour')),
                     'hoursPerWeek' => ce['hoursPerWeek'].to_s,
                     'careDateRange' => {
                      'from' => split_date(ce.dig('careDateRange', 'from')),
                      'to' => split_date(ce.dig('careDateRange', 'to'))
                     },
                     'careDateRangeOverflow' => build_date_range_string(ce.dig('careDateRange')),
                     'noCareEndDate' => to_radio_yes_no(ce.dig('noCareEndDate')),
                     'paymentFrequency' => PAYMENT_FREQUENCY.dig(ce['paymentFrequency']),
                     'paymentFrequencyOverflow' => ce['paymentFrequency'],
                     'paymentAmount' => split_currency_amount(ce.dig('paymentAmount')),
                     'paymentAmountOverflow' => ActiveSupport::NumberHelper.number_to_currency(ce.dig('paymentAmount'))
                   })
        end
        @form_data['medicalExpenses'] = @form_data['medicalExpenses']&.map do |me|
          me.merge({
                     'recipients' => RECIPIENTS.dig(me['recipients']),
                     'recipientsOverflow' => me['recipients']&.humanize,
                     'paymentDate' => split_date(me.dig('paymentDate')),
                     'paymentDateOverflow' => me.dig('paymentDate'),
                     'paymentFrequency' => PAYMENT_FREQUENCY.dig(me['paymentFrequency']),
                     'paymentFrequencyOverflow' => me['paymentFrequency'],
                     'paymentAmount' => split_currency_amount(me.dig('paymentAmount')),
                     'paymentAmountOverflow' => ActiveSupport::NumberHelper.number_to_currency(me.dig('paymentAmount'))
                   })
        end
      end

      def build_date_range_string(date_range)
        "#{date_range.dig('from')} - #{date_range.dig('to') || 'No End Date'}"
      end

      def split_currency_amount(amount)
        return {} if amount.nil? || amount.negative?

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
    end
  end
end
