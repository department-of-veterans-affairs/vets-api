# frozen_string_literal: true

require 'survivors_benefits/pdf_fill/section'

require_relative '../../constants'

module SurvivorsBenefits
  module PdfFill
    # Section 7: Dependency and Indemnity Compensation (D.I.C.)
    class Section7 < Section
      ITERATOR = ::PdfFill::HashConverter::ITERATOR

      KEY = {
        'p14HeaderVeteranSocialSecurityNumber' => {
          'first' => {
            key: 'form1[0].#subform[211].VeteransSocialSecurityNumber_FirstThreeNumbers[4]'
          },
          'second' => {
            key: 'form1[0].#subform[211].VeteransSocialSecurityNumber_SecondTwoNumbers[4]'
          },
          'third' => {
            key: 'form1[0].#subform[211].VeteransSocialSecurityNumber_LastFourNumbers[4]'
          }
        },
        'benefit' => {
          key: 'form1[0].#subform[211].RadioButtonList[33]'
        },
        'treatments' => {
          limit: 3,
          first_key: 'facility',
          'facility' => {
            key: "form1[0].#subform[211].Name_And_Location_Of_VA_Medical_Center[#{ITERATOR}]"
          },
          'startDate' => {
            'month' => {
              iterator_offset: ->(iterator) { 2 - iterator },
              key: "form1[0].#subform[211].Dates_Of_Treatment_START_Month[#{ITERATOR}]"
            },
            'day' => {
              iterator_offset: ->(iterator) { 2 - iterator },
              key: "form1[0].#subform[211].START_Day[#{ITERATOR}]"
            },
            'year' => {
              iterator_offset: ->(iterator) { (0 - iterator) % 3 },
              key: "form1[0].#subform[211].START_Year[#{ITERATOR}]"
            }
          },
          'endDate' => {
            'month' => {
              iterator_offset: ->(iterator) { 2 - iterator },
              key: "form1[0].#subform[211].Dates_Of_Treatment_END_Month[#{ITERATOR}]"
            },
            'day' => {
              iterator_offset: ->(iterator) { (iterator - 1) % 2 },
              key_from_iterator: lambda { |iterator|
                case iterator
                when 2 then 'form1[0].#subform[211].Day[0]'
                else "form1[0].#subform[211].END_Day[#{ITERATOR}]"
                end
              }
            },
            'year' => {
              iterator_offset: ->(iterator) { 2 - iterator },
              key: "form1[0].#subform[211].END_Year[#{ITERATOR}]"
            }
          }
        }
      }.freeze

      def expand(form_data)
        form_data['p14HeaderVeteranSocialSecurityNumber'] = split_ssn(form_data['veteranSocialSecurityNumber'])
        form_data['benefit'] = benefit_to_radio(form_data['benefit'])
        treatments = form_data['treatments'] || []
        form_data['treatments'] = treatments.map do |treatment|
          {
            'facility' => treatment['facility'],
            'startDate' => split_date(treatment['treatmentDates']['start']),
            'endDate' => split_date(treatment['treatmentDates']['end'])
          }
        end
        form_data
      end

      # regrettably, these are not numbered in the 534ez PDF
      def benefit_to_radio(benefit)
        case benefit
        when 'DIC' then 'D.I.C.'
        when 'pactActDIC' then 'D.I.C. due to claimant election of a re-evaluation of a previously' \
                               ' denied claim based on expanded eligibility under PL 117-168 (PACT Act)' \
                               ' (Note: Please refer to Instructions page 6 for guidance on PACT Act)'
        when '1151DIC' then 'D.I.C. under U.S.C. 1151 (Note: D.I.C. under 38 U.S.C. is a rare benefit.' \
                            ' Please refer to the Instructions page 5 for guidance on 38 U.S.C. 1151)'
        else 'Off'
        end
      end
    end
  end
end
