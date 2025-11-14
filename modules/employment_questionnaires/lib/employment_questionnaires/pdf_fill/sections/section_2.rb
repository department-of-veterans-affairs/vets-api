# frozen_string_literal: true

require 'employment_questionnaires/pdf_fill/section'

module EmploymentQuestionnaires
  module PdfFill
    # Section I: Veteran's Identification Information
    class Section2 < Section
      include Helpers
      include ::PdfFill::Forms::FormHelper
      include ::PdfFill::Forms::FormHelper::PhoneNumberFormatting

      # Converts number to word
      NUMBER_TO_WORDS = {
        1 => 'One',
        2 => 'Two',
        3 => 'Three',
        4 => 'Four',
        5 => 'Five'
      }.freeze

      ITERATOR = ::PdfFill::HashConverter::ITERATOR

      KEY = {
        'employmentStatus' => {
          'radio' => {
            question_num: 10,
            key: 'F[0].Page_1[0].RadioButtonList[0]'
          },
          'mailedDate' => {
            question_num: 10,
            key: 'F[0].Page_1[0].Date_Mailed[0]'
          }
        },
        'employmentOne' => {
          'nameAndAddress' => {
            key: 'F[0].Page_1[0].Name_And_Address_Of_Employer[0]'
          },
          'typeOfWork' => {
            limit: 39,
            key: 'F[0].Page_1[0].Type_Of_Work[0]'
          },
          'hoursPerWeek' => {
            limit: 39,
            key: 'F[0].Page_1[0].Hours_Per_Week[0]'
          },
          'dateRange' => {
            'from' => {
              key: 'F[0].Page_1[0].Date_Of_Employment_From[0]'
            },
            'to' => {
              key: 'F[0].Page_1[0].Date_Of_Employment_To[0]'
            }
          },
          'timeLost' => {
            limit: 39,
            key: 'F[0].Page_1[0].Time_Lost_From_Illness[0]'
          },
          'grossEarningsPerMonth' => {
            limit: 10,
            key: 'F[0].Page_1[0].Gross_Earnings_Per_Month[0]'
          }
        },
        'employmentTwo' => {
          'nameAndAddress' => {
            limit: 110,
            key: 'F[0].#subform[1].Name_And_Address_Of_Employer[2]'
          },
          'typeOfWork' => {
            limit: 39,
            key: 'F[0].#subform[1].Type_Of_Work[2]'
          },
          'hoursPerWeek' => {
            limit: 39,
            key: 'F[0].#subform[1].Hours_Per_Week[2]'
          },
          'dateRange' => {
            'from' => {
              key: 'F[0].#subform[1].Date_Of_Employment_From[2]'
            },
            'to' => {
              key: 'F[0].#subform[1].Date_Of_Employment_To[2]'
            }
          },
          'timeLost' => {
            limit: 39,
            key: 'F[0].#subform[1].Time_Lost_From_Illness[2]'
          },
          'grossEarningsPerMonth' => {
            limit: 10,
            key: 'F[0].#subform[1].Gross_Earnings_Per_Month[2]'
          }
        },
        'employmentThree' => {
          'nameAndAddress' => {
            limit: 110,
            key: 'F[0].#subform[1].Name_And_Address_Of_Employer[1]'
          },
          'typeOfWork' => {
            limit: 39,
            key: 'F[0].#subform[1].Type_Of_Work[1]'
          },
          'hoursPerWeek' => {
            limit: 39,
            key: 'F[0].#subform[1].Hours_Per_Week[1]'
          },
          'dateRange' => {
            'from' => {
              key: 'F[0].#subform[1].Date_Of_Employment_From[1]'
            },
            'to' => {
              key: 'F[0].#subform[1].Date_Of_Employment_To[1]'
            }
          },
          'timeLost' => {
            limit: 39,
            key: 'F[0].#subform[1].Time_Lost_From_Illness[1]'
          },
          'grossEarningsPerMonth' => {
            limit: 10,
            key: 'F[0].#subform[1].Gross_Earnings_Per_Month[0]' # <- weird pdf mapping
          }
        },
        'employmentFour' => {
          'nameAndAddress' => {
            limit: 110,
            key: 'F[0].#subform[1].Name_And_Address_Of_Employer[0]'
          },
          'typeOfWork' => {
            limit: 39,
            key: 'F[0].#subform[1].Type_Of_Work[0]'
          },
          'hoursPerWeek' => {
            limit: 39,
            key: 'F[0].#subform[1].Hours_Per_Week[0]'
          },
          'dateRange' => {
            'from' => {
              key: 'F[0].#subform[1].Date_Of_Employment_From[0]'
            },
            'to' => {
              key: 'F[0].#subform[1].Date_Of_Employment_To[0]'
            }
          },
          'timeLost' => {
            limit: 39,
            key: 'F[0].#subform[1].Time_Lost_From_Illness[0]'
          },
          'grossEarningsPerMonth' => {
            limit: 10,
            key: 'F[0].#subform[1].Gross_Earnings_Per_Month[1]' # <- weird pdf mapping
          }
        },
        'signatureSection1' => {
          'signatureDate' => {
            key: 'F[0].#subform[1].DateSigned[0]'
          },
          'ssn' => {
            'first' => {
              key: 'F[0].#subform[1].Veterans_Social_SecurityNumber_FirstThreeNumbers[0]'
            },
            'second' => {
              key: 'F[0].#subform[1].Veterans_Social_SecurityNumber_SecondTwoNumbers[0]'
            },
            'third' => {
              key: 'F[0].#subform[1].Veterans_Social_SecurityNumber_LastFourNumbers[0]'
            }
          }
        },
        'signatureSection2' => {
          'signatureDate' => {
            key: 'F[0].#subform[1].DateSigned[1]'
          }
        },
        'stationAddress' => {
          'address' => {
            key: 'F[0].Page_1[0].Station_Address[0]'
          }
        }
      }.freeze

      def expand(form_data = {})
        employment_history = form_data['employmentHistory']

        if employment_history&.any?
          form_data['employmentOne'] = employment_history[0]

          employment_history[1..].each_with_index do |item, index|
            form_data["employment#{NUMBER_TO_WORDS[index + 2]}"] = item
          end
        end

        split_data(form_data)

        form_data
      end

      def split_data(form_data)
        form_data['signatureSection1']['ssn'] = split_ssn(form_data['signatureSection1']['veteranSocialSecurityNumber'])
        form_data['employmentStatus']['radio'] = form_data['employmentStatus']['radio'] ? 'YES' : 'NO'
      end
    end
  end
end
