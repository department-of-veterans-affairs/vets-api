# frozen_string_literal: true

require 'increase_compensation/pdf_fill/section'

module IncreaseCompensation
  module PdfFill
    # Section III: EMPLOYMENT STATEMENT
    class Section3 < Section
      include Helpers
      # Hash iterator
      ITERATOR = ::PdfFill::HashConverter::ITERATOR
      # Section configuration hash
      KEY = {
        'disabilityAffectEmployFTDate' => {
          'month' => {
            key: 'form1[0].#subform[0].Month[5]'
          },
          'day' => {
            key: 'form1[0].#subform[0].Day[5]'
          },
          'year' => {
            key: 'form1[0].#subform[0].Year[9]'
          }
        },
        'lastWorkedFullTimeDate' => {
          'month' => {
            key: 'form1[0].#subform[0].Month[6]'
          },
          'day' => {
            key: 'form1[0].#subform[0].Day[6]'
          },
          'year' => {
            key: 'form1[0].#subform[0].Year[10]'
          }
        },
        'becameTooDisabledToWorkDate' => {
          'month' => {
            key: 'form1[0].#subform[0].Month[7]'
          },
          'day' => {
            key: 'form1[0].#subform[0].Day[7]'
          },
          'year' => {
            key: 'form1[0].#subform[0].Year[11]'
          }
        },
        'mostEarningsInAYear' => {
          question_num: 17,
          question_suffix: 'A',
          'firstThree' => {
            key: 'form1[0].#subform[0].ValueOfYourPortionOfProperty2_10b3[0]'
          },
          'lastThree' => {
            key: 'form1[0].#subform[0].ValueOfYourPortionOfProperty3_10b3[0]'
          }
        },
        'yearOfMostEarnings' => {
          question_num: 17,
          question_suffix: 'B',
          key: 'form1[0].#subform[0].WHATYEAR[0]'
        },
        'occupationDuringMostEarnings' => {
          question_num: 17,
          question_suffix: 'C',
          limit: 27,
          key: 'form1[0].#subform[0].Occupation_During_That_Year[0]'
        },
        'previousEmployers' => {
          limit: 5,
          question_num: 18,
          question_label: 'Previous Employment',
          question_text: 'Previous Employment',
          first_key: 'nameAndAddress',
          'nameAndAddress' => {
            limit: 110,
            question_num: 18,
            question_label: 'Previous Employer Name',
            question_text: 'Previous Employer Name',
            iterator_offset: ->(iterator) { iterator + 1 },
            key: "form1[0].#subform[1].NAMEANDADDRESSOFEMPLOYERORUNIT#{ITERATOR}[0]"
          },
          'typeOfWork' => {
            limit: 39,
            question_num: 18,
            question_label: 'Previous Employer Type',
            question_text: 'Previous Employer Type',
            iterator_offset: ->(iterator) { iterator + 1 },
            key: "form1[0].#subform[1].TYPEOFWORK#{ITERATOR}[0]"
          },
          'hoursPerWeek' => {
            iterator_offset: ->(iterator) { iterator + 1 },
            limit: 3,
            question_num: 18,
            question_label: 'Previous Employer Hours per week',
            question_text: 'Previous Employer Hours per week',
            key: "form1[0].#subform[1].HOURSPERWEEK#{ITERATOR}[0]"
          },
          'datesOfEmployment' => {
            'from' => {
              'month' => {
                iterator_offset: ->(iterator) { iterator + 1 },
                key: "form1[0].#subform[1].DATESOFEMPLOYMENT#{ITERATOR}_FROM_MONTH[0]"
              },
              'day' => {
                iterator_offset: ->(iterator) { iterator + 1 },
                key: "form1[0].#subform[1].DATESOFEMPLOYMENT#{ITERATOR}_FROM_DAY[0]"
              },
              'year' => {
                iterator_offset: ->(iterator) { iterator + 1 },
                key: "form1[0].#subform[1].DATESOFEMPLOYMENT#{ITERATOR}_FROM_YEAR[0]"
              }
            },
            'to' => {
              'month' => {
                iterator_offset: ->(iterator) { iterator + 1 },
                key: "form1[0].#subform[1].DATESOFEMPLOYMENT#{ITERATOR}_TO_MONTH[0]"
              },
              'day' => {
                iterator_offset: ->(iterator) { iterator + 1 },
                key: "form1[0].#subform[1].DATESOFEMPLOYMENT#{ITERATOR}_TO_DAY[0]"
              },
              'year' => {
                iterator_offset: ->(iterator) { iterator + 1 },
                key: "form1[0].#subform[1].DATESOFEMPLOYMENT#{ITERATOR}_TO_YEAR[0]"
              }
            }
          },
          'timeLostFromIllness' => {
            iterator_offset: ->(iterator) { iterator + 1 },
            key: "form1[0].#subform[1].TIMELOSTFROMILLNESS#{ITERATOR}[0]"
          },
          'mostEarningsInAMonth' => {
            'firstThree' => {
              iterator_offset: ->(iterator) { iterator + 1 },
              key: "form1[0].#subform[1].HIGHESTGROSSEARNINGSPERMONTH18#{ITERATOR}_1[0]"
            },
            'lastThree' => {
              iterator_offset: ->(iterator) { iterator + 1 },
              key: "form1[0].#subform[1].HIGHESTGROSSEARNINGSPERMONTH18#{ITERATOR}_2[0]"
            }
          }
        },
        'preventMilitaryDuties' => {
          question_num: 19,
          key: 'form1[0].#subform[2].RadioButtonList[1]'
        },
        'past12MonthsEarnedIncome' => {
          question_num: 20,
          question_suffix: 'A',
          'firstThree' => {
            key: 'form1[0].#subform[2].totalearnedincome20a_1[0]'
          },
          'lastThree' => {
            key: 'form1[0].#subform[2].totalearnedincome20a_2[0]'
          }
        },
        'currentMonthlyEarnedIncome' => {
          question_num: 20,
          question_suffix: 'B',
          'firstThree' => {
            key: 'form1[0].#subform[2].CURRENTMONTHLYEARNEDINCOME_1[0]'
          },
          'lastThree' => {
            key: 'form1[0].#subform[2].CURRENTMONTHLYEARNEDINCOME_2[0]'
          }
        },
        'leftLastJobDueToDisability' => {
          question_num: 21,
          question_suffix: 'A',
          key: 'form1[0].#subform[2].RadioButtonList[2]'
        },
        'expectDisabilityRetirement' => {
          key: 'form1[0].#subform[2].RadioButtonList[3]'
        },
        'receiveExpectWorkersCompensation' => {
          key: 'form1[0].#subform[2].RadioButtonList[4]'
        },
        'attemptedEmploy' => {
          key: 'form1[0].#subform[2].RadioButtonList[5]'
        },
        'appliedEmployers' => {
          limit: 3,
          question_text: 'Employers Applied For Work Since Unemployment',
          question_label: 'Employers Applied For Work Since Unemployment',
          question_num: 22,
          first_key: 'nameAndAddress',
          'nameAndAddress' => {
            limit: 110,
            question_num: 22,
            question_suffix: 'A',
            question_label: 'Employers Applied Post Unemployment',
            question_text: 'Employers Applied Post Unemployment',
            iterator_offset: ->(iterator) { iterator + 1 },
            key: "form1[0].#subform[2].Table1[0].Row#{ITERATOR}[0].NAME_AND_ADDRESS_OF_EMPLOYER[0]"
          },
          'typeOfWork' => {
            limit: 62,
            question_num: 22,
            question_suffix: 'B',
            question_label: 'Employers Applied Post Unemployment',
            question_text: 'Employers Applied Post Unemployment',
            iterator_offset: ->(iterator) { iterator + 1 },
            key: "form1[0].#subform[2].Table1[0].Row#{ITERATOR}[0].TYPE_OF-WORK[0]"
          },
          'dateApplied' => {
            question_num: 22,
            question_suffix: 'C',
            question_label: 'Employers Applied Post Unemployment',
            question_text: 'Employers Applied Post Unemployment',
            'month' => {
              iterator_offset: ->(iterator) { iterator + 1 },
              key: "form1[0].#subform[2].Table1[0].Row#{ITERATOR}[0].#subform[0].DATESOFEMPLOYMENT5_FROM_MONTH[0]"
            },
            'day' => {
              iterator_offset: ->(iterator) { iterator + 1 },
              key: "form1[0].#subform[2].Table1[0].Row#{ITERATOR}[0].#subform[0].DATESOFEMPLOYMENT5_FROM_DAY[0]"
            },
            'year' => {
              iterator_offset: ->(iterator) { iterator + 1 },
              key: "form1[0].#subform[2].Table1[0].Row#{ITERATOR}[0].#subform[0].DATESOFEMPLOYMENT5_FROM_YEAR[0]"
            }
          }
        }

      }.freeze
      def expand(form_data = {})
        form_data = format_employment(form_data) if form_data.key?('previousEmployers')
        form_data = format_applications(form_data) if form_data.key?('appliedEmployers')
        form_data = format_boolean_fields(form_data)
        form_data['disabilityAffectEmployFTDate'] = split_date(form_data['disabilityAffectEmployFTDate'])
        form_data['lastWorkedFullTimeDate'] = split_date(form_data['lastWorkedFullTimeDate'])
        form_data['becameTooDisabledToWorkDate'] = split_date(form_data['becameTooDisabledToWorkDate'])
        form_data['mostEarningsInAYear'] = split_currency_amount_thousands(form_data['mostEarningsInAYear'])
        form_data['past12MonthsEarnedIncome'] = split_currency_amount_thousands(form_data['past12MonthsEarnedIncome'])
        form_data['currentMonthlyEarnedIncome'] =
          split_currency_amount_thousands(form_data['currentMonthlyEarnedIncome'])
      end

      def format_boolean_fields(form_data)
        form_data['preventMilitaryDuties'] = format_custom_boolean(
          form_data['preventMilitaryDuties']
        )
        form_data['leftLastJobDueToDisability'] = format_custom_boolean(
          form_data['leftLastJobDueToDisability'],
          'YES (If "Yes," explain in Item 26, "Remarks")'
        )
        form_data['expectDisabilityRetirement'] = format_custom_boolean(
          form_data['expectDisabilityRetirement']
        )
        form_data['receiveExpectWorkersCompensation'] = format_custom_boolean(
          form_data['receiveExpectWorkersCompensation']
        )
        form_data['attemptedEmploy'] = format_custom_boolean(
          form_data['attemptedEmploy'],
          'YES (If "Yes," complete Items 22A, 22B, and 22C)'
        )
        form_data
      end

      def format_employment(form_data)
        return form_data if form_data['previousEmployers'].length < 1

        form_data['previousEmployers'].each do |work|
          work['hoursPerWeek'] = work['hoursPerWeek'].to_s.rjust(3)
          work['mostEarningsInAMonth'] = split_currency_amount_thousands(work['mostEarningsInAMonth'])
          work['datesOfEmployment'] = map_date_range(work['datesOfEmployment'])
        end
        form_data
      end

      def format_applications(form_data)
        return form_data if form_data['appliedEmployers'].length < 1

        form_data['appliedEmployers'].each do |work|
          work['dateApplied'] = split_date(work['dateApplied'])
        end
        form_data
      end
    end
  end
end
