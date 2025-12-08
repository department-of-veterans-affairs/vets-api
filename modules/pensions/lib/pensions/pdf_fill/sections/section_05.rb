# frozen_string_literal: true

require_relative '../section'

module Pensions
  module PdfFill
    # Section V: Employment History
    class Section5 < Section
      # Section configuration hash
      KEY = {
        # 5a
        'currentEmployment' => {
          key: 'form1[0].#subform[49].RadioButtonList[9]'
        },
        'currentEmployers' => {
          item_label: 'Current job',
          limit: 1,
          first_key: 'jobType',
          # 5b
          'jobType' => {
            limit: 35,
            question_num: 5,
            question_suffix: 'B',
            question_label: 'What Kind Of Work Are You Currently Doing',
            question_text: 'WHAT KIND OF WORK ARE YOU CURRENTLY DOING',
            key: 'form1[0].#subform[49].What_Kind_Of_Work_Are_You_Currently_Doing[0]'
          },
          # 5c
          'jobHoursWeek' => {
            limit: 3,
            question_num: 5,
            question_suffix: 'B',
            question_label: 'How Many Hours Per Week Do You Average',
            question_text: 'HOW MANY HOURS PER WEEK DO YOU AVERAGE',
            key: 'form1[0].#subform[49].How_Many_Hours_Per_Week_Do_You_Average[0]'
          }
        },
        'previousEmployers' => {
          limit: 1,
          first_key: 'jobTitle',
          # 5d
          'jobDate' => {
            'month' => {
              key: 'form1[0].#subform[49].Date_You_Last_Worked_Month[0]'
            },
            'day' => {
              key: 'form1[0].#subform[49].Date_You_Last_Worked_Day[0]'
            },
            'year' => {
              key: 'form1[0].#subform[49].Date_You_Last_Worked_Year[0]'
            }
          },
          'jobDateOverflow' => {
            question_num: 5,
            question_suffix: 'D',
            question_label: 'When Did You Last Work',
            question_text: 'WHEN DID YOU LAST WORK'
          },
          # 5e
          'jobHoursWeek' => {
            limit: 3,
            question_num: 5,
            question_suffix: 'E',
            question_label: 'How Many Hours Per Week Did You Average',
            question_text: 'HOW MANY HOURS PER WEEK DID YOU AVERAGE',
            key: 'form1[0].#subform[49].How_Many_Hours_Per_Week_Did_You_Average[0]'
          },
          # 5f
          'jobTitle' => {
            limit: 30,
            question_num: 5,
            question_suffix: 'F',
            question_label: 'What Was Your Job Title',
            question_text: 'WHAT WAS YOUR JOB TITLE',
            key: 'form1[0].#subform[49].What_Was_Your_Job_Title[0]'
          },
          # 5g
          'jobType' => {
            limit: 27,
            question_num: 5,
            question_suffix: 'G',
            question_label: 'What Kind Of Work Did You Do',
            question_text: 'WHAT KIND OF WORK DID YOU DO',
            key: 'form1[0].#subform[49].What_Kind_Of_Work_Did_You_Do[0]'
          }
        }
      }.freeze

      ##
      # Expand the form data for employment history.
      #
      # @param form_data [Hash] The form data hash.
      #
      # @return [void]
      #
      # Note: This method modifies `form_data`
      #
      def expand(form_data)
        form_data['currentEmployment'] = to_radio_yes_no(form_data['currentEmployment'])

        form_data['previousEmployers'] = form_data['previousEmployers']&.map do |pe|
          pe.merge({
                     'jobDate' => split_date(pe['jobDate']),
                     'jobDateOverflow' => to_date_string(pe['jobDate'])
                   })
        end

        form_data['currentEmployers'] = nil if form_data['currentEmployment'] == 1
      end
    end
  end
end
