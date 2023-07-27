# frozen_string_literal: true

require 'pdf_fill/hash_converter'
require 'pdf_fill/forms/common_ptsd'
require 'pdf_fill/forms/form_base'

module PdfFill
  module Forms
    class Va210781a < FormBase
      include CommonPtsd

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
        'incidents' => {
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
          'combinedName0' => {
            limit: 80,
            key: "incident_source_name[#{ITERATOR}][0]"
          },
          'combinedAddress0' => {
            limit: 80,
            key: "incident_source_address[#{ITERATOR}][0]"
          },
          'combinedName1' => {
            limit: 80,
            key: "incident_source_name[#{ITERATOR}][1]"
          },
          'combinedAddress1' => {
            limit: 80,
            key: "incident_source_address[#{ITERATOR}][1]"
          },
          'combinedName2' => {
            limit: 80,
            key: "incident_source_name[#{ITERATOR}][2]"
          },
          'combinedAddress2' => {
            limit: 80,
            key: "incident_source_address[#{ITERATOR}][2]"
          },
          'incidentOverflow' => {
            key: '',
            question_text: 'INCIDENTS',
            question_num: 8,
            question_suffix: 'A'
          }
        },
        'otherInformation' => {
          question_text: 'OTHER INFORMATION',
          question_num: 12,
          limit: 11,
          first_key: 'value',
          'value' => {
            question_text: 'OTHER INFORMATION',
            question_num: 12,
            limit: 80,
            key: "F[0].Page_3[0].OtherInformation[#{ITERATOR}]"
          }
        },
        'signature' => {
          key: 'F[0].Page_3[0].signature8[0]'
        },
        'signatureDate' => {
          key: 'F[0].Page_3[0].date9[0]',
          format: 'date'
        },
        'additionalSecondaryIncidentText' => {
          question_num: 15,
          question_text: 'ADDITIONAL INCIDENTS',
          limit: 0,
          key: 'none'
        }
      }.freeze

      def merge_fields(_options = {})
        @form_data['veteranFullName'] = extract_middle_i(@form_data, 'veteranFullName')
        @form_data = expand_ssn(@form_data)
        @form_data['veteranDateOfBirth'] = expand_veteran_dob(@form_data)
        expand_incidents(@form_data['incidents'])
        expand_other_information

        expand_signature(@form_data['veteranFullName'])
        @form_data['signature'] = "/es/ #{@form_data['signature']}"

        @form_data
      end

      private

      def expand_other_information
        return if @form_data['otherInformation'].blank?

        @form_data['otherInformation'].map! do |other_info|
          { 'value' => other_info }
        end
      end

      def combine_source_name_address(incident)
        return if incident.blank? || incident['sources'].blank?

        incident['sources'].each_with_index do |source, index|
          combined_source_address = combine_full_address(source['address'])

          incident["combinedName#{index}"] = source['name']
          incident["combinedAddress#{index}"] = combined_source_address
        end

        incident.except!('sources')
      end

      def combine_other_sources_overflow(incident)
        return if incident.blank? || incident['sources'].blank?

        sources = incident['sources']
        overflow_sources = []

        sources.each do |source|
          overflow = "#{source['name']} \n #{combine_full_address(source['address'])}"
          overflow_sources.push(overflow)
        end

        overflow_sources.join(" \n\n ")
      end

      def format_sources_overflow(incident)
        other_sources_overflow = combine_other_sources_overflow(incident)
        other_sources_overflow.nil? ? '' : other_sources_overflow
      end

      def format_incident_overflow(incident, index)
        incident_overflow = format_incident(incident, index)

        return if incident_overflow.nil?

        incident_overflow.push("Other Sources of Information: \n\n#{format_sources_overflow(incident)}")
        incident['incidentOverflow'] = PdfFill::FormValue.new('', incident_overflow.compact.join("\n\n"))
      end

      def combine_full_address(address)
        return '' if address.blank?

        combine_hash(
          address,
          %w[
            addressLine1
            addressLine2
            city
            state
            zipCode
            country
          ],
          ', '
        )
      end

      def expand_incidents(incidents)
        return if incidents.blank?

        incidents.each_with_index do |incident, index|
          format_incident_overflow(incident, index + 1)
          incident['incidentDate'] = expand_incident_date(incident)
          expand_unit_assigned_dates(incident)
          incident['incidentLocation'] = expand_incident_location(incident)
          incident['unitAssigned'] = expand_incident_unit_assignment(incident)
          combine_source_name_address(incident)
        end
      end
    end
  end
end
