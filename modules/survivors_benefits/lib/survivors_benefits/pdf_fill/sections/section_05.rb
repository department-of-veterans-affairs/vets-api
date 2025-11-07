# frozen_string_literal: true

require 'survivors_benefits/pdf_fill/section'

require_relative '../../constants'

module SurvivorsBenefits
  module PdfFill
    # Section 5: Marital History
    class Section5 < Section
      ITERATOR = ::PdfFill::HashConverter::ITERATOR

      KEY = {
        'p12HeaderVeteranSocialSecurityNumber' => {
          'first' => {
            key: 'form1[0].#subform[209].VeteransSocialSecurityNumber_FirstThreeNumbers[2]'
          },
          'second' => {
            key: 'form1[0].#subform[209].VeteransSocialSecurityNumber_SecondTwoNumbers[2]'
          },
          'third' => {
            key: 'form1[0].#subform[209].VeteransSocialSecurityNumber_LastFourNumbers[2]'
          }
        },
        'veteranMarriages' => {
          limit: 2,
          first_key: 'reasonForSeparation',
          'spouseFullName' => {
            'first' => {
              limit: 12,
              question_num: 1,
              question_suffix: 'A',
              question_label: "Spouse's First Name",
              question_text: 'SPOUSE\'S FIRST NAME',
              iterator_offset: ->(iterator) { 1 - iterator },
              key: "form1[0].#subform[209].FirstName[#{ITERATOR}]"
            },
            'middle' => {
              limit: 1,
              question_num: 1,
              question_suffix: 'A',
              iterator_offset: ->(iterator) { 1 - iterator },
              key: "form1[0].#subform[209].MiddleInitial1[#{ITERATOR}]"
            },
            'last' => {
              limit: 18,
              question_num: 1,
              question_suffix: 'A',
              question_label: "Veteran's Last Name",
              question_text: 'VETERAN\'S LAST NAME',
              iterator_offset: ->(iterator) { 1 - iterator },
              key: "form1[0].#subform[209].LastName[#{ITERATOR}]"
            }
          },
          'reasonForSeparation' => {
            iterator_offset: ->(iterator) { 18 - iterator },
            key: "form1[0].#subform[209].RadioButtonList[#{ITERATOR}]"
          },
          'reasonForSeparationExplanation' => {
            iterator_offset: ->(iterator) { 5 - iterator },
            key: "form1[0].#subform[209].Explain[#{ITERATOR}]"
          },
          'dateOfMarriage' => {
            'month' => {
              iterator_offset: ->(iterator) { 3 - (iterator * 3) },
              key: "form1[0].#subform[209].Date_Month[#{ITERATOR}]"
            },
            'day' => {
              iterator_offset: ->(iterator) { 3 - (iterator * 3) },
              key: "form1[0].#subform[209].Date_Day[#{ITERATOR}]"
            },
            'year' => {
              iterator_offset: ->(iterator) { 3 - (iterator * 3) },
              key: "form1[0].#subform[209].Date_Year[#{ITERATOR}]"
            }
          },
          'dateOfSeparation' => {
            'month' => {
              iterator_offset: ->(iterator) { 2 - iterator },
              key: "form1[0].#subform[209].Date_Month[#{ITERATOR}]"
            },
            'day' => {
              iterator_offset: ->(iterator) { 2 - iterator },
              key: "form1[0].#subform[209].Date_Day[#{ITERATOR}]"
            },
            'year' => {
              iterator_offset: ->(iterator) { 2 - iterator },
              key: "form1[0].#subform[209].Date_Year[#{ITERATOR}]"
            }
          },
          'locationOfMarriage' => {
            limit: 63,
            question_num: 7.1,
            question_suffix: '[Veteran]',
            question_label: '(4) Place Of Marriage',
            question_text: '(4) PLACE OF MARRIAGE',
            iterator_offset: ->(iterator) { 1 - iterator },
            key: "form1[0].#subform[209].Place_Of_Marriage[#{ITERATOR}]"
          },
          'locationOfSeparation' => {
            limit: 54,
            question_num: 7.1,
            question_suffix: '[Veteran]',
            question_label: '(5) Place Of Marriage Termination',
            question_text: '(5) PLACE OF MARRIAGE TERMINATION',
            iterator_offset: ->(iterator) { 1 - iterator },
            key: "form1[0].#subform[209].Place_Of_Marriage_Termination[#{ITERATOR}]"
          }
        },
        'veteranHasAdditionalMarriages' => {
          key: 'form1[0].#subform[209].RadioButtonList[19]'
        },
        'spouseMarriages' => {
          limit: 2,
          first_key: 'reasonForSeparation',
          'spouseFullName' => {
            'first' => {
              limit: 12,
              question_num: 1,
              question_suffix: 'A',
              question_label: "Spouse's First Name",
              question_text: 'SPOUSE\'S FIRST NAME',
              iterator_offset: ->(iterator) { 3 - iterator },
              key: "form1[0].#subform[209].FirstName[#{ITERATOR}]"
            },
            'middle' => {
              limit: 1,
              question_num: 1,
              question_suffix: 'A',
              iterator_offset: ->(iterator) { 3 - iterator },
              key: "form1[0].#subform[209].MiddleInitial1[#{ITERATOR}]"
            },
            'last' => {
              limit: 18,
              question_num: 1,
              question_suffix: 'A',
              question_label: "Veteran's Last Name",
              question_text: 'VETERAN\'S LAST NAME',
              iterator_offset: ->(iterator) { 3 - iterator },
              key: "form1[0].#subform[209].LastName[#{ITERATOR}]"
            }
          },
          'reasonForSeparation' => {
            iterator_offset: ->(iterator) { 21 - iterator },
            key: "form1[0].#subform[209].RadioButtonList[#{ITERATOR}]"
          },
          'reasonForSeparationExplanation' => {
            iterator_offset: ->(iterator) { 7 - iterator },
            key: "form1[0].#subform[209].Explain[#{ITERATOR}]"
          },
          'dateOfMarriage' => {
            'month' => {
              iterator_offset: ->(iterator) { 7 - (iterator * 3) },
              key: "form1[0].#subform[209].Date_Month[#{ITERATOR}]"
            },
            'day' => {
              iterator_offset: ->(iterator) { 7 - (iterator * 3) },
              key: "form1[0].#subform[209].Date_Day[#{ITERATOR}]"
            },
            'year' => {
              iterator_offset: ->(iterator) { 7 - (iterator * 3) },
              key: "form1[0].#subform[209].Date_Year[#{ITERATOR}]"
            }
          },
          'dateOfSeparation' => {
            'month' => {
              iterator_offset: ->(iterator) { 6 - iterator },
              key: "form1[0].#subform[209].Date_Month[#{ITERATOR}]"
            },
            'day' => {
              iterator_offset: ->(iterator) { 6 - iterator },
              key: "form1[0].#subform[209].Date_Day[#{ITERATOR}]"
            },
            'year' => {
              iterator_offset: ->(iterator) { 6 - iterator },
              key: "form1[0].#subform[209].Date_Year[#{ITERATOR}]"
            }
          },
          'locationOfMarriage' => {
            limit: 63,
            question_num: 7.1,
            question_suffix: '[Veteran]',
            question_label: '(4) Place Of Marriage',
            question_text: '(4) PLACE OF MARRIAGE',
            iterator_offset: ->(iterator) { 3 - iterator },
            key: "form1[0].#subform[209].Place_Of_Marriage[#{ITERATOR}]"
          },
          'locationOfSeparation' => {
            limit: 54,
            question_num: 7.1,
            question_suffix: '[Veteran]',
            question_label: '(5) Place Of Marriage Termination',
            question_text: '(5) PLACE OF MARRIAGE TERMINATION',
            iterator_offset: ->(iterator) { 3 - iterator },
            key: "form1[0].#subform[209].Place_Of_Marriage_Termination[#{ITERATOR}]"
          }
        },
        'spouseHasAdditionalMarriages' => {
          key: 'form1[0].#subform[209].RadioButtonList[22]'
        }
      }.freeze

      def expand(form_data)
        form_data['p12HeaderVeteranSocialSecurityNumber'] = split_ssn(form_data['veteranSocialSecurityNumber'])
        form_data['veteranMarriages'] = build_marital_history(form_data['veteranMarriages'])
        form_data['spouseMarriages'] = build_marital_history(form_data['spouseMarriages'], 'SPOUSE')
        form_data['veteranHasAdditionalMarriages'] =
          case form_data['veteranHasAdditionalMarriages']
          when true then 1
          when false then 0
          else 'Off'
          end
        form_data['spouseHasAdditionalMarriages'] = to_radio_yes_no_numeric(form_data['spouseHasAdditionalMarriages'])
        form_data
      end

      def build_marital_history(marriages, marriage_for = 'VETERAN')
        return [] unless marriages.present? && %w[VETERAN SPOUSE].include?(marriage_for)

        marriages.map do |marriage|
          reason_for_separation = marriage['reasonForSeparation'].to_s
          marriage.merge({
                           'dateOfMarriage' => split_date(marriage['dateOfMarriage']),
                           'dateOfSeparation' => split_date(marriage['dateOfSeparation']),
                           'reasonForSeparation' => Constants::REASONS_FOR_SEPARATION[reason_for_separation]
                         })
        end
      end

      def to_radio_yes_no_numeric(obj)
        case obj
        when true then 2
        when false then 1
        else 'Off'
        end
      end
    end
  end
end
