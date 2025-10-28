# frozen_string_literal: true

require 'pdf_fill/hash_converter'
require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'string_helpers'

require_relative 'constants'

# Sections
require_relative 'sections/section_08'
require_relative 'sections/section_09'
require_relative 'sections/section_10'
require_relative 'sections/section_11'
require_relative 'sections/section_12'

# rubocop:disable Metrics/ClassLength
# rubocop:disable Metrics/MethodLength
module Pensions
  module PdfFill
    # The Va21p527ez Form
    class Va21p527ez < ::PdfFill::Forms::FormBase
      include ::PdfFill::Forms::FormHelper
      include ::PdfFill::Forms::FormHelper::PhoneNumberFormatting
      include Helpers

      # The Form ID
      FORM_ID = Pensions::FORM_ID

      # The PDF Template
      TEMPLATE = "#{Pensions::MODULE_PATH}/lib/pensions/pdf_fill/pdfs/21P-527EZ.pdf".freeze

      # The Index Iterator Key
      ITERATOR = ::PdfFill::HashConverter::ITERATOR

      # Starting page number for overflow pages
      START_PAGE = 16

      # Default label column width (points) for redesigned extras in this form
      DEFAULT_LABEL_WIDTH = 130

      # Map question numbers to descriptive titles for overflow attachments
      QUESTION_KEY = [
        { question_number: '1', question_text: "Veteran's Identification Information" },
        { question_number: '2', question_text: "Veteran's Contact Information" },
        { question_number: '3', question_text: "Veteran's Service Information" },
        { question_number: '4', question_text: 'Pension Information' },
        { question_number: '5', question_text: 'Employment History' },
        { question_number: '6', question_text: 'Marital Status' },
        { question_number: '7', question_text: 'Prior Marital History' },
        { question_number: '8', question_text: 'Dependent Children' },
        { question_number: '9', question_text: 'Income and Assets' },
        { question_number: '10', question_text: 'Care/Medical Expenses' },
        { question_number: '11', question_text: 'Direct Deposit Information' },
        { question_number: '12', question_text: 'Claim Certification and Signature' }
      ].freeze

      # V2-style sections grouping question numbers for overflow pages
      SECTIONS = [
        { label: 'Section I: Veteran\'s Identification Information', question_nums: ['1'] },
        { label: 'Section II: Veteran\'s Contact Information', question_nums: ['2'] },
        { label: 'Section III: Veteran\'s Service Information', question_nums: ['3'] },
        { label: 'Section IV: Pension Information', question_nums: ['4'] },
        { label: 'Section V: Employment History', question_nums: ['5'] },
        { label: 'Section VI: Marital Status', question_nums: ['6'] },
        { label: 'Section VII: Prior Marital History', question_nums: ['7'] },
        { label: 'Section VIII: Dependent Children', question_nums: ['8'] },
        { label: 'Section IX: Income and Assets', question_nums: ['9'] },
        { label: 'Section X: Care/Medical Expenses', question_nums: ['10'] },
        { label: 'Section XI: Direct Deposit Information', question_nums: ['11'] },
        { label: 'Section XII: Claim Certification and Signature', question_nums: ['12'] }
      ].freeze

      # The PDF Keys
      key = {
        # 1a
        'veteranFullName' => {
          'first' => {
            limit: 12,
            question_num: 1,
            question_suffix: 'A',
            question_label: "Veteran's First Name",
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
            question_label: "Veteran's Last Name",
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
            question_label: 'Mailing Address Number And Street',
            question_text: 'MAILING ADDRESS NUMBER AND STREET',
            key: 'form1[0].#subform[48].NumberStreet[0]'
          },
          'street2' => {
            limit: 5,
            question_num: 2,
            question_suffix: 'A',
            question_label: 'Mailing Address Apt/Unit',
            question_text: 'MAILING ADDRESS APT/UNIT',
            key: 'form1[0].#subform[48].Apt_Or_Unit_Number[0]'
          },
          'city' => {
            limit: 18,
            question_num: 2,
            question_suffix: 'A',
            question_label: 'Mailing Address City',
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
              question_label: 'Postal Code - Last Four',
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
          question_label: 'International Phone Number',
          question_text: 'International Phone Number',
          key: 'form1[0].#subform[48].International_Phone_Number[0]'
        },
        # 2c
        'email' => {
          limit: 32,
          question_num: 2,
          question_suffix: 'C',
          question_label: "Veteran's E-Mail Address",
          question_text: 'VETERAN\'S E-MAIL ADDRESS',
          key: 'form1[0].#subform[48].Veterans_Email_Address_Optional[0]'
        },
        # 3a
        'previousNames' => {
          item_label: 'Other service name',
          limit: 1,
          first_key: 'first',
          'first' => {
            limit: 12,
            question_num: 3,
            question_suffix: 'A',
            question_label: 'Other First Name',
            question_text: 'OTHER FIRST NAME',
            key: "form1[0].#subform[48].Other_Name_You_Served_Under_First_Name[#{ITERATOR}]"
          },
          'last' => {
            limit: 18,
            question_num: 3,
            question_suffix: 'A',
            question_label: 'Other Last Name',
            question_text: 'OTHER LAST NAME',
            key: "form1[0].#subform[48].Other_Name_You_Served_Under_Last_Name[#{ITERATOR}]"
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
          key: 'form1[0].#subform[48].Your_Service_Number[0]'
        },
        # 3f
        'placeOfSeparationLineOne' => {
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
          item_label: 'VA medical center',
          limit: 1,
          first_key: 'medicalCenter',
          'medicalCenter' => {
            limit: 33,
            question_num: 4,
            question_suffix: 'F',
            question_label: 'Specify VA Facility',
            question_text: 'Specify VA Facility',
            key: 'form1[0].#subform[49].Facility[0]'
          }
        },
        # 4g
        'federalTreatmentHistory' => {
          key: 'form1[0].#subform[49].RadioButtonList[8]'
        },
        'federalMedicalCenters' => {
          item_label: 'Federal medical facility',
          limit: 1,
          first_key: 'medicalCenter',
          'medicalCenter' => {
            limit: 44,
            question_num: 4,
            question_suffix: 'G',
            question_label: 'Specify Federal Facility',
            question_text: 'Specify Federal Facility',
            key: 'form1[0].#subform[49].Facility[1]'
          }
        },
        # 5a
        'currentEmployment' => {
          key: 'form1[0].#subform[49].RadioButtonList[9]'
        },
        'currentEmployers' => {
          item_label: 'Current job',
          limit: 1,
          first_key: 'jobType',
          # 5b
          'jobType' => {
            limit: 35,
            question_num: 5,
            question_suffix: 'B',
            question_label: 'What Kind Of Work Are You Currently Doing',
            question_text: 'WHAT KIND OF WORK ARE YOU CURRENTLY DOING',
            key: 'form1[0].#subform[49].What_Kind_Of_Work_Are_You_Currently_Doing[0]'
          },
          # 5c
          'jobHoursWeek' => {
            limit: 3,
            question_num: 5,
            question_suffix: 'B',
            question_label: 'How Many Hours Per Week Do You Average',
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
            question_label: 'When Did You Last Work',
            question_text: 'WHEN DID YOU LAST WORK'
          },
          # 5e
          'jobHoursWeek' => {
            limit: 3,
            question_num: 5,
            question_suffix: 'E',
            question_label: 'How Many Hours Per Week Did You Average',
            question_text: 'HOW MANY HOURS PER WEEK DID YOU AVERAGE',
            key: 'form1[0].#subform[49].How_Many_Hours_Per_Week_Did_You_Average[0]'
          },
          # 5f
          'jobTitle' => {
            limit: 30,
            question_num: 5,
            question_suffix: 'F',
            question_label: 'What Was Your Job Title',
            question_text: 'WHAT WAS YOUR JOB TITLE',
            key: 'form1[0].#subform[49].What_Was_Your_Job_Title[0]'
          },
          # 5g
          'jobType' => {
            limit: 27,
            question_num: 5,
            question_suffix: 'G',
            question_label: 'What Kind Of Work Did You Do',
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
              question_label: "Spouse's Current First Name",
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
              question_label: "Spouse's Current Last Name",
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
            question_label: 'Place Of Marriage City And State Or Country',
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
            question_label: 'Specify Type Of Marriage',
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
            question_label: 'Spouse Mailing Address Street',
            question_text: 'SPOUSE MAILING ADDRESS STREET',
            key: 'form1[0].#subform[49].Number_And_Street[0]'
          },
          'street2' => {
            limit: 5,
            question_num: 6,
            question_suffix: 'J',
            question_label: 'Spouse Mailing Address Apt Number',
            question_text: 'SPOUSE MAILING ADDRESS APT NUMBER',
            key: 'form1[0].#subform[49].Apt_Or_Unit_Number[1]'
          },
          'city' => {
            limit: 18,
            question_num: 6,
            question_suffix: 'J',
            question_label: 'Spouse Mailing Address City',
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
              question_label: 'Who Were You Married To? (First Name)',
              question_text: 'WHO WERE YOU MARRIED TO? (FIRST NAME)',
              key: "Marriages.Veterans_Prior_Spouse_FirstName[#{ITERATOR}]"
            },
            'middle' => {
              question_num: 7.1,
              question_suffix: '[Veteran]',
              question_label: 'Who Were You Married To? (Middle Name)',
              question_text: 'WHO WERE YOU MARRIED TO? (MIDDLE NAME)',
              key: "Marriages.Veterans_Prior_Spouse_MiddleInitial1[#{ITERATOR}]"
            },
            'last' => {
              limit: 18,
              question_num: 7.1,
              question_suffix: '[Veteran]',
              question_label: 'Who Were You Married To? (Last Name)',
              question_text: 'WHO WERE YOU MARRIED TO? (LAST NAME)',
              key: "Marriages.Veterans_Prior_Spouse_LastName[#{ITERATOR}]"
            }
          },
          'spouseFullNameOverflow' => {
            question_num: 7.1,
            question_suffix: '[Veteran]',
            question_label: '(1) Who Were You Married To?',
            question_text: '(1) WHO WERE YOU MARRIED TO?'
          },
          'reasonForSeparation' => {
            key: "Marriages.Previous_Marriage_End_Reason[#{ITERATOR}]"
          },
          'reasonForSeparationOverflow' => {
            question_num: 7.1,
            question_suffix: '[Veteran]',
            question_label: '(2) How Did Your Previous Marriage End?',
            question_text: '(2) HOW DID YOUR PREVIOUS MARRIAGE END?'
          },
          'otherExplanation' => {
            limit: 43,
            question_num: 7.1,
            question_suffix: '[Veteran]',
            question_label: '(2) How Did Your Previous Marriage End (Other Reason)?',
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
            question_label: '(3) What Are The Dates Of The Previous Marriage?',
            question_text: '(3) WHAT ARE THE DATES OF THE PREVIOUS MARRIAGE?'
          },
          'locationOfMarriage' => {
            limit: 63,
            question_num: 7.1,
            question_suffix: '[Veteran]',
            question_label: '(4) Place Of Marriage',
            question_text: '(4) PLACE OF MARRIAGE',
            key: "Marriages.Place_Of_Marriage_City_And_State_Or_Country[#{ITERATOR}]"
          },
          'locationOfSeparation' => {
            limit: 54,
            question_num: 7.1,
            question_suffix: '[Veteran]',
            question_label: '(5) Place Of Marriage Termination',
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
              question_label: 'Who Was Your Spouse Married To? (First Name)',
              question_text: 'WHO WAS YOUR SPOUSE MARRIED TO? (FIRST NAME)',
              key: "Spouse_Marriages.Spouses_Prior_Spouse_FirstName[#{ITERATOR}]"
            },
            'middle' => {
              question_num: 7.2,
              question_suffix: '[Spouse]',
              question_label: 'Who Was Your Spouse Married To? (Middle Name)',
              question_text: 'WHO WAS YOUR SPOUSE MARRIED TO? (MIDDLE NAME)',
              key: "Spouse_Marriages.Spouses_Prior_Spouse_MiddleInitial1[#{ITERATOR}]"
            },
            'last' => {
              limit: 18,
              question_num: 7.2,
              question_suffix: '[Spouse]',
              question_label: 'Who Was Your Spouse Married To? (Last Name)',
              question_text: 'WHO WAS YOUR SPOUSE MARRIED TO? (LAST NAME)',
              key: "Spouse_Marriages.Spouses_Prior_Spouse_LastName[#{ITERATOR}]"
            }
          },
          'spouseFullNameOverflow' => {
            question_num: 7.2,
            question_suffix: '[Spouse]',
            question_label: '(1) Who Was Your Spouse You Married To?',
            question_text: '(1) WHO WAS YOUR SPOUSE YOU MARRIED TO?'
          },
          'reasonForSeparation' => {
            key: "Spouse_Marriages.Previous_Marriage_End_Reason[#{ITERATOR}]"
          },
          'reasonForSeparationOverflow' => {
            question_num: 7.2,
            question_suffix: '[Spouse]',
            question_label: '(2) How Did The Previous Marriage End?',
            question_text: '(2) HOW DID THE PREVIOUS MARRIAGE END?'
          },
          'otherExplanation' => {
            limit: 43,
            question_num: 7.2,
            question_suffix: '[Spouse]',
            question_label: '(2) How Did The Previous Marriage End (Other Reason)?',
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
            question_label: '(3) What Are The Dates Of The Previous Marriage?',
            question_text: '(3) WHAT ARE THE DATES OF THE PREVIOUS MARRIAGE?'
          },
          'locationOfMarriage' => {
            limit: 63,
            question_num: 7.2,
            question_suffix: '[Spouse]',
            question_label: '(4) Place Of Marriage',
            question_text: '(4) PLACE OF MARRIAGE',
            key: "Spouse_Marriages.Place_Of_Marriage_City_And_State_Or_Country[#{ITERATOR}]"
          },
          'locationOfSeparation' => {
            limit: 54,
            question_num: 7.2,
            question_suffix: '[Spouse]',
            question_label: '(5) Place Of Marriage Termination',
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
          question_label: 'Number of Dependent Children Who Live With You',
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
              question_label: "Child's First Name",
              question_text: 'CHILD\'S FIRST NAME',
              key: "Dependent_Children.Childs_FirstName[#{ITERATOR}]"
            },
            'middle' => {
              question_num: 8.1,
              question_label: "Child's Middle Name",
              question_text: 'CHILD\'S MIDDLE NAME',
              key: "Dependent_Children.Childs_MiddleInitial1[#{ITERATOR}]"
            },
            'last' => {
              limit: 18,
              question_num: 8.1,
              question_label: "Child's Last Name",
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
            question_label: "(2) Child's Date Of Birth",
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
            question_label: "(4) Child's Social Security Number",
            question_text: '(4) CHILD\'S SOCIAL SECURITY NUMBER'
          },
          'childPlaceOfBirth' => {
            limit: 60,
            question_num: 8.1,
            question_label: "(3) Child's Place Of Birth",
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
            question_label: "(5) Child's Status",
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
            question_label: '(6) Amount Of Contribution For Child',
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
            question_label: "Custodian's First Name",
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
            question_label: "Custodian's Last Name",
            question_text: 'CUSTODIAN\'S LAST NAME',
            key: 'form1[0].#subform[51].Custodians_LastName[0]'
          },
          'custodianAddress' => {
            'street' => {
              limit: 30,
              question_num: 8.2,
              question_suffix: 'R',
              question_label: "Custodian's Address Number and Street",
              question_text: 'CUSTODIAN\'S ADDRESS NUMBER AND STREET',
              key: 'form1[0].#subform[51].NumberStreet[3]'
            },
            'street2' => {
              limit: 5,
              question_num: 8.2,
              question_suffix: 'R',
              question_label: "Custodian's Address Apt/Unit",
              question_text: 'CUSTODIAN\'S ADDRESS APT/UNIT',
              key: 'form1[0].#subform[51].Apt_Or_Unit_Number[2]'
            },
            'city' => {
              limit: 18,
              question_num: 8.2,
              question_suffix: 'R',
              question_label: "Custodian's Address City",
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
            question_label: "Custodian's Address",
            question_text: 'CUSTODIAN\'S ADDRESS'
          },
          'dependentsWithCustodianOverflow' => {
            question_num: 8.2,
            question_suffix: 'R',
            question_label: 'Dependents Living With This Custodian',
            question_text: 'DEPENDENTS LIVING WITH THIS CUSTODIAN'
          }
        }
      }.freeze

      # The list of section classes for form expansion and key building
      SECTION_CLASSES = [Section8, Section9, Section10, Section11, Section12].freeze

      SECTION_CLASSES.each { |section| key = key.merge(section::KEY) }

      # form configuration hash
      KEY = key.freeze

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

        # Section 12
        SECTION_CLASSES.each { |section| section.new.expand(form_data) }

        @form_data
      end

      # SECTION I: VETERAN'S IDENTIFICATION INFORMATION
      def expand_veteran_identification_information
        middle_initial = @form_data.dig('veteranFullName', 'middle').try(:[], 0)
        @form_data['veteranFullName'] ||= {}
        @form_data['veteranFullName']['first'] = @form_data.dig('veteranFullName', 'first')&.titleize
        @form_data['veteranFullName']['middle'] = middle_initial || ''
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
        @form_data['veteranAddress']['country'] = @form_data.dig('veteranAddress', 'country')&.slice(0, 2)
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
        @form_data['serviceBranch'] = @form_data['serviceBranch']&.each_key { |k| @form_data['serviceBranch'][k] = '1' }

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
        @form_data['medicaidStatus'] = to_radio_yes_no(
          @form_data['medicaidStatus'] || @form_data['medicaidCoverage']
        )
        @form_data['specialMonthlyPension'] = to_radio_yes_no(@form_data['specialMonthlyPension'])
        @form_data['medicalCondition'] = to_radio_yes_no(@form_data['medicalCondition'])
        @form_data['socialSecurityDisability'] = to_radio_yes_no(
          @form_data['socialSecurityDisability'] || @form_data['isOver65']
        )

        # If "YES," skip question 4B
        @form_data['medicalCondition'] = nil if @form_data['socialSecurityDisability'].zero?

        # If "NO," skip question 4D
        @form_data['medicaidStatus'] = nil if @form_data['nursingHome'] == 1

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

        @form_data['currentEmployers'] = nil if @form_data['currentEmployment'] == 1
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
        @form_data['spouseAddress']['country'] = @form_data.dig('spouseAddress', 'country')&.slice(0, 2)
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

        middle_initial = current_marriage.dig('spouseFullName', 'middle')&.first
        current_marriage['spouseFullName']['middle'] = middle_initial
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
          marriage.merge!({ 'spouseFullNameOverflow' => marriage['spouseFullName']&.values&.join(' '),
                            'dateOfMarriage' => split_date(marriage['dateOfMarriage']),
                            'dateOfSeparation' => split_date(marriage['dateOfSeparation']),
                            'dateRangeOfMarriageOverflow' => build_date_range_string(marriage_date_range),
                            'reasonForSeparation' => Constants::REASONS_FOR_SEPARATION[reason_for_separation],
                            'reasonForSeparationOverflow' => reason_for_separation.humanize })
          marriage['spouseFullName']['middle'] = marriage['spouseFullName']['middle']&.first
          marriage
        end
      end
    end
  end
end
# rubocop:enable Metrics/MethodLength
# rubocop:enable Metrics/ClassLength
