# frozen_string_literal: true

require 'pdf_fill/hash_converter'
require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'string_helpers'

require_relative 'constants'

# Sections
require_relative 'sections/section_05'
require_relative 'sections/section_06'
require_relative 'sections/section_07'
require_relative 'sections/section_08'
require_relative 'sections/section_09'
require_relative 'sections/section_10'
require_relative 'sections/section_11'
require_relative 'sections/section_12'

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
        { question_number: '4', question_text: 'VA Medical Centers' },
        { question_number: '4g', question_text: 'Federal Medical Facilities' },
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
        }
      }.freeze

      # The list of section classes for form expansion and key building
      SECTION_CLASSES = [Section5, Section6, Section7, Section8, Section9, Section10, Section11, Section12].freeze

      # Sections 7 - 12
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

        # Sections 7 - 12
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
    end
  end
end
# rubocop:enable Metrics/MethodLength
