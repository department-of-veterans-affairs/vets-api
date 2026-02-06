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
        'veteranMarriageOne' => {
          first_key: 'reasonForSeparation',
          'spouseFullName' => {
            'first' => {
              limit: 12,
              question_num: 5,
              question_suffix: 'A',
              question_label: 'Spouse\'s First Name',
              question_text: 'SPOUSE\'S FIRST NAME',
              key: 'form1[0].#subform[209].FirstName[1]'
            },
            'middle' => {
              limit: 1,
              question_num: 5,
              question_suffix: 'A',
              key: 'form1[0].#subform[209].MiddleInitial1[1]'
            },
            'last' => {
              limit: 18,
              question_num: 5,
              question_suffix: 'A',
              question_label: 'Spouse\'s Last Name',
              question_text: 'SPOUSE\'S LAST NAME',
              key: 'form1[0].#subform[209].LastName[1]'
            }
          },
          'reasonForSeparation' => {
            key: 'form1[0].#subform[209].RadioButtonList[18]'
          },
          'reasonForSeparationExplanation' => {
            limit: 52,
            question_num: 5,
            question_suffix: 'B',
            question_label: 'Reason For Separation Explanation',
            question_text: 'REASON FOR SEPARATION EXPLANATION',
            key: 'form1[0].#subform[209].Explain[5]'
          },
          'dateOfMarriage' => {
            'month' => {
              key: 'form1[0].#subform[209].Date_Month[3]'
            },
            'day' => {
              key: 'form1[0].#subform[209].Date_Day[3]'
            },
            'year' => {
              key: 'form1[0].#subform[209].Date_Year[3]'
            }
          },
          'dateOfSeparation' => {
            'month' => {
              key: 'form1[0].#subform[209].Date_Month[2]'
            },
            'day' => {
              key: 'form1[0].#subform[209].Date_Day[2]'
            },
            'year' => {
              key: 'form1[0].#subform[209].Date_Year[2]'
            }
          },
          'locationOfMarriage' => {
            limit: 42,
            question_num: 5,
            question_suffix: 'D',
            question_label: 'Place Of Marriage',
            question_text: 'PLACE OF MARRIAGE',
            key: 'form1[0].#subform[209].Place_Of_Marriage[1]'
          },
          'locationOfSeparation' => {
            limit: 42,
            question_num: 5,
            question_suffix: 'E',
            question_label: 'Place Of Marriage Termination',
            question_text: 'PLACE OF MARRIAGE TERMINATION',
            key: 'form1[0].#subform[209].Place_Of_Marriage_Termination[1]'
          }
        },
        'veteranMarriageTwo' => {
          first_key: 'reasonForSeparation',
          'spouseFullName' => {
            'first' => {
              limit: 12,
              question_num: 5,
              question_suffix: 'F',
              question_label: 'Spouse\'s First Name',
              question_text: 'SPOUSE\'S FIRST NAME',
              key: 'form1[0].#subform[209].FirstName[0]'
            },
            'middle' => {
              limit: 1,
              question_num: 5,
              question_suffix: 'F',
              key: 'form1[0].#subform[209].MiddleInitial1[0]'
            },
            'last' => {
              limit: 18,
              question_num: 5,
              question_suffix: 'F',
              question_label: 'Spouse\'s Last Name',
              question_text: 'SPOUSE\'S LAST NAME',
              key: 'form1[0].#subform[209].LastName[0]'
            }
          },
          'reasonForSeparation' => {
            key: 'form1[0].#subform[209].RadioButtonList[17]'
          },
          'reasonForSeparationExplanation' => {
            limit: 52,
            question_num: 5,
            question_suffix: 'G',
            question_label: 'Reason For Separation Explanation',
            question_text: 'REASON FOR SEPARATION EXPLANATION',
            key: 'form1[0].#subform[209].Explain[4]'
          },
          'dateOfMarriage' => {
            'month' => {
              key: 'form1[0].#subform[209].Date_Month[0]'
            },
            'day' => {
              key: 'form1[0].#subform[209].Date_Day[0]'
            },
            'year' => {
              key: 'form1[0].#subform[209].Date_Year[0]'
            }
          },
          'dateOfSeparation' => {
            'month' => {
              key: 'form1[0].#subform[209].Date_Month[1]'
            },
            'day' => {
              key: 'form1[0].#subform[209].Date_Day[1]'
            },
            'year' => {
              key: 'form1[0].#subform[209].Date_Year[1]'
            }
          },
          'locationOfMarriage' => {
            limit: 42,
            question_num: 5,
            question_suffix: 'I',
            question_label: 'Place Of Marriage',
            question_text: 'PLACE OF MARRIAGE',
            key: 'form1[0].#subform[209].Place_Of_Marriage[0]'
          },
          'locationOfSeparation' => {
            limit: 42,
            question_num: 5,
            question_suffix: 'J',
            question_label: 'Place Of Marriage Termination',
            question_text: 'PLACE OF MARRIAGE TERMINATION',
            key: 'form1[0].#subform[209].Place_Of_Marriage_Termination[0]'
          }
        },
        'veteranHasAdditionalMarriages' => {
          key: 'form1[0].#subform[209].RadioButtonList[19]'
        },
        'spouseMarriageOne' => {
          first_key: 'reasonForSeparation',
          'spouseFullName' => {
            'first' => {
              limit: 12,
              question_num: 5,
              question_suffix: 'L',
              question_label: 'Spouse\'s First Name',
              question_text: 'SPOUSE\'S FIRST NAME',
              key: 'form1[0].#subform[209].FirstName[3]'
            },
            'middle' => {
              limit: 1,
              question_num: 5,
              question_suffix: 'L',
              key: 'form1[0].#subform[209].MiddleInitial1[3]'
            },
            'last' => {
              limit: 18,
              question_num: 5,
              question_suffix: 'L',
              question_label: 'Spouse\'s Last Name',
              question_text: 'SPOUSE\'S LAST NAME',
              key: 'form1[0].#subform[209].LastName[3]'
            }
          },
          'reasonForSeparation' => {
            key: 'form1[0].#subform[209].RadioButtonList[21]'
          },
          'reasonForSeparationExplanation' => {
            limit: 64,
            question_num: 5,
            question_suffix: 'M',
            question_label: 'Reason For Separation Explanation',
            question_text: 'REASON FOR SEPARATION EXPLANATION',
            key: 'form1[0].#subform[209].Explain[7]'
          },
          'dateOfMarriage' => {
            'month' => {
              key: 'form1[0].#subform[209].Date_Month[7]'
            },
            'day' => {
              key: 'form1[0].#subform[209].Date_Day[7]'
            },
            'year' => {
              key: 'form1[0].#subform[209].Date_Year[7]'
            }
          },
          'dateOfSeparation' => {
            'month' => {
              key: 'form1[0].#subform[209].Date_Month[6]'
            },
            'day' => {
              key: 'form1[0].#subform[209].Date_Day[6]'
            },
            'year' => {
              key: 'form1[0].#subform[209].Date_Year[6]'
            }
          },
          'locationOfMarriage' => {
            limit: 42,
            question_num: 5,
            question_suffix: 'O',
            question_label: 'Place Of Marriage',
            question_text: 'PLACE OF MARRIAGE',
            key: 'form1[0].#subform[209].Place_Of_Marriage[3]'
          },
          'locationOfSeparation' => {
            limit: 42,
            question_num: 5,
            question_suffix: 'P',
            question_label: 'Place Of Marriage Termination',
            question_text: 'PLACE OF MARRIAGE TERMINATION',
            key: 'form1[0].#subform[209].Place_Of_Marriage_Termination[3]'
          }
        },
        'spouseMarriageTwo' => {
          first_key: 'reasonForSeparation',
          'spouseFullName' => {
            'first' => {
              limit: 12,
              question_num: 5,
              question_suffix: 'Q',
              question_label: 'Spouse\'s First Name',
              question_text: 'SPOUSE\'S FIRST NAME',
              key: 'form1[0].#subform[209].FirstName[2]'
            },
            'middle' => {
              limit: 1,
              question_num: 5,
              question_suffix: 'Q',
              key: 'form1[0].#subform[209].MiddleInitial1[2]'
            },
            'last' => {
              limit: 18,
              question_num: 5,
              question_suffix: 'Q',
              question_label: 'Spouse\'s Last Name',
              question_text: 'SPOUSE\'S LAST NAME',
              key: 'form1[0].#subform[209].LastName[2]'
            }
          },
          'reasonForSeparation' => {
            key: 'form1[0].#subform[209].RadioButtonList[20]'
          },
          'reasonForSeparationExplanation' => {
            limit: 64,
            question_num: 5,
            question_suffix: 'R',
            question_label: 'Reason For Separation Explanation',
            question_text: 'REASON FOR SEPARATION EXPLANATION',
            key: 'form1[0].#subform[209].Explain[6]'
          },
          'dateOfMarriage' => {
            'month' => {
              key: 'form1[0].#subform[209].Date_Month[4]'
            },
            'day' => {
              key: 'form1[0].#subform[209].Date_Day[4]'
            },
            'year' => {
              key: 'form1[0].#subform[209].Date_Year[4]'
            }
          },
          'dateOfSeparation' => {
            'month' => {
              key: 'form1[0].#subform[209].Date_Month[5]'
            },
            'day' => {
              key: 'form1[0].#subform[209].Date_Day[5]'
            },
            'year' => {
              key: 'form1[0].#subform[209].Date_Year[5]'
            }
          },
          'locationOfMarriage' => {
            limit: 42,
            question_num: 5,
            question_suffix: 'T',
            question_label: 'Place Of Marriage',
            question_text: 'PLACE OF MARRIAGE',
            key: 'form1[0].#subform[209].Place_Of_Marriage[2]'
          },
          'locationOfSeparation' => {
            limit: 42,
            question_num: 5,
            question_suffix: 'U',
            question_label: 'Place Of Marriage Termination',
            question_text: 'PLACE OF MARRIAGE TERMINATION',
            key: 'form1[0].#subform[209].Place_Of_Marriage_Termination[2]'
          }
        },
        'spouseHasAdditionalMarriages' => {
          key: 'form1[0].#subform[209].RadioButtonList[22]'
        }
      }.freeze

      def expand(form_data)
        form_data['p12HeaderVeteranSocialSecurityNumber'] = split_ssn(form_data['veteranSocialSecurityNumber'])
        veteran_marriages = build_marital_history(form_data['veteranMarriages'], 'VETERAN')
        form_data['veteranMarriageOne'] = veteran_marriages.first || {}
        form_data['veteranMarriageTwo'] = veteran_marriages.second || {}
        spouse_marriages = build_marital_history(form_data['spouseMarriages'], 'SPOUSE')
        form_data['spouseMarriageOne'] = spouse_marriages.first || {}
        form_data['spouseMarriageTwo'] = spouse_marriages.second || {}
        form_data['veteranHasAdditionalMarriages'] =
          case form_data['veteranHasAdditionalMarriages']
          when true then 1
          when false then 0
          else 'Off'
          end
        form_data['spouseHasAdditionalMarriages'] = to_radio_yes_no_numeric(form_data['spouseHasAdditionalMarriages'])
        form_data
      end

      def build_marital_history(marriages, marriage_for)
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