# frozen_string_literal: true

require 'pdf_fill/hash_converter'
require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/common_ptsd'

# rubocop:disable Metrics/ClassLength

module PdfFill
  module Forms
    class Va210781 < FormBase
      include CommonPtsd

      INCIDENT_ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'veteranFullName' => {
          'first' => {
            key: 'form1[0].#subform[0].ClaimantsFirstName[0]',
            limit: 12,
            question_num: 1,
            question_suffix: 'A',
            question_text: "VETERAN/BENEFICIARY'S FIRST NAME"
          },
          'middleInitial' => {
            key: 'form1[0].#subform[0].ClaimantsMiddleInitial1[0]'
          },
          'last' => {
            key: 'form1[0].#subform[0].ClaimantsLastName[0]',
            limit: 18,
            question_num: 1,
            question_suffix: 'B',
            question_text: "VETERAN/BENEFICIARY'S LAST NAME"
          }
        },
        'veteranSocialSecurityNumber' => {
          'first' => {
            key: 'form1[0].#subform[0].ClaimantsSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'form1[0].#subform[0].ClaimantsSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[0].ClaimantsSocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        'veteranSocialSecurityNumber1' => {
          'first' => {
            key: 'form1[0].#subform[1].VeteransSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'form1[0].#subform[1].VeteransSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[1].VeteransSocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        'veteranSocialSecurityNumber2' => {
          'first' => {
            key: 'form1[0].#subform[2].VeteransSocialSecurityNumber_FirstThreeNumbers[1]'
          },
          'second' => {
            key: 'form1[0].#subform[2].VeteransSocialSecurityNumber_SecondTwoNumbers[1]'
          },
          'third' => {
            key: 'form1[0].#subform[2].VeteransSocialSecurityNumber_LastFourNumbers[1]'
          }
        },
        'vaFileNumber' => {
          key: 'form1[0].#subform[0].VAFileNumber[0]'
        },
        'veteranDateOfBirth' => {
          'month' => {
            key: 'form1[0].#subform[0].DOBmonth[0]'
          },
          'day' => {
            key: 'form1[0].#subform[0].DOBday[0]'
          },
          'year' => {
            key: 'form1[0].#subform[0].DOByear[0]'
          }
        },
        'veteranServiceNumber' => {
          key: 'form1[0].#subform[0].VeteransServiceNumber[0]'
        },
        'email' => {
          key: 'form1[0].#subform[0].PreferredEmail[0]'
        },
        'veteranPhone' => {
          key: 'form1[0].#subform[0].PreferredEmail[1]'
        },
        'veteranSecondaryPhone' => {
          key: 'form1[0].#subform[0].PreferredEmail[2]'
        },
        'incidents' => {
          limit: 2,
          first_key: 'incidentDescription',
          question_text: 'INCIDENTS',
          question_num: 8,
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
            question_num: 8,
            limit: 3,
            first_key: 'row0',
            'row0' => {
              key: "incidentLocationFirstRow[#{INCIDENT_ITERATOR}]"
            },
            'row1' => {
              key: "incidentLocationSecondRow[#{INCIDENT_ITERATOR}]"
            },
            'row2' => {
              key: "incidentLocationThirdRow[#{INCIDENT_ITERATOR}]"
            }
          },
          'unitAssigned' => {
            question_num: 8,
            limit: 3,
            'row0' => {
              key: "unitAssignmentFirstRow[#{INCIDENT_ITERATOR}]",
              limit: 30
            },
            'row1' => {
              key: "unitAssignmentSecondRow[#{INCIDENT_ITERATOR}]",
              limit: 30
            },
            'row2' => {
              key: "unitAssignmentThirdRow[#{INCIDENT_ITERATOR}]",
              limit: 30
            }
          },
          'incidentDescription' => {
            key: "incidentDescription[#{INCIDENT_ITERATOR}]"
          },
          'medalsCitations' => {
            key: "medalsCitations[#{INCIDENT_ITERATOR}]"
          },
          'first0' => {
            key: "personInvolvedFirst[0][#{INCIDENT_ITERATOR}]",
            limit: 12
          },
          'middleInitial0' => {
            key: "personInvolvedMiddleI[0][#{INCIDENT_ITERATOR}]"
          },
          'last0' => {
            key: "personInvolvedLast[0][#{INCIDENT_ITERATOR}]",
            limit: 18
          },
          'rank0' => {
            key: "personInvolvedRank[0][#{INCIDENT_ITERATOR}]"
          },
          'injuryDeathDateMonth0' => {
            key: "injuryDeathDateMonth[0][#{INCIDENT_ITERATOR}]"
          },
          'injuryDeathDateDay0' => {
            key: "injuryDeathDateDay[0][#{INCIDENT_ITERATOR}]"
          },
          'injuryDeathDateYear0' => {
            key: "injuryDeathDateYear[0][#{INCIDENT_ITERATOR}]"
          },
          'killedInAction0' => {
            key: "killedInAction0[#{INCIDENT_ITERATOR}]"
          },
          'killedNonBattle0' => {
            key: "killedNonBattle0[#{INCIDENT_ITERATOR}]"
          },
          'woundedInAction0' => {
            key: "woundedInAction0[#{INCIDENT_ITERATOR}]"
          },
          'injuredNonBattle0' => {
            key: "injuredNonBattle0[#{INCIDENT_ITERATOR}]"
          },
          'other0' => {
            key: "other0[#{INCIDENT_ITERATOR}]"
          },
          'otherText0' => {
            key: "otherText0[#{INCIDENT_ITERATOR}]"
          },
          'unitAssigned0Row0' => {
            key: "personUnitAssignedRow0[0][#{INCIDENT_ITERATOR}]",
            limit: 30
          },
          'unitAssigned0Row1' => {
            key: "personUnitAssignedRow1[0][#{INCIDENT_ITERATOR}]",
            limit: 30
          },
          'unitAssigned0Row2' => {
            key: "personUnitAssignedRow2[0][#{INCIDENT_ITERATOR}]",
            limit: 30
          },
          'description0' => {
            always_overflow: true
          },
          'first1' => {
            key: "personInvolvedFirst[1][#{INCIDENT_ITERATOR}]",
            limit: 12
          },
          'middleInitial1' => {
            key: "personInvolvedMiddleI[1][#{INCIDENT_ITERATOR}]"
          },
          'last1' => {
            key: "personInvolvedLast[1][#{INCIDENT_ITERATOR}]",
            limit: 18
          },
          'rank1' => {
            key: "personInvolvedRank[1][#{INCIDENT_ITERATOR}]"
          },
          'injuryDeathDateMonth1' => {
            key: "injuryDeathDateMonth[1][#{INCIDENT_ITERATOR}]"
          },
          'injuryDeathDateDay1' => {
            key: "injuryDeathDateDay[1][#{INCIDENT_ITERATOR}]"
          },
          'injuryDeathDateYear1' => {
            key: "injuryDeathDateYear[1][#{INCIDENT_ITERATOR}]"
          },
          'killedInAction1' => {
            key: "killedInAction1[#{INCIDENT_ITERATOR}]"
          },
          'killedNonBattle1' => {
            key: "killedNonBattle1[#{INCIDENT_ITERATOR}]"
          },
          'woundedInAction1' => {
            key: "woundedInAction1[#{INCIDENT_ITERATOR}]"
          },
          'injuredNonBattle1' => {
            key: "injuredNonBattle1[#{INCIDENT_ITERATOR}]"
          },
          'other1' => {
            key: "other1[#{INCIDENT_ITERATOR}]"
          },
          'otherText1' => {
            key: "otherText1[#{INCIDENT_ITERATOR}]"
          },
          'unitAssigned1Row0' => {
            key: "personUnitAssignedRow0[1][#{INCIDENT_ITERATOR}]",
            limit: 30
          },
          'unitAssigned1Row1' => {
            key: "personUnitAssignedRow1[1][#{INCIDENT_ITERATOR}]",
            limit: 30
          },
          'unitAssigned1Row2' => {
            key: "personUnitAssignedRow2[1][#{INCIDENT_ITERATOR}]",
            limit: 30
          },
          'description1' => {
            always_overflow: true
          },
          'incidentOverflow' => {
            key: '',
            question_text: 'INCIDENTS',
            question_num: 8,
            question_suffix: 'A'
          },
          'personsInvolvedArray' => {
            limit: 2
          }
        },
        'remarks' => {
          key: 'form1[0].#subform[2].REMARKS[0]',
          question_num: 14
        },
        'signature' => {
          key: 'form1[0].#subform[2].Signature[0]'
        },
        'signatureDate' => {
          key: 'form1[0].#subform[2].Date11[0]',
          format: 'date'
        },
        'additionalIncidentText' => {
          question_num: 17,
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

        expand_signature(@form_data['veteranFullName'])
        @form_data['signature'] = "/es/ #{@form_data['signature']}"

        @form_data
      end

      private

      def expand_incidents(incidents)
        return if incidents.blank?

        incidents.each_with_index do |incident, index|
          format_incident_overflow(incident, index + 1)
          incident['incidentDate'] = expand_incident_date(incident)
          expand_unit_assigned_dates(incident)
          incident['incidentLocation'] = expand_incident_location(incident)
          incident['unitAssigned'] = expand_incident_unit_assignment(incident)
          expand_persons_involved(incident)
        end
      end

      def expand_persons_involved(incident)
        return if incident.blank?
        return if incident['personsInvolved'].blank?

        persons_involved = incident['personsInvolved']
        persons_involved.each_with_index do |person_involved, index|
          expand_injury_death_date(person_involved, index)
          split_person_unit_assignment(person_involved, index)
          flatten_person_identification(person_involved, index)
          resolve_cause_injury_death(person_involved, index)

          person_involved.map do |k, v|
            incident[k] = v
          end
        end

        incident['personsInvolvedArray'] = incident['personsInvolved']

        incident.except!('personsInvolved')
      end

      def expand_injury_death_date(person_involved, index)
        injury_date = person_involved['injuryDeathDate']
        return if injury_date.blank?

        s_date = split_approximate_date(injury_date)
        person_involved["injuryDeathDateMonth#{index}"] = s_date['month']
        person_involved["injuryDeathDateDay#{index}"] = s_date['day']
        person_involved["injuryDeathDateYear#{index}"] = s_date['year']
        person_involved.except!('injuryDeathDate')
      end

      def split_person_unit_assignment(person_involved, index)
        incident_unit_assignment = person_involved['unitAssigned']
        return if incident_unit_assignment.blank?

        s_incident_unit_assignment = incident_unit_assignment.scan(/(.{1,30})(\s+|$)/)
        s_incident_unit_assignment.each_with_index do |row, row_index|
          person_involved["unitAssigned#{index}Row#{row_index}"] = row[0]
        end
        person_involved.except!('unitAssigned')
      end

      def flatten_person_identification(person_involved, index)
        return if person_involved.blank?

        flatten_person_name(person_involved, index) if person_involved['name'].present?

        unless person_involved['description'].nil?
          person_involved["description#{index}"] = person_involved['description']
          person_involved.except!('description')
        end

        person_involved.except!('name')

        person_involved["rank#{index}"] = person_involved['rank']
        person_involved.except!('rank')
      end

      def flatten_person_name(person_involved, index)
        extract_middle_i(person_involved, 'name')
        person_involved["first#{index}"] = person_involved['name']['first']
        person_involved["middleInitial#{index}"] = person_involved['name']['middleInitial']
        person_involved["last#{index}"] = person_involved['name']['last']
      end

      def resolve_cause_injury_death(person_involved, index)
        return if person_involved.blank?

        cause = person_involved['injuryDeath']
        person_involved["#{cause}#{index}"] = true
        if cause == 'other'
          person_involved["otherText#{index}"] = person_involved['injuryDeathOther']
          person_involved.except!('injuryDeathOther')
        end
        person_involved.except!('injuryDeath')
      end

      def format_incident_overflow(incident, index)
        incident_overflow = format_incident(incident, index)

        return if incident_overflow.nil?

        incident_medals_citations = incident['medalsCitations'] || ''
        incident_overflow.push("Medals Or Citations: \n\n#{incident_medals_citations}")

        incident_overflow.push("Persons Involved: \n\n#{format_persons_involved(incident)}")
        incident['incidentOverflow'] = PdfFill::FormValue.new('', incident_overflow.compact.join("\n\n"))
      end

      def format_persons_involved(incident)
        return if incident.blank?

        persons_involved = incident['personsInvolved']
        return '' if persons_involved.blank?

        overflow_people = []
        persons_involved.each do |person|
          overflow_people.push(format_one_person(person))
        end

        overflow_people.join("\n\n")
      end

      def format_one_person(person)
        cause = format_cause_enum(person['injuryDeath'])

        overflow_person = []
        overflow_person.push(combine_full_name(person['name']))
        overflow_person.push("Description: #{person['description']}") unless person['description'].nil?
        overflow_person.push("Rank: #{person['rank']}") unless person['rank'].nil?
        overflow_person.push("Unit Assigned: #{person['unitAssigned']}") unless person['unitAssigned'].nil?
        overflow_person.push("Injury or Death Date: #{person['injuryDeathDate']}") unless person['injuryDeathDate'].nil?
        overflow_person.push("Injury or Death Cause: #{cause}") unless cause.empty?
        overflow_person.join("\n")
      end

      def format_cause_enum(cause)
        cause_map = {
          'killedInAction' => 'Killed in Action',
          'killedNonBattle' => 'Killed Non-Battle',
          'woundedInAction' => 'Wounded in Action',
          'injuredNonBattle' => 'Injured Non-Battle',
          'other' => 'Other'
        }
        cause.nil? ? '' : cause_map[cause]
      end
    end
  end
end

# rubocop:enable Metrics/ClassLength
