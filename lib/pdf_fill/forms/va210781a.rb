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
          first_key: 'incidentLocation',
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
            question_num: 8,
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
            },
            'incidentLocationOverflow' => {
              key: '',
              question_text: 'INCIDENT LOCATION',
              question_num: 8,
              question_suffix: 'C'
            }
          },
          'unitAssigned' => {
            question_num: 8,
            'firstRow' => {
              key: "unitAssignmentFirstRow[#{INCIDENT_ITERATOR}]",
              limit: 30
            },
            'secondRow' => {
              key: "unitAssignmentSecondRow[#{INCIDENT_ITERATOR}]",
              limit: 30
            },
            'thirdRow' => {
              key: "unitAssignmentThirdRow[#{INCIDENT_ITERATOR}]",
              limit: 30
            },
            'unitAssignedOverflow' => {
              key: '',
              question_text: 'UNIT ASSIGNED DURING INCIDENT',
              question_num: 9,
              question_suffix: 'D'
            }
          },
          'incidentDescription' => {
            key: "incidentDescription[#{INCIDENT_ITERATOR}]",
            question_num: 8,
            question_suffix: 'E'
          },
          'source' => {
            'combinedName0' => {
              key: "incident_source_name[#{INCIDENT_ITERATOR}][0]"
            },
            'combinedAddress0' => {
              key: "incident_source_address[#{INCIDENT_ITERATOR}][0]"
            },
            'combinedName1' => {
              key: "incident_source_name[#{INCIDENT_ITERATOR}][1]"
            },
            'combinedAddress1' => {
              key: "incident_source_address[#{INCIDENT_ITERATOR}][1]"
            },
            'combinedName2' => {
              key: "incident_source_name[#{INCIDENT_ITERATOR}][2]"
            },
            'combinedAddress2' => {
              key: "incident_source_address[#{INCIDENT_ITERATOR}][2]"
            },
            'sourceOverflow' => {
              key: '',
              question_num: 9,
              question_suffix: 'A',
              question_text: 'OTHER SOURCES OF INFORMATION ABOUT INCIDENT'
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

      def expand_unit_assigned_dates(incident)
        incident_unit_assigned_dates = incident['unitAssignedDates']
        return if incident_unit_assigned_dates.blank?
        from_dates = split_date(incident_unit_assigned_dates['from'])
        to_dates = split_date(incident_unit_assigned_dates['to'])

        unit_assignment_dates = {
          'fromMonth' => from_dates['month'],
          'fromDay' => from_dates['day'],
          'fromYear' => from_dates['year'],
          'toMonth' => to_dates['month'],
          'toDay' => to_dates['day'],
          'toYear' => to_dates['year']
        }

        incident_unit_assigned_dates.except!('to')
        incident_unit_assigned_dates.except!('from')
        incident_unit_assigned_dates.merge!(unit_assignment_dates)
      end

      def expand_incident_location(incident)
        incident_location = incident['incidentLocation']
        return if incident_location.blank?

        if incident_location.length <= 90
          s_location = incident_location.scan(/(.{1,30})(\s+|$)/)
          split_incident_location = {
            'firstRow' => s_location.length.positive? ? s_location[0][0] : '',
            'secondRow' => s_location.length > 1 ? s_location[1][0] : '',
            'thirdRow' => s_location.length > 2 ? s_location[2][0] : ''
          }
          incident['incidentLocation'] = split_incident_location

        else
          incident['incidentLocation'] = {}
          incident['incidentLocation']['incidentLocationOverflow'] = PdfFill::FormValue.new('', incident_location)
        end
      end

      def expand_incident_unit_assignment(incident)
        incident_unit_assignment = incident['unitAssigned']
        return if incident_unit_assignment.blank?

        if incident_unit_assignment.length <= 90
          s_incident_unit_assignment = incident_unit_assignment.scan(/(.{1,30})(\s+|$)/)
          split_incident_unit_assignment = {
            'firstRow' => s_incident_unit_assignment.length.positive? ? s_incident_unit_assignment[0][0] : '',
            'secondRow' => s_incident_unit_assignment.length > 1 ? s_incident_unit_assignment[1][0] : '',
            'thirdRow' => s_incident_unit_assignment.length > 2 ? s_incident_unit_assignment[2][0] : ''
          }
          incident['unitAssigned'] = split_incident_unit_assignment
        else
          incident['unitAssigned'] = {}
          incident['unitAssigned']['unitAssignedOverflow'] = PdfFill::FormValue.new('', incident_unit_assignment)
        end
      end

      def expand_other_sources(incident)
        return if incident.blank?

        incident_sources = incident['source']
        combined_sources = {}
        overflow_sources = []

        incident_sources.each_with_index do |source, index|
          combined_source_name = combine_full_name(source['name'])
          combined_source_address = combine_full_address(source['address'])

          combined_sources["combinedName#{index}"] = combined_source_name
          combined_sources["combinedAddress#{index}"] = combined_source_address

          overflow = combined_source_name + '\n' + combined_source_address
          overflow_sources.push(overflow)
        end

        if incident_sources.length > 3
          incident['source'] = {}
          overflow = overflow_sources.join('\n\n')
          incident['source']['sourceOverflow'] = PdfFill::FormValue.new('', overflow)
        else
          incident['source'] = combined_sources
        end
      end

      def expand_incidents(incidents)
        return if incidents.blank?
        incidents.each do |incident|
          expand_incident_date(incident)
          expand_unit_assigned_dates(incident)
          expand_incident_location(incident)
          expand_incident_unit_assignment(incident)
          expand_other_sources(incident)
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
