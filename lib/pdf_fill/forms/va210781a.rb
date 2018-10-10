# frozen_string_literal: true

module PdfFill
  module Forms
    class Va210781a < FormBase
      include FormHelper
      
      INCIDENT_ITERATOR = PdfFill::HashConverter::ITERATOR
      KEY = {
        'veteranFullName' => {
          'first' => {
            key: 'F[0].Page_1[0].ClaimantsFirstName[0]',
            limit: 12,
            question_num: 1,
            question_text: "VETERAN/BENEFICIARY'S FIRST NAME"
          },
          'middleInitial' => {
            key: 'F[0].Page_1[0].ClaimantsMiddleInitial1[0]'
          },
          'last' => {
            key: 'F[0].Page_1[0].ClaimantsLastName[0]',
            limit: 18,
            question_num: 1,
            question_text: "VETERAN/BENEFICIARY'S LAST NAME"
          }
        },
        'veteranSocialSecurityNumber' => {
          'first' => {
            key: 'F[0].Page_1[0].ClaimantsSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'F[0].Page_1[0].ClaimantsSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'F[0].Page_1[0].ClaimantsSocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        'veteranSocialSecurityNumber1' => {
          'first' => {
            key: 'F[0].Page_2[0].VeteransSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'F[0].Page_2[0].VeteransSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'F[0].Page_2[0].VeteransSocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        'veteranSocialSecurityNumber2' => {
          'first' => {
            key: 'F[0].Page_3[0].VeteransSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'F[0].Page_3[0].VeteransSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'F[0].Page_3[0].VeteransSocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        'vaFileNumber' => {
          key: 'F[0].Page_1[0].VAFileNumber[0]'
        },
        'veteranDateOfBirth' => {
          'month' => {
            key: 'F[0].Page_1[0].DOBmonth[0]'
          },
          'day' => {
            key: 'F[0].Page_1[0].DOBday[0]'
          },
          'year' => {
            key: 'F[0].Page_1[0].DOByear[0]'
          }
        },
        'veteranServiceNumber' => {
          key: 'F[0].Page_1[0].VeteransServiceNumber[0]'
        },
        'email' => {
          key: 'F[0].Page_1[0].PreferredEmail[0]'
        },
        'veteranPhone' => {
          key: 'F[0].Page_1[0].PreferredEmail[1]'
        },
        'veteranSecondaryPhone' => {
          key: 'F[0].Page_1[0].PreferredEmail[2]'
        },
        'incident' => {
          limit: 2,
          'incidentDate' => {
            'month' => {
              key: "incidentDateMonth[#{INCIDENT_ITERATOR}]"
            },
            'day' => {
              key: "incidentDateDay[#{INCIDENT_ITERATOR}]"
            },
            'year' => {
              key: "incidentDateYear[#{INCIDENT_ITERATOR}]"
            }
          },
          'unitAssignedDates' => {
            'fromMonth' => {
              key: "unitAssignmentDateFromMonth[#{INCIDENT_ITERATOR}]"
            },
            'fromDay' => {
              key: "unitAssignmentDateFromDay[#{INCIDENT_ITERATOR}]"
            },
            'fromYear' => {
              key: "unitAssignmentDateFromYear[#{INCIDENT_ITERATOR}]"
            },
            'toMonth' => {
              key: "unitAssignmentDateToMonth[#{INCIDENT_ITERATOR}]"
            },
            'toDay' => {
              key: "unitAssignmentDateToDay[#{INCIDENT_ITERATOR}]"
            },
            'toYear' => {
              key: "unitAssignmentDateToYear[#{INCIDENT_ITERATOR}]"
            }
          }, 
          'incidentLocation' => {
            limit: 90,
            'firstRow' => {
              key: "incidentLocationFirstRow[#{INCIDENT_ITERATOR}]",
              limit: 30
            },
            'secondRow' => {
              key: "incidentLocationSecondRow[#{INCIDENT_ITERATOR}]",
              limit: 30
            },
            'thirdRow' => {
              key: "incidentLocationThirdRow[#{INCIDENT_ITERATOR}]",
              limit: 30
            }
          }
        },
        'otherInformation' => {
          key: 'F[0].Page_3[0].OtherInformation[0]',
          question_num: 12
        },
        'signature' => {
          key: 'F[0].Page_3[0].signature8[0]'
        },
        'signatureDate' => {
          key: 'F[0].Page_3[0].date9[0]'
        }
      }.freeze

      def expand_veteran_full_name
        @form_data['veteranFullName'] = extract_middle_i(@form_data, 'veteranFullName')
      end

      def expand_ssn
        ssn = @form_data['veteranSocialSecurityNumber']
        return if ssn.blank?
        ['', '1', '2'].each do |suffix|
          @form_data["veteranSocialSecurityNumber#{suffix}"] = split_ssn(ssn)
        end
      end

      def expand_veteran_dob
        veteran_date_of_birth = @form_data['veteranDateOfBirth']
        return if veteran_date_of_birth.blank?
        @form_data['veteranDateOfBirth'] = split_date(veteran_date_of_birth)
      end

      def expand_incident_date(incident)
        incident_date = incident['incidentDate']
        return if incident_date.blank?
        incident['incidentDate'] = split_date(incident_date)
      end

      def expand_unit_assignment_dates(incident)
        incidentUnitAssignedDates = incident['unitAssignedDates']
        return if incidentUnitAssignedDates.blank?
        fromDates = split_date(incidentUnitAssignedDates['from'])
        toDates = split_date(incidentUnitAssignedDates['to'])

        unitAssignmentDates = {
          'fromMonth' => fromDates['month'],
          'fromDay' => fromDates['day'],
          'fromYear' => fromDates['year'],
          'toMonth' => toDates['month'], 
          'toDay' => toDates['day'],
          'toYear' => toDates['year']
        }

        incidentUnitAssignedDates.except!('to')
        incidentUnitAssignedDates.except!('from')
        incidentUnitAssignedDates.merge!(unitAssignmentDates)
      end

      def expand_incident_location(incident)
        incident_location = incident['incidentLocation']
        return if incident_location.blank?

        if(incident_location.length <= 90)
          s_location = incident_location.split(" ")
          lineCharacterCount = 0
          line_arr = Array.new
          finished_lines = Array.new
  
          binding.pry
          s_location.each_with_index do |word, index|
            lineIsFull = lineCharacterCount + word.length < 30 ? false : true
            # if line is full, create a finished line, clear the collection, and start a new line collection
            if lineIsFull
              line = line_arr.join(" ")
              finished_lines.push(line)
              line_arr.clear
              line_arr.push(word)
              lineCharacterCount = word.length + 1
              
            else
              line_arr.push(word)
              lineCharacterCount += word.length + 1
            end

            if index == s_location.size - 1
              final_line = line_arr.join(" ")
              finished_lines.push(final_line)
            end
          end
        end

        split_incident_location = {
          'firstRow' => finished_lines.length > 0 ? finished_lines[0] : "",
          'secondRow' => finished_lines.length > 1 ? finished_lines[1] : "",
          'thirdRow' => finished_lines.length > 2 ? finished_lines[2] : ""
        }

        incident['incidentLocation'] = split_incident_location
      end

      def expand_incidents(incidents)
        return if incidents.blank?
        incidents.each do |incident|
          expand_incident_date(incident)
       #   expand_unit_assignment_dates(incident)
        end
      end

      def merge_fields
        expand_veteran_full_name
        expand_ssn
        expand_veteran_dob
        expand_incidents(@form_data['incident'])

        expand_signature(@form_data['veteranFullName'])
        @form_data['signature'] = '/es/ ' + @form_data['signature']

        @form_data
      end
    end
  end
end
