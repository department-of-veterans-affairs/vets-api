# frozen_string_literal: true

require_relative '../section'

module Burials
  module PdfFill
    # Section III: Veteran Service Information
    class Section3V2 < Section
      # Section configuration hash
      KEY = {
        'previousNames' => {
          'first' => {
            key: 'form1[0].#subform[94].Other_Name_You_Served_Under_First_Name[0]',
            limit: 12,
            question_num: 14,
            question_label: 'Other Name You Served Under - First Name',
            question_text: 'OTHER NAME YOU SERVED UNDER - FIRST NAME'
          },
          'last' => {
            key: 'form1[0].#subform[94].Other_Name_You_Served_Under_Last_Name[0]',
            limit: 18,
            question_num: 14,
            question_label: 'Other Name You Served Under - Last Name',
            question_text: 'OTHER NAME YOU SERVED UNDER - LAST NAME'
          }
        },
        'serviceDateRange' => {
          'from' => {
            'month' => {
              key: 'form1[0].#subform[94].Date_Entered_Active_Duty_Month[0]',
              limit: 2,
              question_num: 15,
              question_suffix: 'A',
              question_label: 'Date Entered Active Duty - Month',
              question_text: 'DATE ENTERED ACTIVE DUTY - MONTH'
            },
            'day' => {
              key: 'form1[0].#subform[94].Date_Entered_Active_Duty_Day[0]',
              limit: 2,
              question_num: 15,
              question_suffix: 'B',
              question_label: 'Date Entered Active Duty - Day',
              question_text: 'DATE ENTERED ACTIVE DUTY - DAY'
            },
            'year' => {
              key: 'form1[0].#subform[94].Date_Entered_Active_Duty_Year[0]',
              limit: 4,
              question_num: 15,
              question_suffix: 'C',
              question_label: 'Date Entered Active Duty - Year',
              question_text: 'DATE ENTERED ACTIVE DUTY - YEAR'
            }
          },
          'to' => {
            'month' => {
              key: 'form1[0].#subform[94].Date_Of_Release_From_Active_Duty_Month[0]',
              limit: 2,
              question_num: 16,
              question_suffix: 'A',
              question_label: 'Date Of Release From Active Duty - Month',
              question_text: 'DATE OF RELEASE FROM ACTIVE DUTY - MONTH'
            },
            'day' => {
              key: 'form1[0].#subform[94].Date_Of_Release_From_Active_Duty_Day[0]',
              limit: 2,
              question_num: 16,
              question_suffix: 'B',
              question_label: 'Date Of Release From Active Duty - Day',
              question_text: 'DATE OF RELEASE FROM ACTIVE DUTY - DAY'
            },
            'year' => {
              key: 'form1[0].#subform[94].Date_Of_Release_From_Active_Duty_Year[0]',
              limit: 4,
              question_num: 16,
              question_suffix: 'C',
              question_label: 'Date Of Release From Active Duty - Year',
              question_text: 'DATE OF RELEASE FROM ACTIVE DUTY - YEAR'
            }
          }
        },
        'militaryServiceNumber' => {
          key: 'form1[0].#subform[94].Service_Number[0]',
          question_num: 17,
          question_label: 'Service Number',
          question_text: 'SERVICE NUMBER'
        },
        'serviceBranch' => {
          'army' => {
            key: 'form1[0].#subform[94].Army[0]',
            question_num: 18,
            question_label: 'Service Branch - Army',
            question_text: 'SERVICE BRANCH - ARMY'
          },
          'navy' => {
            key: 'form1[0].#subform[94].Navy[0]',
            question_num: 18,
            question_label: 'Service Branch - Navy',
            question_text: 'SERVICE BRANCH - NAVY'
          },
          'airForce' => {
            key: 'form1[0].#subform[94].Air_Force[0]',
            question_num: 18,
            question_label: 'Service Branch - Air Force',
            question_text: 'SERVICE BRANCH - AIR FORCE'
          },
          'coastGuard' => {
            key: 'form1[0].#subform[94].Coast_Guard[0]',
            question_num: 18,
            question_label: 'Service Branch - Coast Guard',
            question_text: 'SERVICE BRANCH - COAST GUARD'
          },
          'marineCorps' => {
            key: 'form1[0].#subform[94].Marine_Corps[0]',
            question_num: 18,
            question_label: 'Service Branch - Marine Corps',
            question_text: 'SERVICE BRANCH - MARINE CORPS'
          },
          'spaceForce' => {
            key: 'form1[0].#subform[94].Space_Force[0]',
            question_num: 18,
            question_label: 'Service Branch - Space Force',
            question_text: 'SERVICE BRANCH - SPACE FORCE'
          },
          'usphs' => {
            key: 'form1[0].#subform[94].USPHS[0]',
            question_num: 18,
            question_label: 'Service Branch - USPHS',
            question_text: 'SERVICE BRANCH - USPHS'
          },
          'noaa' => {
            key: 'form1[0].#subform[94].NOAA[0]',
            question_num: 18,
            question_label: 'Service Branch - NOAA',
            question_text: 'SERVICE BRANCH - NOAA'
          }
        },
        'placeOfSeparation' => {
          key: 'form1[0].#subform[94].Place_Of_Last_Separation[0]',
          question_num: 19,
          question_label: 'Place Of Last Separation',
          question_text: 'PLACE OF LAST SEPARATION'
        },
        'powConfinement' => {
          key: 'form1[0].#subform[94].RadioButtonList[1]'
        },
        'powPeriods' => {
          limit: 2,
          'powDateRange' => {
            'from' => {
              'month' => {
                key: "form1[0].#subform[94].Date_Confinement_Started_Month[#{ITERATOR}]",
                limit: 2,
                question_num: 20,
                question_suffix: 'B',
                question_label: 'Date Confinement Started - Month',
                question_text: 'DATE CONFINEMENT STARTED - MONTH'
              },
              'day' => {
                key: "form1[0].#subform[94].Date_Confinement_Started_Day[#{ITERATOR}]",
                limit: 2,
                question_num: 20,
                question_suffix: 'B',
                question_label: 'Date Confinement Started - Day',
                question_text: 'DATE CONFINEMENT STARTED - DAY'
              },
              'year' => {
                key: "form1[0].#subform[94].Date_Confinement_Started_Year[#{ITERATOR}]",
                limit: 4,
                question_num: 20,
                question_suffix: 'B',
                question_label: 'Date Confinement Started - Year',
                question_text: 'DATE CONFINEMENT STARTED - YEAR'
              }
            },
            'to' => {
              'month' => {
                key: "form1[0].#subform[94].Date_Confinement_Ended_Month[#{ITERATOR}]",
                limit: 2,
                question_num: 20,
                question_suffix: 'C',
                question_label: 'Date Confinement Ended - Month',
                question_text: 'DATE CONFINEMENT ENDED - MONTH'
              },
              'day' => {
                key: "form1[0].#subform[94].Date_Confinement_Ended_Day[#{ITERATOR}]",
                limit: 2,
                question_num: 20,
                question_suffix: 'C',
                question_label: 'Date Confinement Ended - Day',
                question_text: 'DATE CONFINEMENT ENDED - DAY'
              },
              'year' => {
                key: "form1[0].#subform[94].Date_Confinement_Ended_Year[#{ITERATOR}]",
                limit: 4,
                question_num: 20,
                question_suffix: 'C',
                question_label: 'Date Confinement Ended - Year',
                question_text: 'DATE CONFINEMENT ENDED - YEAR'
              }
            }
          }
        }
      }.freeze
      ##
      # Expands the form data for Section 3.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        expand_previous_names(form_data)
        expand_service_date_range(form_data)
        expand_service_branch(form_data)
        expand_pow_confinement(form_data)
        expand_pow_periods(form_data)
      end

      ##
      # Expands previous names array into first and last name fields
      #
      # @param form_data [Hash]
      #
      # @return [void]
      def expand_previous_names(form_data)
        previous_names = form_data['previousNames']
        return if previous_names.blank?

        # Take the first previous name from the array
        name = previous_names.first
        return if name.blank?

        # First field: just first name
        # Last field: middle initial + last name + suffix
        middle_initial = name['middle'].present? ? name['middle'][0] : nil
        full_last = [middle_initial, name['last'], name['suffix']].compact.join(' ')

        form_data['previousNames'] = {
          'first' => name['first'],
          'last' => full_last
        }
      end

      ##
      # Expands service date range into month/day/year fields
      #
      # @param form_data [Hash]
      #
      # @return [void]
      def expand_service_date_range(form_data)
        date_range = form_data['serviceDateRange']
        return if date_range.blank?

        form_data['serviceDateRange'] = {
          'from' => split_date(date_range['from']),
          'to' => split_date(date_range['to'])
        }
      end

      ##
      # Expands service branch into checkboxes
      #
      # @param form_data [Hash]
      #
      # @return [void]
      def expand_service_branch(form_data)
        service_branch = form_data['serviceBranch']
        return if service_branch.blank?

        form_data['serviceBranch'] = {
          'army' => select_checkbox(service_branch == 'army'),
          'navy' => select_checkbox(service_branch == 'navy'),
          'airForce' => select_checkbox(service_branch == 'airForce'),
          'coastGuard' => select_checkbox(service_branch == 'coastGuard'),
          'marineCorps' => select_checkbox(service_branch == 'marineCorps'),
          'spaceForce' => select_checkbox(service_branch == 'spaceForce'),
          'usphs' => select_checkbox(service_branch == 'usphs'),
          'noaa' => select_checkbox(service_branch == 'noaa')
        }
      end

      ##
      # Expands POW confinement radio button based on presence of POW periods
      #
      # @param form_data [Hash]
      #
      # @return [void]
      def expand_pow_confinement(form_data)
        pow_periods = form_data['powPeriods']

        # Only set powConfinement if there are pow periods (set to yes/0)
        # If no periods, don't set the field at all (leave blank)
        return if pow_periods.blank?

        form_data['powConfinement'] = select_radio(true)
      end

      ##
      # Expands POW periods into month/day/year fields
      #
      # @param form_data [Hash]
      #
      # @return [void]
      def expand_pow_periods(form_data)
        pow_periods = form_data['powPeriods']
        return if pow_periods.blank?

        form_data['powPeriods'] = pow_periods.map do |period|
          {
            'powDateRange' => {
              'from' => split_date(period.dig('powDateRange', 'from')),
              'to' => split_date(period.dig('powDateRange', 'to'))
            }
          }
        end
      end
    end
  end
end
