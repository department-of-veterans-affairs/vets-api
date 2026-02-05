# frozen_string_literal: true

require 'survivors_benefits/pdf_fill/section'

require_relative '../../constants'

module SurvivorsBenefits
  module PdfFill
    # Section 2: Claimants's Identification Information
    class Section2 < Section
      include ::PdfFill::Forms::FormHelper
      include ::PdfFill::Forms::FormHelper::PhoneNumberFormatting
      include Helpers

      # Section configuration hash
      KEY = {
        'claimantFullName' => {
          'first' => {
            limit: 12,
            question_num: 1,
            question_suffix: 'A',
            question_label: 'Claimant\'s First Name',
            question_text: 'CLAIMANT\'S FIRST NAME',
            key: 'form1[0].#subform[207].ClaimantsFirstName[0]'
          },
          'middle' => {
            limit: 1,
            question_num: 1,
            question_suffix: 'A',
            key: 'form1[0].#subform[207].ClaimantsMiddleInitial1[0]'
          },
          'last' => {
            limit: 18,
            question_num: 1,
            question_suffix: 'A',
            question_label: 'Claimant\'s Last Name',
            question_text: 'CLAIMANTS\'S LAST NAME',
            key: 'form1[0].#subform[207].ClaimantsLastName[0]'
          }
        },
        'claimantRelationship' => {
          key: 'form1[0].#subform[207].RadioButtonList[2]'
        },
        # 1b
        'claimantSocialSecurityNumber' => {
          'first' => {
            key: 'form1[0].#subform[207].ClaimantsSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'form1[0].#subform[207].ClaimantsSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[207].ClaimantsSocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        'claimantDateOfBirth' => {
          'month' => {
            key: 'form1[0].#subform[207].DOBmonth[1]'
          },
          'day' => {
            key: 'form1[0].#subform[207].DOBday[1]'
          },
          'year' => {
            key: 'form1[0].#subform[207].DOByear[1]'
          }
        },
        # 1d
        'claimantIsVeteran' => {
          key: 'form1[0].#subform[207].RadioButtonList[3]'
        },
        'claimantAddress' => {
          'street' => {
            limit: 30,
            question_num: 2,
            question_suffix: 'F',
            question_label: 'Mailing Address Number And Street',
            question_text: 'MAILING ADDRESS NUMBER AND STREET',
            key: 'form1[0].#subform[207].NumberStreet[0]'
          },
          'street2' => {
            limit: 5,
            question_num: 2,
            question_suffix: 'F',
            question_label: 'Mailing Address Apt/Unit',
            question_text: 'MAILING ADDRESS APT/UNIT',
            key: 'form1[0].#subform[207].Apt_Or_Unit_Number[0]'
          },
          'city' => {
            limit: 18,
            question_num: 2,
            question_suffix: 'F',
            question_label: 'Mailing Address City',
            question_text: 'MAILING ADDRESS CITY',
            key: 'form1[0].#subform[207].City[0]'
          },
          'state' => {
            key: 'form1[0].#subform[207].State_Province[0]'
          },
          'country' => {
            key: 'form1[0].#subform[207].Country[0]'
          },
          'postalCode' => {
            'firstFive' => {
              key: 'form1[0].#subform[207].Zip_Postal_Code[0]'
            },
            'lastFour' => {
              limit: 4,
              question_num: 2,
              question_suffix: 'F',
              question_label: 'Postal Code - Last Four',
              question_text: 'POSTAL CODE - LAST FOUR',
              key: 'form1[0].#subform[207].Zip_Postal_Code[1]'
            }
          }
        },
        'claimantPhone' => {
          'phone_area_code' => {
            key: 'form1[0].#subform[207].Telephone_Number_First_Three_Numbers[0]'
          },
          'phone_first_three_numbers' => {
            key: 'form1[0].#subform[207].Telephone_Number_Second_Three_Numbers[0]'
          },
          'phone_last_four_numbers' => {
            key: 'form1[0].#subform[207].Telephone_Number_Last_Four_Numbers[0]'
          }
        },
        'claimantInternationalPhone' => {
          key: 'form1[0].#subform[207].International_Telephone_Number[0]'
        },
        'claimantEmail' => {
          limit: 32,
          question_num: 2,
          question_suffix: 'H',
          question_label: 'Claimant Email Address (Optional)',
          question_text: 'CLAIMANT EMAIL ADDRESS (OPTIONAL)',
          key: 'form1[0].#subform[207].Email_Address_Optional[0]'
        },
        'claims' => {
          'DIC' => {
            key: 'form1[0].#subform[207].Dependency_And_Indemnity_Compensation_DIC[0]'
          },
          'survivorsPension' => {
            key: 'form1[0].#subform[207].Survivors_Pension[0]'
          },
          'accruedBenefits' => {
            key: 'form1[0].#subform[207].Accrued_Benefits[0]'
          }
        }
      }.freeze

      def expand(form_data = {})
        form_data['claimantFullName'] ||= {}
        form_data['claimantFullName']['first'] = form_data.dig('claimantFullName', 'first')&.titleize
        form_data['claimantFullName']['middle'] = form_data.dig('claimantFullName', 'middle')&.first&.titleize
        form_data['claimantFullName']['last'] = form_data.dig('claimantFullName', 'last')&.titleize
        form_data['claimantRelationship'] = relationship_to_radio(form_data['claimantRelationship'])
        form_data['claimantSocialSecurityNumber'] = split_ssn(form_data['claimantSocialSecurityNumber'])
        form_data['claimantDateOfBirth'] = split_date(form_data['claimantDateOfBirth'])
        form_data['claimantIsVeteran'] = to_radio_yes_no(form_data['claimantIsVeteran'])
        form_data['claimantAddress'] ||= {}
        form_data['claimantAddress']['postalCode'] =
          split_postal_code(form_data['claimantAddress'])
        form_data['claimantPhone'] = expand_phone_number(form_data['claimantPhone'].to_s)

        form_data
      end

      def relationship_to_radio(relationship)
        if Constants::RELATIONSHIPS.include?(relationship)
          relationship&.humanize&.upcase
        else
          'Off'
        end
      end

      def to_radio_yes_no(obj)
        case obj
        when true then 'YES'
        when false then 'NO'
        else 'Off'
        end
      end
    end
  end
end
