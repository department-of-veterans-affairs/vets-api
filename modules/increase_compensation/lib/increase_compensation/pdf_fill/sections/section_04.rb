# frozen_string_literal: true

require 'increase_compensation/pdf_fill/section'

module IncreaseCompensation
  module PdfFill
    # Section IV: SCHOOLING AND OTHER TRAINING
    class Section4 < Section
      # Section configuration hash
      KEY = {
        'education' => {
          'gradeSchool' => {
            key: 'form1[0].#subform[2].EducationRadioButtonList[0]'
          },
          'highSchool' => {
            key: 'form1[0].#subform[2].EducationRadioButtonList[1]'
          },
          'college' => {
            key: 'form1[0].#subform[2].EducationRadioButtonList[2]'
          }
        },
        'trainingPreDisabled' => {
          key: 'form1[0].#subform[2].RadioButtonList[6]'
        },
        'otherEducationTrainingPreUnemployability' => {
          'name' => {
            limit: 15,
            key: 'form1[0].#subform[2].Type_Of_Education_Or_Training[0]'
          },
          'from' => {
            'month' => {
              key: 'form1[0].#subform[2].DATESOFTRAINING_BEGINNING_MONTH[0]'
            },
            'day' => {
              key: 'form1[0].#subform[2].DATESOFTRAINING_BEGINNING_DAY[0]'
            },
            'year' => {
              key: 'form1[0].#subform[2].DATESOFTRAINING_BEGINNING_YEAR[0]'
            }
          },
          'to' => {
            'month' => {
              key: 'form1[0].#subform[2].DATESOFTRAINING_COMPLETION_MONTH[0]'
            },
            'day' => {
              key: 'form1[0].#subform[2].DATESOFTRAINING_COMPLETION_DAY[0]'
            },
            'year' => {
              key: 'form1[0].#subform[2].DATESOFTRAINING_COMPLETION_YEAR[0]'
            }
          }
        },
        'trainingPostUnemployment' => {
          key: 'form1[0].#subform[2].RadioButtonList[7]'
        },
        'otherEducationTrainingPostUnemployability' => {
          limit: 1,
          question_num: 25,
          question_text: 'Other Education or Training After Unemployability',
          first_key: 'name',
          'name' => {
            key: 'form1[0].#subform[2].Type_Of_Education_Or_Training[1]'
          },
          'from' => {
            'month' => {
              limit: 2,
              key: 'form1[0].#subform[2].DATESOFTRAINING_BEGINNING_MONTH[1]'
            },
            'day' => {
              limit: 2,
              key: 'form1[0].#subform[2].DATESOFTRAINING_BEGINNING_DAY[1]'
            },
            'year' => {
              limit: 4,
              key: 'form1[0].#subform[2].DATESOFTRAINING_BEGINNING_YEAR[1]'
            }
          },
          'to' => {
            'month' => {
              limit: 2,
              key: 'form1[0].#subform[2].DATESOFTRAINING_COMPLETION_MONTH[1]'
            },
            'day' => {
              limit: 2,
              key: 'form1[0].#subform[2].DATESOFTRAINING_COMPLETION_DAY[1]'
            },
            'year' => {
              limit: 4,
              key: 'form1[0].#subform[2].DATESOFTRAINING_COMPLETION_YEAR[1]'
            }
          }
        }
      }.freeze
      def expand(form_data = {})
        # form_data['gradeSchool'] = 1 2 3 4 5 6 7 8 OFF
        # form_data['highSchool'] = 10 11 12 OFF
        # form_data['college'] = Fresh Soph Jr Sr Off
        # form_data['trainingPreDisabled'] = NO || OFF
        # form_data['trainingPreDisabled'] = YES (If &quot;Yes,&quot; complete Items 25B and 25C) || NO || OFF
      end
    end
  end
end
