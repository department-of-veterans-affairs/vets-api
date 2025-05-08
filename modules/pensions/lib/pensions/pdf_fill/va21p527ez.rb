# frozen_string_literal: true

require 'pdf_fill/hash_converter'
require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'string_helpers'

require_relative 'constants'

# rubocop:disable Metrics/ClassLength
module Pensions
  module PdfFill
    # The Va21p527ez Form
    class Va21p527ez < ::PdfFill::Forms::FormBase
      include ::PdfFill::Forms::FormHelper
      include ::PdfFill::Forms::FormHelper::PhoneNumberFormatting
      include ActiveSupport::NumberHelper

      # The Form ID
      FORM_ID = Pensions::FORM_ID

      # The PDF Template
      TEMPLATE = "#{Pensions::MODULE_PATH}/lib/pensions/pdf_fill/pdfs/21P-527EZ.pdf".freeze

      # The Index Iterator Key
      ITERATOR = ::PdfFill::HashConverter::ITERATOR

      # The PDF Keys
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
              limit: 4,
              question_num: 2,
              question_suffix: 'A',
              question_text: 'POSTAL CODE - LAST FOUR',
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
        # 7a-j Veteran's prior marriages
        'marriages' => {
          limit: 2,
          first_key: 'otherExplanation',
          question_num: 7.1,
          'spouseFullName' => {
            'first' => {
              limit: 12,
              question_num: 7.1,
              question_suffix: '[Veteran]',
              question_text: 'WHO WERE YOU MARRIED TO? (FIRST NAME)',
              key: "Marriages.Veterans_Prior_Spouse_FirstName[#{ITERATOR}]"
            },
            'middle' => {
              question_num: 7.1,
              question_suffix: '[Veteran]',
              question_text: 'WHO WERE YOU MARRIED TO? (MIDDLE NAME)',
              key: "Marriages.Veterans_Prior_Spouse_MiddleInitial1[#{ITERATOR}]"
            },
            'last' => {
              limit: 18,
              question_num: 7.1,
              question_suffix: '[Veteran]',
              question_text: 'WHO WERE YOU MARRIED TO? (LAST NAME)',
              key: "Marriages.Veterans_Prior_Spouse_LastName[#{ITERATOR}]"
            }
          },
          'spouseFullNameOverflow' => {
            question_num: 7.1,
            question_suffix: '[Veteran]',
            question_text: '(1) WHO WERE YOU MARRIED TO?'
          },
          'reasonForSeparation' => {
            key: "Marriages.Previous_Marriage_End_Reason[#{ITERATOR}]"
          },
          'reasonForSeparationOverflow' => {
            question_num: 7.1,
            question_suffix: '[Veteran]',
            question_text: '(2) HOW DID YOUR PREVIOUS MARRIAGE END?'
          },
          'otherExplanation' => {
            limit: 43,
            question_num: 7.1,
            question_suffix: '[Veteran]',
            question_text: '(2) HOW DID YOUR PREVIOUS MARRIAGE END (OTHER REASON)?',
            key: "Marriages.Other_Specify[#{ITERATOR}]"
          },
          'dateOfMarriage' => {
            'month' => {
              key: "Marriages.Date_Of_Prior_Marriage_Start_Month[#{ITERATOR}]"
            },
            'day' => {
              key: "Marriages.Date_Of_Prior_Marriage_Start_Day[#{ITERATOR}]"
            },
            'year' => {
              key: "Marriages.Date_Of_Prior_Marriage_Start_Year[#{ITERATOR}]"
            }
          },
          'dateOfSeparation' => {
            'month' => {
              key: "Marriages.Date_Of_Prior_Marriage_End_Month[#{ITERATOR}]"
            },
            'day' => {
              key: "Marriages.Date_Of_Prior_Marriage_End_Day[#{ITERATOR}]"
            },
            'year' => {
              key: "Marriages.Date_Of_Prior_Marriage_End_Year[#{ITERATOR}]"
            }
          },
          'dateRangeOfMarriageOverflow' => {
            question_num: 7.1,
            question_suffix: '[Veteran]',
            question_text: '(3) WHAT ARE THE DATES OF THE PREVIOUS MARRIAGE?'
          },
          'locationOfMarriage' => {
            limit: 63,
            question_num: 7.1,
            question_suffix: '[Veteran]',
            question_text: '(4) PLACE OF MARRIAGE',
            key: "Marriages.Place_Of_Marriage_City_And_State_Or_Country[#{ITERATOR}]"
          },
          'locationOfSeparation' => {
            limit: 54,
            question_num: 7.1,
            question_suffix: '[Veteran]',
            question_text: '(5) PLACE OF MARRIAGE TERMINATION',
            key: "Marriages.Place_Of_Marriage_Termination_City_And_State_Or_Country[#{ITERATOR}]"
          }
        },
        # 7l-u Spouse's prior marriages
        'spouseMarriages' => {
          limit: 2,
          first_key: 'otherExplanation',
          'spouseFullName' => {
            'first' => {
              limit: 12,
              question_num: 7.2,
              question_suffix: '[Spouse]',
              question_text: 'WHO WAS YOUR SPOUSE MARRIED TO? (FIRST NAME)',
              key: "Spouse_Marriages.Spouses_Prior_Spouse_FirstName[#{ITERATOR}]"
            },
            'middle' => {
              question_num: 7.2,
              question_suffix: '[Spouse]',
              question_text: 'WHO WAS YOUR SPOUSE MARRIED TO? (MIDDLE NAME)',
              key: "Spouse_Marriages.Spouses_Prior_Spouse_MiddleInitial1[#{ITERATOR}]"
            },
            'last' => {
              limit: 18,
              question_num: 7.2,
              question_suffix: '[Spouse]',
              question_text: 'WHO WAS YOUR SPOUSE MARRIED TO? (LAST NAME)',
              key: "Spouse_Marriages.Spouses_Prior_Spouse_LastName[#{ITERATOR}]"
            }
          },
          'spouseFullNameOverflow' => {
            question_num: 7.2,
            question_suffix: '[Spouse]',
            question_text: '(1) WHO WAS YOUR SPOUSE YOU MARRIED TO?'
          },
          'reasonForSeparation' => {
            key: "Spouse_Marriages.Previous_Marriage_End_Reason[#{ITERATOR}]"
          },
          'reasonForSeparationOverflow' => {
            question_num: 7.2,
            question_suffix: '[Spouse]',
            question_text: '(2) HOW DID THE PREVIOUS MARRIAGE END?'
          },
          'otherExplanation' => {
            limit: 43,
            question_num: 7.2,
            question_suffix: '[Spouse]',
            question_text: '(2) HOW DID THE PREVIOUS MARRIAGE END (OTHER REASON)?',
            key: "Spouse_Marriages.Other_Specify[#{ITERATOR}]"
          },
          'dateOfMarriage' => {
            'month' => {
              key: "Spouse_Marriages.Date_Of_Prior_Marriage_Start_Month[#{ITERATOR}]"
            },
            'day' => {
              key: "Spouse_Marriages.Date_Of_Prior_Marriage_Start_Day[#{ITERATOR}]"
            },
            'year' => {
              key: "Spouse_Marriages.Date_Of_Prior_Marriage_Start_Year[#{ITERATOR}]"
            }
          },
          'dateOfSeparation' => {
            'month' => {
              key: "Spouse_Marriages.Date_Of_Prior_Marriage_End_Month[#{ITERATOR}]"
            },
            'day' => {
              key: "Spouse_Marriages.Date_Of_Prior_Marriage_End_Day[#{ITERATOR}]"
            },
            'year' => {
              key: "Spouse_Marriages.Date_Of_Prior_Marriage_End_Year[#{ITERATOR}]"
            }
          },
          'dateRangeOfMarriageOverflow' => {
            question_num: 7.2,
            question_suffix: '[Spouse]',
            question_text: '(3) WHAT ARE THE DATES OF THE PREVIOUS MARRIAGE?'
          },
          'locationOfMarriage' => {
            limit: 63,
            question_num: 7.2,
            question_suffix: '[Spouse]',
            question_text: '(4) PLACE OF MARRIAGE',
            key: "Spouse_Marriages.Place_Of_Marriage_City_And_State_Or_Country[#{ITERATOR}]"
          },
          'locationOfSeparation' => {
            limit: 54,
            question_num: 7.2,
            question_suffix: '[Spouse]',
            question_text: '(5) PLACE OF MARRIAGE TERMINATION',
            key: "Spouse_Marriages.Place_Of_Marriage_Termination_City_And_State_Or_Country[#{ITERATOR}]"
          }
        },
        # 7k
        'additionalMarriages' => {
          key: 'form1[0].#subform[50].RadioButtonList[15]'
        },
        # 7v
        'additionalSpouseMarriages' => {
          key: 'form1[0].#subform[50].RadioButtonList[17]'
        },
        # 8a
        'dependentChildrenInHousehold' => {
          key: 'form1[0].#subform[50].Number_Of_Dependent_Children_Who_Live_With_You[0]',
          limit: 2,
          question_num: 8,
          question_suffix: 'A',
          question_text: 'Number of Dependent Children Who Live With You'
        },
        # 8b-p Dependent Children
        'dependents' => {
          limit: 3,
          first_key: 'childPlaceOfBirth',
          'fullName' => {
            'first' => {
              limit: 12,
              question_num: 8.1,
              question_text: 'CHILD\'S FIRST NAME',
              key: "Dependent_Children.Childs_FirstName[#{ITERATOR}]"
            },
            'middle' => {
              question_num: 8.1,
              question_text: 'CHILD\'S MIDDLE NAME',
              key: "Dependent_Children.Childs_MiddleInitial1[#{ITERATOR}]"
            },
            'last' => {
              limit: 18,
              question_num: 8.1,
              question_text: 'CHILD\'S LAST NAME',
              key: "Dependent_Children.Childs_LastName[#{ITERATOR}]"
            }
          },
          'fullNameOverflow' => {
            question_num: 8.1,
            question_text: '(1) CHILD\'S NAME'
          },
          'childDateOfBirth' => {
            'month' => {
              key: "Dependent_Children.Childs_DOB_Month[#{ITERATOR}]"
            },
            'day' => {
              key: "Dependent_Children.Childs_DOB_Day[#{ITERATOR}]"
            },
            'year' => {
              key: "Dependent_Children.Childs_DOB_Year[#{ITERATOR}]"
            }
          },
          'childDateOfBirthOverflow' => {
            question_num: 8.1,
            question_text: '(2) CHILD\'S DATE OF BIRTH'
          },
          'childSocialSecurityNumber' => {
            'first' => {
              key: "Dependent_Children.Childs_SocialSecurityNumber_FirstThreeNumbers[#{ITERATOR}]"
            },
            'second' => {
              key: "Dependent_Children.Childs_SocialSecurityNumber_SecondTwoNumbers[#{ITERATOR}]"
            },
            'third' => {
              key: "Dependent_Children.Childs_SocialSecurityNumber_LastFourNumbers[#{ITERATOR}]"
            }
          },
          'childSocialSecurityNumberOverflow' => {
            question_num: 8.1,
            question_text: '(4) CHILD\'S SOCIAL SECURITY NUMBER'
          },
          'childPlaceOfBirth' => {
            limit: 60,
            question_num: 8.1,
            question_text: '(3) CHILD\'S PLACE OF BIRTH',
            key: "Dependent_Children.Place_Of_Birth_City_And_State_Or_Country[#{ITERATOR}]"
          },
          'childRelationship' => {
            'biological' => {
              key: "Dependent_Children.Biological[#{ITERATOR}]"
            },
            'adopted' => {
              key: "Dependent_Children.Adopted[#{ITERATOR}]"
            },
            'stepchild' => {
              key: "Dependent_Children.Stepchild[#{ITERATOR}]"
            }
          },
          'disabled' => {
            key: "Dependent_Children.Seriously_Disabled[#{ITERATOR}]"
          },
          'attendingCollege' => {
            key: "Dependent_Children.Eighteen_To_Twenty_Three_Years_Old_In_School[#{ITERATOR}]"
          },
          'previouslyMarried' => {
            key: "Dependent_Children.Previously_Married[#{ITERATOR}]"
          },
          'childNotInHousehold' => {
            key: "Dependent_Children.Does_Not_Live_With_You_But_Contributes[#{ITERATOR}]"
          },
          'childStatusOverflow' => {
            question_num: 8.1,
            question_text: '(5) CHILD\'S STATUS'
          },
          'monthlyPayment' => {
            'part_two' => {
              key: "Dependent_Children.Amount_Of_Contribution_First_Two[#{ITERATOR}]"
            },
            'part_one' => {
              key: "Dependent_Children.Amount_Of_Contribution_Last_Three[#{ITERATOR}]"
            },
            'part_cents' => {
              key: "Dependent_Children.Amount_Of_Contribution_Cents[#{ITERATOR}]"
            }
          },
          'monthlyPaymentOverflow' => {
            question_num: 8.1,
            question_text: '(6) Amount of Contribution For Child'
          }
        },
        # 8q
        'dependentsNotWithYouAtSameAddress' => {
          key: 'form1[0].#subform[51].RadioButtonList[20]'
        },
        # 8r
        'custodians' => {
          limit: 1,
          first_key: 'first',
          'first' => {
            limit: 12,
            question_num: 8.2,
            question_suffix: 'R',
            question_text: 'CUSTODIAN\'S FIRST NAME',
            key: 'form1[0].#subform[51].Custodians_FirstName[0]'
          },
          'middle' => {
            key: 'form1[0].#subform[51].Custodians_MiddleInitial1[0]'
          },
          'last' => {
            limit: 18,
            question_num: 8.2,
            question_suffix: 'R',
            question_text: 'CUSTODIAN\'S LAST NAME',
            key: 'form1[0].#subform[51].Custodians_LastName[0]'
          },
          'custodianAddress' => {
            'street' => {
              limit: 30,
              question_num: 8.2,
              question_suffix: 'R',
              question_text: 'CUSTODIAN\'S ADDRESS NUMBER AND STREET',
              key: 'form1[0].#subform[51].NumberStreet[3]'
            },
            'street2' => {
              limit: 5,
              question_num: 8.2,
              question_suffix: 'R',
              question_text: 'CUSTODIAN\'S ADDRESS APT/UNIT',
              key: 'form1[0].#subform[51].Apt_Or_Unit_Number[2]'
            },
            'city' => {
              limit: 18,
              question_num: 8.2,
              question_suffix: 'R',
              question_text: 'CUSTODIAN\'S ADDRESS CITY',
              key: 'form1[0].#subform[51].City[2]'
            },
            'state' => {
              question_num: 8.2,
              question_suffix: 'R',
              key: 'form1[0].#subform[51].State_Or_Province[1]'
            },
            'country' => {
              question_num: 8.2,
              question_suffix: 'R',
              key: 'form1[0].#subform[51].Country[2]'
            },
            'postalCode' => {
              question_num: 8.2,
              question_suffix: 'R',
              'firstFive' => {
                key: 'form1[0].#subform[51].Zip_Postal_Code[4]'
              },
              'lastFour' => {
                key: 'form1[0].#subform[51].Zip_Postal_Code[5]'
              }
            }
          },
          'custodianAddressOverflow' => {
            question_num: 8.2,
            question_suffix: 'R',
            question_text: 'CUSTODIAN\'S ADDRESS'
          },
          'dependentsWithCustodianOverflow' => {
            question_num: 8.2,
            question_suffix: 'R',
            question_text: 'DEPENDENTS LIVING WITH THIS CUSTODIAN'
          }
        },
        # 9a
        'totalNetWorth' => {
          key: 'form1[0].#subform[51].RadioButtonList[21]'
        },
        'netWorthEstimation' => {
          'part_two' => {
            key: 'form1[0].#subform[51].Total_Value_Of_Assets_Amount[1]'
          },
          'part_one' => {
            key: 'form1[0].#subform[51].Total_Value_Of_Assets_Amount[0]'
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
          'part_three' => {
            key: 'form1[0].#subform[51].Value_Of_Land_Over_Two_Acres_Amount[1]'
          },
          'part_two' => {
            key: 'form1[0].#subform[51].Value_Of_Land_Over_Two_Acres_Amount[2]'
          },
          'part_one' => {
            key: 'form1[0].#subform[51].Value_Of_Land_Over_Two_Acres_Amount[0]'
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
        # 9h-k Income Sources
        'incomeSources' => {
          limit: 4,
          first_key: 'dependentName',
          # (1) Recipient
          'receiver' => {
            key: "Income_Recipient[#{ITERATOR}]"
          },
          'receiverOverflow' => {
            question_num: 9,
            question_suffix: '(1)',
            question_text: 'PAYMENT RECIPIENT'
          },
          'dependentName' => {
            key: "Income_Recipient_Child[#{ITERATOR}]",
            limit: 29,
            question_num: 9,
            question_suffix: '(1)',
            question_text: 'CHILD NAME'
          },
          # (2) Income Type
          'typeOfIncome' => {
            key: "Income_Type[#{ITERATOR}]"
          },
          'typeOfIncomeOverflow' => {
            question_num: 9,
            question_suffix: '(2)',
            question_text: 'INCOME TYPE'
          },
          'otherTypeExplanation' => {
            key: "Other_Specify_Type_Of_Income[#{ITERATOR}]",
            limit: 31,
            question_num: 9,
            question_suffix: '(2)',
            question_text: 'OTHER INCOME TYPE EXPLANATION'
          },
          # (3) Income Payer
          'payer' => {
            key: "Name_Of_Income_Payer[#{ITERATOR}]",
            limit: 25,
            question_num: 9,
            question_suffix: '(3)',
            question_text: 'PAYER NAME'
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
            question_text: 'CURRENT GROSS MONTHLY INCOME'
          }
        },
        # 10a
        'hasAnyExpenses' => {
          key: 'Has_Any_Expenses_Yes_No'
        },
        # 10b-d Care Expenses
        'careExpenses' => {
          limit: 3,
          first_key: 'childName',
          # (1) Recipient
          'recipients' => {
            key: "Care_Expenses.Recipient[#{ITERATOR}]"
          },
          'recipientsOverflow' => {
            question_num: 10.1,
            question_suffix: '[Care](1)',
            question_text: 'CARE EXPENSE RECIPIENT'
          },
          'childName' => {
            key: "Care_Expenses.Child_Specify[#{ITERATOR}]",
            limit: 45,
            question_num: 10.1,
            question_suffix: '[Care](1)',
            question_text: 'CARE EXPENSE CHILD NAME'
          },
          # (2) Provider
          'provider' => {
            key: "Care_Expenses.Name_Of_Provider[#{ITERATOR}]",
            limit: 70,
            question_num: 10.1,
            question_suffix: '[Care](2)',
            question_text: 'CARE EXPENSE PROVIDER NAME'
          },
          'careType' => {
            key: "Care_Expenses.Care_Type[#{ITERATOR}]"
          },
          'careTypeOverflow' => {
            question_num: 10.1,
            question_suffix: '[Care](2)',
            question_text: 'CARE TYPE'
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
            question_num: 10.1,
            question_suffix: '[Care](3)',
            question_text: 'CARE EXPENSE RATE PER HOUR'
          },
          'hoursPerWeek' => {
            limit: 3,
            question_num: 10.1,
            question_suffix: '[Care](3)',
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
            question_num: 10.1,
            question_suffix: '[Care](4)',
            question_text: 'DATE RANGE CARE RECEIVED'
          },
          'noCareEndDate' => {
            key: "Care_Expenses.CheckBox_No_End_Date[#{ITERATOR}]"
          },
          # (5) Payment Frequency
          'paymentFrequency' => {
            key: "Care_Expenses.Payment_Frequency[#{ITERATOR}]"
          },
          'paymentFrequencyOverflow' => {
            question_num: 10.1,
            question_suffix: '[Care](5)',
            question_text: 'CARE EXPENSE PAYMENT FREQUENCY'
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
            question_num: 10.1,
            question_suffix: '[Care](6)',
            question_text: 'CARE EXPENSE PAYMENT AMOUNT'
          }
        },
        # 10e-j Medical Expenses
        'medicalExpenses' => {
          limit: 6,
          first_key: 'childName',
          # (1) Recipient
          'recipients' => {
            key: "Med_Expenses.Recipient[#{ITERATOR}]"
          },
          'recipientsOverflow' => {
            question_num: 10.2,
            question_suffix: '[Medical](1)',
            question_text: 'MEDICAL EXPENSE RECIPIENT'
          },
          'childName' => {
            key: "Med_Expenses.Child_Specify[#{ITERATOR}]",
            limit: 45,
            question_num: 10.2,
            question_suffix: '[Medical](1)',
            question_text: 'MEDICAL EXPENSE CHILD NAME'
          },
          # (2) Provider
          'provider' => {
            key: "Med_Expenses.Paid_To[#{ITERATOR}]",
            limit: 108,
            question_num: 10.2,
            question_suffix: '[Medical](2)',
            question_text: 'MEDICAL EXPENSE PROVIDER NAME'
          },
          # (3) Purpose
          'purpose' => {
            key: "Med_Expenses.Purpose[#{ITERATOR}]",
            limit: 108,
            question_num: 10.2,
            question_suffix: '[Medical](3)',
            question_text: 'MEDICAL EXPENSE PURPOSE'
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
            question_num: 10.2,
            question_suffix: '[Medical](4)',
            question_text: 'MEDICAL EXPENSE PAYMENT DATE'
          },
          # (5) Payment Frequency
          'paymentFrequency' => {
            key: "Med_Expenses.Payment_Frequency[#{ITERATOR}]"
          },
          'paymentFrequencyOverflow' => {
            question_num: 10.2,
            question_suffix: '[Medical](5)',
            question_text: 'MEDICAL EXPENSE PAYMENT FREQUENCY'
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
            question_num: 10.2,
            question_suffix: '[Medical](6)',
            question_text: 'MEDICAL EXPENSE PAYMENT AMOUNT'
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

      ###
      # Merge all the key data together
      #
      def merge_fields(_options = {})
        expand_veteran_identification_information
        expand_veteran_contact_information
        expand_veteran_service_information
        expand_pension_information
        expand_employment_history
        expand_marital_status
        expand_prior_marital_history
        expand_dependent_children
        expand_income_and_assets
        expand_care_medical_expenses
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
        prev_names = @form_data['previousNames']

        @form_data['previousNames'] = prev_names.pluck('previousFullName') if prev_names.present?
        @form_data['activeServiceDateRange'] = {
          'from' => split_date(@form_data.dig('activeServiceDateRange', 'from')),
          'to' => split_date(@form_data.dig('activeServiceDateRange', 'to'))
        }
        @form_data['serviceBranch'] = @form_data['serviceBranch']&.select { |_, value| value == true }

        @form_data['pow'] = to_radio_yes_no(@form_data['powDateRange'].present?)
        if @form_data['pow'] == 1
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
        @form_data['medicaidStatus'] = to_radio_yes_no(
          @form_data['medicaidStatus'] || @form_data['medicaidCoverage']
        )
        @form_data['specialMonthlyPension'] = to_radio_yes_no(@form_data['specialMonthlyPension'])
        @form_data['medicalCondition'] = to_radio_yes_no(@form_data['medicalCondition'])
        @form_data['socialSecurityDisability'] = to_radio_yes_no(
          @form_data['socialSecurityDisability'] || @form_data['isOver65']
        )

        # If "YES," skip question 4B
        @form_data['medicalCondition'] = 'Off' if @form_data['socialSecurityDisability'] == 1

        # If "NO," skip question 4D
        @form_data['medicaidStatus'] = 'Off' if @form_data['nursingHome'] == 2

        @form_data['vaTreatmentHistory'] = to_radio_yes_no(@form_data['vaTreatmentHistory'])
        @form_data['federalTreatmentHistory'] = to_radio_yes_no(@form_data['federalTreatmentHistory'])
      end

      # SECTION V: EMPLOYMENT HISTORY
      def expand_employment_history
        @form_data['currentEmployment'] = to_radio_yes_no(@form_data['currentEmployment'])

        @form_data['previousEmployers'] = @form_data['previousEmployers']&.map do |pe|
          pe.merge({
                     'jobDate' => split_date(pe['jobDate']),
                     'jobDateOverflow' => to_date_string(pe['jobDate'])
                   })
        end

        @form_data['currentEmployers'] = nil if @form_data['currentEmployment'] == 2
      end

      # SECTION VI: MARITAL STATUS
      def expand_marital_status
        @form_data['maritalStatus'] = marital_status_to_radio(@form_data['maritalStatus'])
        @form_data['currentMarriage'] = get_current_marriage(@form_data['marriages'])
        @form_data['spouseDateOfBirth'] = split_date(@form_data['spouseDateOfBirth'])
        @form_data['spouseSocialSecurityNumber'] = split_ssn(@form_data['spouseSocialSecurityNumber'])
        if @form_data['maritalStatus'] != 2
          @form_data['spouseIsVeteran'] = to_radio_yes_no(@form_data['spouseIsVeteran'])
        end
        @form_data['spouseAddress'] ||= {}
        @form_data['spouseAddress']['postalCode'] = split_postal_code(@form_data['spouseAddress'])
        @form_data['currentSpouseMonthlySupport'] = split_currency_amount(@form_data['currentSpouseMonthlySupport'])
        @form_data['reasonForCurrentSeparation'] =
          reason_for_current_separation_to_radio(@form_data['reasonForCurrentSeparation'])
      end

      # Take a marital status and convert it to a radio selection.
      def marital_status_to_radio(marital_status)
        case marital_status
        when 'MARRIED' then 0
        when 'SEPARATED' then 1
        else 2
        end
      end

      # Get the current marriage
      def get_current_marriage(marriages)
        current_marriage_index = marriages&.index { |marriage| !marriage.key?('dateOfSeparation') }

        if current_marriage_index
          current_marriage = marriages[current_marriage_index].clone
          marriages.delete_at(current_marriage_index)
        else
          current_marriage = {}
        end

        return current_marriage if current_marriage.empty?

        marriage_type = current_marriage['marriageType']
        current_marriage['marriageType'] =
          marriage_type == 'CEREMONY' ? 0 : 1
        current_marriage['dateOfMarriage'] =
          split_date(current_marriage['dateOfMarriage'])
        current_marriage
      end

      # Get the current reason of separation to a radio box.
      def reason_for_current_separation_to_radio(reason_for_separation)
        case reason_for_separation
        when 'MEDICAL_CARE' then 0
        when 'RELATIONSHIP' then 1
        when 'LOCATION' then 2
        when 'OTHER' then 3
        else 'Off'
        end
      end

      # SECTION VII: PRIOR MARITAL HISTORY
      def expand_prior_marital_history
        @form_data['marriages'] = build_marital_history(@form_data['marriages'], 'VETERAN')
        @form_data['spouseMarriages'] = build_marital_history(@form_data['spouseMarriages'], 'SPOUSE')
        if @form_data['marriages']&.any?
          @form_data['additionalMarriages'] = to_radio_yes_no(@form_data['marriages'].length.to_i > 3)
        end
        if @form_data['spouseMarriages']&.any?
          @form_data['additionalSpouseMarriages'] = to_radio_yes_no(@form_data['spouseMarriages'].length.to_i > 2)
        end
      end

      # Build the marital history key data.
      def build_marital_history(marriages, marriage_for = 'VETERAN')
        return [] unless marriages.present? && %w[VETERAN SPOUSE].include?(marriage_for)

        marriages.map do |marriage|
          reason_for_separation = marriage['reasonForSeparation'].to_s
          marriage_date_range = {
            'from' => marriage['dateOfMarriage'],
            'to' => marriage['dateOfSeparation']
          }
          marriage.merge({ 'spouseFullNameOverflow' => marriage['spouseFullName']&.values&.join(' '),
                           'dateOfMarriage' => split_date(marriage['dateOfMarriage']),
                           'dateOfSeparation' => split_date(marriage['dateOfSeparation']),
                           'dateRangeOfMarriageOverflow' => build_date_range_string(marriage_date_range),
                           'reasonForSeparation' => Constants::REASONS_FOR_SEPARATION[reason_for_separation],
                           'reasonForSeparationOverflow' => reason_for_separation.humanize })
        end
      end

      # SECTION VIII: DEPENDENT CHILDREN
      def expand_dependent_children
        @form_data['dependentChildrenInHousehold'] = select_children_in_household(@form_data['dependents'])
        @form_data['dependents'] = @form_data['dependents']&.map { |dependent| dependent_to_hash(dependent) }
        # 8Q Do all children not living with you reside at the same address?
        custodian_addresses = {}
        dependents_not_in_household = @form_data['dependents']&.reject { |dep| dep['childInHousehold'] } || []
        dependents_not_in_household.each do |dependent|
          custodian_key = dependent['personWhoLivesWithChild'].values.join('_')
          if custodian_addresses[custodian_key].nil?
            custodian_addresses[custodian_key] = build_custodian_hash_from_dependent(dependent)
          else
            custodian_addresses[custodian_key]['dependentsWithCustodianOverflow'] +=
              ", #{dependent['fullName']&.values&.join(' ')}"
          end
        end
        if custodian_addresses.any?
          @form_data['dependentsNotWithYouAtSameAddress'] = to_radio_yes_no(custodian_addresses.length == 1)
        end
        @form_data['custodians'] = custodian_addresses.values
      end

      # Build the custodian data from dependents
      def build_custodian_hash_from_dependent(dependent)
        dependent['personWhoLivesWithChild']
          .merge({
                   'custodianAddress' => dependent['childAddress'].merge(
                     'postalCode' => split_postal_code(dependent['childAddress'])
                   )
                 })
          .merge({
                   'custodianAddressOverflow' => build_address_string(dependent['childAddress']),
                   'dependentsWithCustodianOverflow' => dependent['fullName']&.values&.join(' ')
                 })
      end

      # Create an address string from an address hash
      def build_address_string(address)
        return '' if address.blank?

        country = address['country'].present? ? "#{address['country']}, " : ''
        address_arr = [
          address['street'].to_s, address['street2'].presence,
          "#{address['city']}, #{address['state']}, #{country}#{address['postalCode']}"
        ].compact

        address_arr.join("\n")
      end

      # Select the children in a household of the dependents.
      def select_children_in_household(dependents)
        return unless dependents&.any?

        dependents.select do |dependent|
          dependent['childInHousehold']
        end.length.to_s
      end

      # Build a string to represent the dependents status.
      def child_status_overflow(dependent)
        child_status_overflow = [dependent['childRelationship']&.humanize]
        child_status_overflow << 'seriously disabled' if dependent['disabled']
        child_status_overflow << '18-23 years old (in school)' if dependent['attendingCollege']
        child_status_overflow << 'previously married' if dependent['previouslyMarried']
        child_status_overflow << 'does not live with you but contributes' unless dependent['childInHousehold']
        child_status_overflow
      end

      # Create a hash table from a dependent that outlines all the data joined and formatted together.
      def dependent_to_hash(dependent)
        dependent
          .merge({
                   'fullNameOverflow' => dependent['fullName']&.values&.join(' '),
                   'childDateOfBirth' => split_date(dependent['childDateOfBirth']),
                   'childDateOfBirthOverflow' => to_date_string(dependent['childDateOfBirth']),
                   'childSocialSecurityNumber' => split_ssn(dependent['childSocialSecurityNumber']),
                   'childSocialSecurityNumberOverflow' => dependent['childSocialSecurityNumber'],
                   'childRelationship' => {
                     'biological' => to_checkbox_on_off(dependent['childRelationship'] == 'BIOLOGICAL'),
                     'adopted' => to_checkbox_on_off(dependent['childRelationship'] == 'ADOPTED'),
                     'stepchild' => to_checkbox_on_off(dependent['childRelationship'] == 'STEP_CHILD')
                   },
                   'disabled' => to_checkbox_on_off(dependent['disabled']),
                   'attendingCollege' => to_checkbox_on_off(dependent['attendingCollege']),
                   'previouslyMarried' => to_checkbox_on_off(dependent['previouslyMarried']),
                   'childNotInHousehold' => to_checkbox_on_off(!dependent['childInHousehold']),
                   'childStatusOverflow' => child_status_overflow(dependent).join(', '),
                   'monthlyPayment' => split_currency_amount(dependent['monthlyPayment']),
                   'monthlyPaymentOverflow' => number_to_currency(dependent['monthlyPayment'])
                 })
      end

      # SECTION IX: INCOME AND ASSETS
      def expand_income_and_assets
        @form_data['totalNetWorth'] = to_radio_yes_no(@form_data['totalNetWorth'])
        if @form_data['netWorthEstimation']
          @form_data['netWorthEstimation'] =
            split_currency_amount(@form_data['netWorthEstimation'])
        end
        @form_data['transferredAssets'] = to_radio_yes_no(@form_data['transferredAssets'])
        @form_data['homeOwnership'] = to_radio_yes_no(@form_data['homeOwnership'])
        if @form_data['homeOwnership'] == 1
          @form_data['homeAcreageMoreThanTwo'] = to_radio_yes_no(@form_data['homeAcreageMoreThanTwo'])
          @form_data['landMarketable'] = to_radio_yes_no(@form_data['landMarketable'])
        end
        if @form_data['homeAcreageValue'].present?
          @form_data['homeAcreageValue'] =
            split_currency_amount(@form_data['homeAcreageValue'])
        end
        @form_data['moreThanFourIncomeSources'] =
          to_radio_yes_no(@form_data['incomeSources'].present? && @form_data['incomeSources'].length > 4)
        @form_data['incomeSources'] = merge_income_sources(@form_data['incomeSources'])
      end

      # Merge all income sources together and normalize the data.
      def merge_income_sources(income_sources)
        income_sources&.map do |income_source|
          income_source_hash = {
            'receiver' => Constants::RECIPIENTS[income_source['receiver']],
            'receiverOverflow' => income_source['receiver']&.humanize,
            'typeOfIncome' => Constants::INCOME_TYPES[income_source['typeOfIncome']],
            'typeOfIncomeOverflow' => income_source['typeOfIncome']&.humanize,
            'amount' => split_currency_amount(income_source['amount']),
            'amountOverflow' => number_to_currency(income_source['amount'])
          }
          if income_source['dependentName'].present?
            income_source_hash['dependentName'] =
              income_source['dependentName']
          end
          income_source.merge(income_source_hash)
        end
      end

      # SECTION X: CARE/MEDICAL EXPENSES
      def expand_care_medical_expenses
        @form_data['hasAnyExpenses'] =
          to_radio_yes_no(@form_data['hasCareExpenses'] || @form_data['hasMedicalExpenses'])
        @form_data['careExpenses'] = merge_care_expenses(@form_data['careExpenses'])
        @form_data['medicalExpenses'] = merge_medical_expenses(@form_data['medicalExpenses'])
      end

      # Map over the care expenses and expand the data out.
      def merge_care_expenses(care_expenses)
        care_expenses&.map do |care_expense|
          care_expense.merge(care_expense_to_hash(care_expense))
        end
      end

      # Expand a care expense data hash.
      def care_expense_to_hash(care_expense)
        {
          'recipients' => Constants::RECIPIENTS[care_expense['recipients']],
          'recipientsOverflow' => care_expense['recipients']&.humanize,
          'careType' => Constants::CARE_TYPES[care_expense['careType']],
          'careTypeOverflow' => care_expense['careType']&.humanize,
          'ratePerHour' => split_currency_amount(care_expense['ratePerHour']),
          'ratePerHourOverflow' => number_to_currency(care_expense['ratePerHour']),
          'hoursPerWeek' => care_expense['hoursPerWeek'].to_s,
          'careDateRange' => {
            'from' => split_date(care_expense.dig('careDateRange', 'from')),
            'to' => split_date(care_expense.dig('careDateRange', 'to'))
          },
          'careDateRangeOverflow' => build_date_range_string(care_expense['careDateRange']),
          'noCareEndDate' => to_checkbox_on_off(care_expense['noCareEndDate']),
          'paymentFrequency' => Constants::PAYMENT_FREQUENCY[care_expense['paymentFrequency']],
          'paymentFrequencyOverflow' => care_expense['paymentFrequency'],
          'paymentAmount' => split_currency_amount(care_expense['paymentAmount']),
          'paymentAmountOverflow' => number_to_currency(care_expense['paymentAmount'])
        }
      end

      # Map over medical expenses and create a set of data.
      def merge_medical_expenses(medical_expenses)
        medical_expenses&.map do |medical_expense|
          medical_expense.merge({
                                  'recipients' => Constants::RECIPIENTS[medical_expense['recipients']],
                                  'recipientsOverflow' => medical_expense['recipients']&.humanize,
                                  'paymentDate' => split_date(medical_expense['paymentDate']),
                                  'paymentDateOverflow' => to_date_string(medical_expense['paymentDate']),
                                  'paymentFrequency' =>
                                    Constants::PAYMENT_FREQUENCY[medical_expense['paymentFrequency']],
                                  'paymentFrequencyOverflow' => medical_expense['paymentFrequency'],
                                  'paymentAmount' => split_currency_amount(medical_expense['paymentAmount']),
                                  'paymentAmountOverflow' => number_to_currency(
                                    medical_expense['paymentAmount']
                                  )
                                })
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
        # signed on provided date (generally SavedClaim.created_at) or default to today
        signature_date = @form_data['signatureDate'] || Time.zone.now.strftime('%Y-%m-%d')
        @form_data['signatureDate'] = split_date(signature_date)
      end

      # Convert a date to a string
      def to_date_string(date)
        date_hash = split_date(date)
        return unless date_hash

        "#{date_hash['month']}-#{date_hash['day']}-#{date_hash['year']}"
      end

      # Build a date range string from a date range object
      def build_date_range_string(date_range)
        "#{to_date_string(date_range['from'])} - #{to_date_string(date_range['to']) || 'No End Date'}"
      end

      # Split up currency amounts to three parts.
      def split_currency_amount(amount)
        return {} if amount.nil? || amount.negative? || amount >= 10_000_000

        number_map = {
          1 => 'one',
          2 => 'two',
          3 => 'three'
        }

        arr = number_to_currency(amount).to_s.split(/[,.$]/).reject(&:empty?)
        split_hash = { 'part_cents' => arr.last }
        arr.pop
        arr.each_with_index { |x, i| split_hash["part_#{number_map[arr.length - i]}"] = x }
        split_hash
      end

      # Convert an objects truthiness to a radio on/off.
      def to_checkbox_on_off(obj)
        obj ? 1 : 'Off'
      end

      # Convert an objects truthiness to a radio yes/no.
      def to_radio_yes_no(obj)
        obj ? 1 : 2
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
