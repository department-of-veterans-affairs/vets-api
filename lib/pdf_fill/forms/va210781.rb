# frozen_string_literal: true

module PdfFill
  module Forms
    class Va210781 < FormBase
      include FormHelper

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
        'incident' => {
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
          'personInvolved' => {
            limit: 22,
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
            'injuryDeath0' => {
              'checkbox' => {
                'killedinAction' => {
                  key: 'form1[0].#subform[1].KILLEDINACTION4[0]'
                },
                'killedInNonBattle' => {
                  key: 'form1[0].#subform[1].KILLEDNONBATTLE4[0]'
                },
                'woundedInAction' => {
                  key: 'form1[0].#subform[1].WOUNDEDINACTION4[0]'
                },
                'injuredNonBattle' => {
                  key: 'form1[0].#subform[1].INJUREDNONBATTLE4[0]'
                },
                'Other' => {
                  key: 'form1[0].#subform[1].WOUNDEDINACTION4[1]'
                }
              }
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
            'injuryDeath1' => {
              'checkbox' => {
                'killedinAction' => {
                  key: 'form1[0].#subform[1].KILLEDINACTION4[0]'
                },
                'killedInNonBattle' => {
                  key: 'form1[0].#subform[1].KILLEDNONBATTLE4[0]'
                },
                'woundedInAction' => {
                  key: 'form1[0].#subform[1].WOUNDEDINACTION4[0]'
                },
                'injuredNonBattle' => {
                  key: 'form1[0].#subform[1].INJUREDNONBATTLE4[0]'
                },
                'Other' => {
                  key: 'form1[0].#subform[1].WOUNDEDINACTION4[1]'
                }
              }
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
            } 
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
          key: 'form1[0].#subform[2].Date11[0]'
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

      def expand_incidents(incidents)
        return if incidents.blank?

        incidents.each_with_index do |incident, index|
          # expand_incident_extras(incident, index + 1)
          expand_incident_date(incident)
          expand_unit_assigned_dates(incident)
          expand_incident_location(incident)
          expand_incident_unit_assignment(incident)
          expand_persons_involved(incident)

        end
      end

      def expand_persons_involved(incident)
        return if incident.blank?
        return if incident['personInvolved'].blank?

        personsInvolved = incident['personInvolved']
        personsInvolved.each_with_index do |personInvolved, index|
          expand_injury_death_date(personInvolved, index)
          split_person_unit_assignment(personInvolved, index)
          flatten_person_identification(personInvolved, index)
          resolve_cause_injury_death(personInvolved, index)
        end

        combined_persons_involved = {}
        personsInvolved.each do | person |
          person.each do |key, value|
            combined_persons_involved[key] = value
          end
        end
        incident['personInvolved'] = combined_persons_involved

      end

      def expand_injury_death_date(personInvolved, index)
        injury_date = personInvolved['injuryDeathDate']
        return if injury_date.blank?
        s_date = split_date(injury_date)
        personInvolved["injuryDeathDateMonth#{index}"] = s_date['month']
        personInvolved["injuryDeathDateDay#{index}"] = s_date['day']
        personInvolved["injuryDeathDateYear#{index}"] = s_date['year']
        personInvolved.except!('injuryDeathDate')
      end

      def split_person_unit_assignment(personInvolved, index)
        incident_unit_assignment = personInvolved['unitAssigned']
        return if incident_unit_assignment.blank?

        s_incident_unit_assignment = incident_unit_assignment.scan(/(.{1,30})(\s+|$)/)
        s_incident_unit_assignment.each_with_index do |row, row_index|
          personInvolved["unitAssigned#{index}Row#{row_index}"] = row[0]
        end
        personInvolved.except!('unitAssigned')
      end

      def flatten_person_identification(personInvolved, index) 
        return if personInvolved.blank?

        extract_middle_i(personInvolved, 'name')
        personInvolved["first#{index}"] = personInvolved['name']['first']        
        personInvolved["middleInitial#{index}"] = personInvolved['name']['middleInitial']        
        personInvolved["last#{index}"] = personInvolved['name']['last']        
        personInvolved.except!('name')

        personInvolved["rank#{index}"] = personInvolved['rank']
        personInvolved.except!('rank')
      end

      def resolve_cause_injury_death(personInvolved, index)
        return if personInvolved.blank?
        
        cause = personInvolved['injuryDeath']
        personInvolved["injuryDeath#{index}"] = {}
        
        enum: [
          ‘Killed in Action’,
          ‘Killed Non-Battle’,
          ‘Wounded in Action’,
          ‘Injured Non-Battle’,
          ‘Other’,

          'killedInAction' => {
          },
          'killedNonBattle' => {
          },
          'woundedInAction' => {
          },
          'injuredNonBattle' => {
          },
          'Other' => {


        case cause
        when 'Killed in Action'
          personInvolved["injuryDeath#{index}"]['killedInAction'] = true
        when 'Killed Non-Battle'
          personInvolved["injuryDeath#{index}"]['killedInAction'] = true



          personInvolved["injuryDeathOther#{index}"] = personInvolved['injuryDeathOther']

      end

    end
  end
end