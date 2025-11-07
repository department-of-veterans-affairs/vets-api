# frozen_string_literal: true

require 'survivors_benefits/pdf_fill/section'

module SurvivorsBenefits
  module PdfFill
    # Section I: Veteran's Identification Information
    class Section1 < Section
      include ::PdfFill::Forms::FormHelper
      include Helpers

      # Section configuration hash
      KEY = {
        # 1a
        'veteranFullName' => {
          'first' => {
            limit: 12,
            question_num: 1,
            question_suffix: 'A',
            question_label: "Veteran's First Name",
            question_text: 'VETERAN\'S FIRST NAME',
            key: 'form1[0].#subform[207].VeteransFirstName[0]'
          },
          'middle' => {
            limit: 1,
            question_num: 1,
            question_suffix: 'A',
            key: 'form1[0].#subform[207].VeteransMiddleInitial1[0]'
          },
          'last' => {
            limit: 18,
            question_num: 1,
            question_suffix: 'A',
            question_label: "Veteran's Last Name",
            question_text: 'VETERAN\'S LAST NAME',
            key: 'form1[0].#subform[207].VeteransLastName[0]'
          }
        },
        # 1b
        'section1VeteranSocialSecurityNumber' => {
          'first' => {
            key: 'form1[0].#subform[207].VeteransSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'form1[0].#subform[207].VeteransSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[207].VeteransSocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        'veteranDateOfBirth' => {
          'month' => {
            key: 'form1[0].#subform[207].DOBmonth[0]'
          },
          'day' => {
            key: 'form1[0].#subform[207].DOBday[0]'
          },
          'year' => {
            key: 'form1[0].#subform[207].DOByear[0]'
          }
        },
        # 1d
        'vaClaimsHistory' => {
          key: 'form1[0].#subform[207].RadioButtonList[0]'
        },
        # 1e
        'vaFileNumber' => {
          question_num: 1,
          question_suffix: 'C',
          key: 'form1[0].#subform[207].VAFileNumber[0]'
        },
        'diedOnDuty' => {
          key: 'form1[0].#subform[207].RadioButtonList[1]'
        },
        'veteranServiceNumber' => {
          key: 'form1[0].#subform[207].VETERANS_SERVICE_NUMBER[0]'
        },
        'veteranDateOfDeath' => {
          'month' => {
            key: 'form1[0].#subform[207].DATE_OF_DEATH_Month[0]'
          },
          'day' => {
            key: 'form1[0].#subform[207].DATE_OF_DEATH_Day[0]'
          },
          'year' => {
            key: 'form1[0].#subform[207].DATE_OF_DEATH_Year[0]'
          }
        }
      }.freeze

      def expand(form_data = {})
        form_data['veteranFullName'] ||= {}
        form_data['veteranFullName']['first'] = form_data.dig('veteranFullName', 'first')&.titleize
        form_data['veteranFullName']['middle'] = form_data.dig('veteranFullName', 'middle')&.first&.titleize
        form_data['veteranFullName']['last'] = form_data.dig('veteranFullName', 'last')&.titleize
        form_data['section1VeteranSocialSecurityNumber'] = split_ssn(form_data['veteranSocialSecurityNumber'])
        form_data['veteranDateOfBirth'] = split_date(form_data['veteranDateOfBirth'])
        form_data['vaClaimsHistory'] = to_radio_yes_no(form_data['vaClaimsHistory'])
        form_data['diedOnDuty'] = to_radio_yes_no(form_data['diedOnDuty'])
        form_data['veteranDateOfDeath'] = split_date(form_data['veteranDateOfDeath'])
        form_data
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
