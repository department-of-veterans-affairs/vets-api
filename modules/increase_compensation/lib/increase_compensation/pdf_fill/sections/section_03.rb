# frozen_string_literal: true

require 'increase_compensation/pdf_fill/section'

module IncreaseCompensation
  module PdfFill
    # Section III: Reporting Period
    class Section3 < Section
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
          key: 'form1[0].#subform[0].Occupation_During_That_Year[0]'
        },
        'previousEmployers' => {
          limit: 5,
          question_num: 18,
          first_key: 'nameAndAddress',
          'nameAndAddress' => {
            iterator_offset: ->(iterator) { iterator + 1 },
            key: "form1[0].#subform[1].NAMEANDADDRESSOFEMPLOYERORUNIT#{ITERATOR}[0]"
          },
          'typeOfWork' => {
            iterator_offset: ->(iterator) { iterator + 1 },
            key: "form1[0].#subform[1].TYPEOFWORK#{ITERATOR}[0]"
          },
          'hoursPerWeek' => {
            iterator_offset: ->(iterator) { iterator + 1 },
            limit: 3,
            key: "form1[0].#subform[1].HOURSPERWEEK#{ITERATOR}[0]"
          },
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
          },
          'timeLostFromIllness' => {
            iterator_offset: ->(iterator) { iterator + 1 },
            key: "form1[0].#subform[1].TIMELOSTFROMILLNESS#{ITERATOR}[0]"
          },
          'mostEarningsInAMonth' => {
            iterator_offset: ->(iterator) { iterator + 1 },
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
          question_num: 22,
          first_key: 'nameAndAddress',
          'nameAndAddress' => {
            iterator_offset: ->(iterator) { iterator + 1 },
            key: "form1[0].#subform[2].Table1[0].Row#{ITERATOR}[0].NAME_AND_ADDRESS_OF_EMPLOYER[0]"
          },
          'workType' => {
            iterator_offset: ->(iterator) { iterator + 1 },
            key: "form1[0].#subform[2].Table1[0].Row#{ITERATOR}[0].TYPE_OF-WORK[0]"
          },
          'date' => {
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
        # if form_data['preventMilitaryDuties'] || YES || NO || OFF

        # form_data['leftLastJobDueToDisability'] YES (If &quot;Yes,&quot; explain in Item 26, &quot;Remarks&quot;) || NO || OFF

        # form_data['expectDisabilityRetirement'] YES || NO || OFF

        # form_data['receiveExpectWorkersCompensation'] YES || NO || OFF

        # form_data['attemptedEmploy'] YES (If &quot;Yes,&quot; complete Items 22A, 22B, and 22C) || NO || OFF
      end
    end
  end
end
