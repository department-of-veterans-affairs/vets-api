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
        'educationTrainingPreUnemployability' => {
          'name' => {
            limit: 12,
            key: 'form1[0].#subform[2].Type_Of_Education_Or_Training[0]'
          },
          'datesOfTraining' => {
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
          }
        },
        'trainingPostUnemployment' => {
          question_num: 25,
          key: 'form1[0].#subform[2].RadioButtonList[7]'
        },
        'educationTrainingPostUnemployability' => {
          question_num: 25,
          'name' => {
            limit: 12,
            key: 'form1[0].#subform[2].Type_Of_Education_Or_Training[1]'
          },
          'datesOfTraining' => {
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
        }
      }.freeze
      def expand(form_data = {})
        if form_data.key?('education') && form_data['education'].key?('highSchool')
          form_data['education']['highSchool'] = education_highschool_bug_fix(form_data['education']['highSchool'])
        end
        form_data['trainingPreDisabled'] = format_custom_boolean(form_data['trainingPreDisabled'], '1')
        if form_data.dig('educationTrainingPreUnemployability', 'datesOfTraining')
          form_data['educationTrainingPreUnemployability']['datesOfTraining'] =
            map_date_range(form_data['educationTrainingPreUnemployability']['datesOfTraining'])
        end
        if form_data.dig('educationTrainingPostUnemployability', 'datesOfTraining')
          form_data['educationTrainingPostUnemployability']['datesOfTraining'] =
            map_date_range(form_data['educationTrainingPostUnemployability']['datesOfTraining'])
        end
      end

      # option are off by 1 as grade '9' is not in the pdf data, so grade 12 appears as 'Off'
      def education_highschool_bug_fix(grade)
        return {} if grade.nil?

        case grade
        when 9
          10
        when 10
          11
        when 11
          12
        when 12
          'Off'
        else
          ''
        end
      end
    end
  end
end
