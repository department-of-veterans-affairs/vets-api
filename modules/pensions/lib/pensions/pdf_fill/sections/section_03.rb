# frozen_string_literal: true

require_relative '../section'

module Pensions
  module PdfFill
    # Section III: Veteran Service Information
    class Section3 < Section
      # Section configuration hash
      KEY = {
        # 3a
        'previousNames' => {
          item_label: 'Other service name',
          limit: 1,
          first_key: 'first',
          'first' => {
            limit: 12,
            question_num: 3,
            question_suffix: 'A',
            question_label: 'Other First Name',
            question_text: 'OTHER FIRST NAME',
            key: "form1[0].#subform[48].Other_Name_You_Served_Under_First_Name[#{ITERATOR}]"
          },
          'last' => {
            limit: 18,
            question_num: 3,
            question_suffix: 'A',
            question_label: 'Other Last Name',
            question_text: 'OTHER LAST NAME',
            key: "form1[0].#subform[48].Other_Name_You_Served_Under_Last_Name[#{ITERATOR}]"
          }
        },
        # 3b
        'activeServiceDateRange' => {
          'from' => {
            'month' => {
              key: 'form1[0].#subform[48].Date_Entered_Active_Duty_Month[0]'
            },
            'day' => {
              key: 'form1[0].#subform[48].Date_Entered_Active_Duty_Day[0]'
            },
            'year' => {
              key: 'form1[0].#subform[48].Date_Entered_Active_Duty_Year[0]'
            }
          },
          'to' => {
            'month' => {
              key: 'form1[0].#subform[48].Date_Of_Release_From_Active_Duty_Month[0]'
            },
            'day' => {
              key: 'form1[0].#subform[48].Date_Of_Release_From_Active_Duty_Day[0]'
            },
            'year' => {
              key: 'form1[0].#subform[48].Date_Of_Release_From_Active_Duty_Year[0]'
            }
          }
        },
        # 3e
        'serviceBranch' => {
          'army' => {
            key: 'form1[0].#subform[48].Army[0]'
          },
          'navy' => {
            key: 'form1[0].#subform[48].Navy[0]'
          },
          'airForce' => {
            key: 'form1[0].#subform[48].Air_Force[0]'
          },
          'coastGuard' => {
            key: 'form1[0].#subform[48].Coast_Guard[0]'
          },
          'marineCorps' => {
            key: 'form1[0].#subform[48].Marine_Corps[0]'
          },
          'spaceForce' => {
            key: 'form1[0].#subform[48].Space_Force[0]'
          },
          'usphs' => {
            key: 'form1[0].#subform[48].USPHS[0]'
          },
          'noaa' => {
            key: 'form1[0].#subform[48].NOAA[0]'
          }
        },
        # 3d
        'serviceNumber' => {
          key: 'form1[0].#subform[48].Your_Service_Number[0]'
        },
        # 3f
        'placeOfSeparationLineOne' => {
          key: 'form1[0].#subform[48].Place_Of_Your_Last_Separation[1]'
        },
        'placeOfSeparationLineTwo' => {
          key: 'form1[0].#subform[48].Place_Of_Your_Last_Separation[0]'
        },
        # 3g
        'pow' => {
          key: 'form1[0].#subform[48].RadioButtonList[1]'
        },
        # 3h
        'powDateRange' => {
          'from' => {
            'month' => {
              key: 'form1[0].#subform[48].Date_Confinement_Started_Month[1]'
            },
            'day' => {
              key: 'form1[0].#subform[48].Date_Confinement_Started_Day[1]'
            },
            'year' => {
              key: 'form1[0].#subform[48].Date_Confinement_Started_Year[1]'
            }
          },
          'to' => {
            'month' => {
              key: 'form1[0].#subform[48].Date_Confinement_Ended_Month[1]'
            },
            'day' => {
              key: 'form1[0].#subform[48].Date_Confinement_Ended_Day[1]'
            },
            'year' => {
              key: 'form1[0].#subform[48].Date_Confinement_Ended_Year[1]'
            }
          }
        }
      }.freeze

      ##
      # Expand the form data for Veteran service history.
      #
      # @param form_data [Hash] The form data hash.
      #
      # @return [void]
      #
      # Note: This method modifies `form_data`
      #
      # rubocop:disable Metrics/MethodLength
      def expand(form_data)
        prev_names = form_data['previousNames']

        form_data['previousNames'] = prev_names.pluck('previousFullName') if prev_names.present?
        form_data['activeServiceDateRange'] = {
          'from' => split_date(form_data.dig('activeServiceDateRange', 'from')),
          'to' => split_date(form_data.dig('activeServiceDateRange', 'to'))
        }
        form_data['serviceBranch'] = form_data['serviceBranch']&.select { |_, value| value == true }
        form_data['serviceBranch'] = form_data['serviceBranch']&.each_key { |k| form_data['serviceBranch'][k] = '1' }

        form_data['pow'] = to_radio_yes_no(form_data['powDateRange'].present?)
        if form_data['pow'].zero?
          form_data['powDateRange'] ||= {}
          form_data['powDateRange']['from'] = split_date(form_data.dig('powDateRange', 'from'))
          form_data['powDateRange']['to'] = split_date(form_data.dig('powDateRange', 'to'))
        end

        place_of_separation = form_data['placeOfSeparation'].to_s

        if place_of_separation.length <= 36 # split lines
          form_data['placeOfSeparationLineOne'] = place_of_separation[0..17]
          form_data['placeOfSeparationLineTwo'] = place_of_separation[18..]
        else # overflow
          form_data['placeOfSeparationLineOne'] = place_of_separation
        end
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
