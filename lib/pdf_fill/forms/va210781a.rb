# frozen_string_literal: true

module PdfFill
  module Forms
    class Va210781a < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'veteranFullName' => {
          'first' => {
            key: 'F[0].Page_1[0].ClaimantsFirstName[0]',
            limit: 12,
            question_num: 1,
            question_suffix: 'A',
            question_text: "VETERAN/BENEFICIARY'S FIRST NAME"
          },
          'middleInitial' => {
            key: 'F[0].Page_1[0].ClaimantsMiddleInitial1[0]'
          },
          'last' => {
            key: 'F[0].Page_1[0].ClaimantsLastName[0]',
            limit: 18,
            question_num: 1,
            question_suffix: 'B',
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
          first_key: 'incidentDescription',
          question_text: 'INCIDENTS',
          question_num: 8,
          'incidentDate' => {
            'month' => {
              key: "incidentDateMonth[#{ITERATOR}]"
            },
            'day' => {
              key: "incidentDateDay[#{ITERATOR}]"
            },
            'year' => {
              key: "incidentDateYear[#{ITERATOR}]"
            }
          },
          'unitAssignedDates' => {
            'fromMonth' => {
              key: "unitAssignmentDateFromMonth[#{ITERATOR}]"
            },
            'fromDay' => {
              key: "unitAssignmentDateFromDay[#{ITERATOR}]"
            },
            'fromYear' => {
              key: "unitAssignmentDateFromYear[#{ITERATOR}]"
            },
            'toMonth' => {
              key: "unitAssignmentDateToMonth[#{ITERATOR}]"
            },
            'toDay' => {
              key: "unitAssignmentDateToDay[#{ITERATOR}]"
            },
            'toYear' => {
              key: "unitAssignmentDateToYear[#{ITERATOR}]"
            }
          },
          'incidentLocation' => {
            question_num: 8,
            limit: 3,
            first_key: 'row0',
            'row0' => {
              key: "incidentLocationFirstRow[#{ITERATOR}]"
            },
            'row1' => {
              key: "incidentLocationSecondRow[#{ITERATOR}]"
            },
            'row2' => {
              key: "incidentLocationThirdRow[#{ITERATOR}]"
            }
          },
          'unitAssigned' => {
            question_num: 8,
            limit: 3,
            'row0' => {
              key: "unitAssignmentFirstRow[#{ITERATOR}]",
              limit: 30
            },
            'row1' => {
              key: "unitAssignmentSecondRow[#{ITERATOR}]",
              limit: 30
            },
            'row2' => {
              key: "unitAssignmentThirdRow[#{ITERATOR}]",
              limit: 30
            }
          },
          'incidentDescription' => {
            key: "incidentDescription[#{ITERATOR}]"
          },
          'source' => {
            limit: 6,
            first_key: 'combinedName0',
            'combinedName0' => {
              key: "incident_source_name[#{ITERATOR}][0]"
            },
            'combinedAddress0' => {
              key: "incident_source_address[#{ITERATOR}][0]"
            },
            'combinedName1' => {
              key: "incident_source_name[#{ITERATOR}][1]"
            },
            'combinedAddress1' => {
              key: "incident_source_address[#{ITERATOR}][1]"
            },
            'combinedName2' => {
              key: "incident_source_name[#{ITERATOR}][2]"
            },
            'combinedAddress2' => {
              key: "incident_source_address[#{ITERATOR}][2]"
            }
          },
          'incidentOverflow' => {
            key: '',
            question_text: 'INCIDENTS',
            question_num: 8,
            question_suffix: 'A'
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

      def merge_fields
        expand_veteran_full_name
        expand_ssn
        expand_veteran_dob
        expand_incidents(@form_data['incident'])

        expand_signature(@form_data['veteranFullName'])
        @form_data['signature'] = '/es/ ' + @form_data['signature']

        @form_data
      end

      private

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

        split_incident_location = {}
        s_location = incident_location.scan(/(.{1,30})(\s+|$)/)

        s_location.each_with_index do |row, index|
          split_incident_location["row#{index}"] = row[0]
        end

        incident['incidentLocation'] = split_incident_location
      end

      def expand_incident_unit_assignment(incident)
        incident_unit_assignment = incident['unitAssigned']
        return if incident_unit_assignment.blank?

        split_incident_unit_assignment = {}
        s_incident_unit_assignment = incident_unit_assignment.scan(/(.{1,30})(\s+|$)/)

        s_incident_unit_assignment.each_with_index do |row, index|
          split_incident_unit_assignment["row#{index}"] = row[0]
        end

        incident['unitAssigned'] = split_incident_unit_assignment
      end

      def get_unit_date_overflow(unit_assigned_dates)
        unit_assigned_dates_overflow = combine_date_ranges(unit_assigned_dates)
        unit_assigned_dates_overflow.nil? ? '' : unit_assigned_dates_overflow
      end

      def combine_source_name_address(incident)
        return if incident.blank?

        incident_sources = incident['source']
        combined_sources = {}

        incident_sources.each_with_index do |source, index|
          combined_source_name = combine_full_name(source['name'])
          combined_source_address = combine_full_address(source['address'])

          combined_sources["combinedName#{index}"] = combined_source_name
          combined_sources["combinedAddress#{index}"] = combined_source_address
        end

        incident['source'] = combined_sources
      end

      def combine_other_sources_overflow(incident)
        return if incident.blank? || incident['source'].blank?

        sources = incident['source']
        overflow_sources = []

        sources.each do |source|
          overflow = combine_full_name(source['name']) + " \n " + combine_full_address(source['address'])
          overflow_sources.push(overflow)
        end

        overflow_sources.join(" \n\n ")
      end

      def format_sources_overflow(incident)
        other_sources_overflow = combine_other_sources_overflow(incident)
        other_sources_overflow.nil? ? '' : other_sources_overflow
      end

      def expand_incident_overflow(incident, index)
        return if incident.blank?
        incident_overflow = ["Incident Number: #{index}"]

        incident_date = incident['incidentDate'].nil? ? '' : incident['incidentDate']
        incident_overflow.push('Incident Date: ' + incident_date)

        incident_overflow.push('Dates of Unit Assignment: ' + get_unit_date_overflow([incident['unitAssignedDates']]))

        incident_location = incident['incidentLocation'].nil? ? '' : incident['incidentLocation']
        incident_overflow.push("Incident Location: \n\n" + incident_location)

        incident_unit_assigned = incident['unitAssigned'].nil? ? '' : incident['unitAssigned']
        incident_overflow.push("Unit Assignment During Incident: \n\n" + incident_unit_assigned)

        incident_description = incident['incidentDescription'].nil? ? '' : incident['incidentDescription']
        incident_overflow.push("Description of Incident: \n\n" + incident_description)

        incident_overflow.push("Other Sources of Information: \n\n" + format_sources_overflow(incident))

        incident['incidentOverflow'] = PdfFill::FormValue.new('', incident_overflow.compact.join("\n\n"))
      end

      def expand_incidents(incidents)
        return if incidents.blank?

        incidents.each_with_index do |incident, index|
          expand_incident_overflow(incident, index + 1)
          expand_incident_date(incident)
          expand_unit_assigned_dates(incident)
          expand_incident_location(incident)
          expand_incident_unit_assignment(incident)
          combine_source_name_address(incident)
        end
      end
    end
  end
end
