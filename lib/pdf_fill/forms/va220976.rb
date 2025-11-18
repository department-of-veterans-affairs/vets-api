# frozen_string_literal: true

module PdfFill
  module Forms
    class Va220976 < FormBase
      include FormHelper

      INSTITUTION_TYPE_ENUM = {
        'public' => 'PUBLIC',
        'privateForProfit' => 'PRIVATE-FOR-PROFIT',
        'privateNotForProfit' => 'PRIVATE-NOT-FOR-PROFIT'
      }.freeze

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'primaryInstitution' => {
          'institutionName' => {
            key: 'institution_name'
          },
          'vaFacilityCode' => {
            key: 'institution_facility_code'
          },
          'physicalAddress' => {
            key: 'institution_physical_address'
          },
          'mailingAddress' => {
            key: 'institution_mailing_address'
          },
          'country' => {
            key: 'institution_country'
          },
          'website' => {
            key: 'institution_website'
          }
        },
        'generalInfo' => {
          'typeInitial' => {
            key: 'submission_type_initial'
          },
          'typeApproval' => {
            key: 'submission_type_approval'
          },
          'typeReapproval' => {
            key: 'submission_type_reapproval'
          },
          'typeUpdate' => {
            key: 'submission_type_update'
          },
          'typeOther' => {
            key: 'submission_type_other'
          },
          'otherExplanation' => {
            key: 'other_explanation'
          },
          'updateExplanation' => {
            key: 'update_explanation'
          },
          'institutionType' => {
            key: 'institution_type'
          },
          'isHigherLearning' => {
            key: 'is_higher_learning'
          },
          'isTitle4' => {
            key: 'is_title_4'
          },
          'higherLearningDescription' => {
            key: 'is_higher_learning_description'
          },
          'title4Description' => {
            key: 'is_title_4_description'
          }
        },
        'branches' => {
          limit: 4,
          label_all: true,
          'name' => {
            key: "branch_#{ITERATOR}_name"
          },
          'address' => {
            key: "branch_#{ITERATOR}_address"
          }
        },
        'programs' => {
          limit: 4,
          label_all: true,
          'programName' => {
            key: "degree_program_#{ITERATOR}_name"
          },
          'totalProgramLength' => {
            key: "degree_program_#{ITERATOR}_length"
          },
          'weeksPerTerm' => {
            key: "degree_program_#{ITERATOR}_weeks_per_term"
          },
          'entryRequirements' => {
            key: "degree_program_#{ITERATOR}_entry_requirements"
          },
          'creditHours' => {
            key: "degree_program_#{ITERATOR}_credit_hours"
          }
        },
        'acknowledgement7' => {
          key: 'authorizing_initials_1'
        },
        'acknowledgement8' => {
          key: 'authorizing_initials_2'
        },
        'acknowledgement9' => {
          key: 'authorizing_initials_3'
        },
        'acknowledgement10a' => {
          'financiallySound' => {
            key: 'is_financially_sound'
          },
          'financialSoundnessExplanation' => {
            key: 'financially_sound_description'
          }
        },
        'acknowledgement10b' => {
          key: 'authorizing_initials_4'
        },
        'faculty' => {
          limit: 7,
          label_all: true,
          'name' => {
            key: "faculty_#{ITERATOR}_name"
          },
          'title' => {
            key: "faculty_#{ITERATOR}_title"
          }
        },
        'medicalData' => {
          'isInWDOMS' => {
            key: 'is_listed_as_medical_school'
          },
          'accreditingAgency' => {
            key: 'accrediting_authority_name'
          },
          'providesClassroomInstruction' => {
            key: 'provides_clinical_program'
          },
          'hasRecentGraduatingClasses' => {
            key: 'has_graduated_classes'
          },
          'graduation1Date' => {
            key: 'graduating_class_1_date'
          },
          'graduation1NumStudents' => {
            key: 'graduating_class_1_num_graduated'
          },
          'graduation2Date' => {
            key: 'graduating_class_2_date'
          },
          'graduation2NumStudents' => {
            key: 'graduating_class_2_num_graduated'
          }
        },
        'contactInfo' => {
          'financialRepName' => {
            key: 'financial_rep_name'
          },
          'financialRepEmail' => {
            key: 'financial_rep_email'
          },
          'scoRepName' => {
            key: 'sco_name'
          },
          'scoRepEmail' => {
            key: 'sco_email'
          },
          'authorizingOfficialName' => {
            key: 'authorizing_official_name'
          },
          'authorizingOfficialSignature' => {
            key: 'authorizing_official_signature'
          }
        },
        'dateSigned' => {
          key: 'date_signed'
        }
      }.freeze

      def merge_fields(_options = {})
        form_data = JSON.parse(JSON.generate(@form_data))

        format_general_info(form_data)
        format_institutions(form_data)
        format_acknowledgements(form_data)
        format_faculty(form_data)
        format_medical_data(form_data)
        format_contacts(form_data)
        form_data
      end

      def format_institutions(form_data)
        form_data['primaryInstitution'] = form_data['institutionDetails'].first
        form_data['primaryInstitution']['physicalAddress'] =
          combine_full_address(form_data['primaryInstitution']['physicalAddress'])
        form_data['primaryInstitution']['mailingAddress'] =
          combine_full_address(form_data['primaryInstitution']['mailingAddress'])
        form_data['primaryInstitution']['country'] =
          if form_data['primaryInstitution']['isForeignCountry']
            form_data['primaryInstitution']['physicalAddress']['country']
          else
            ''
          end
        form_data['primaryInstitution']['website'] = form_data['website']

        form_data['branches'] = form_data['institutionDetails'][1..].map do |data|
          {
            'name' => data['institutionName'],
            'address' => combine_full_address(data['physicalAddress'])
          }
        end
      end

      def format_general_info(form_data)
        form_data['generalInfo'] = {
          'typeInitial' => form_data['submissionReasons']['initialApplication'] ? 'Yes' : 'Off',
          'typeApproval' => form_data['submissionReasons']['approvalOfNewPrograms'] ? 'Yes' : 'Off',
          'typeReapproval' => form_data['submissionReasons']['reapproval'] ? 'Yes' : 'Off',
          'typeUpdate' => form_data['submissionReasons']['updateInformation'] ? 'Yes' : 'Off',
          'typeOther' => form_data['submissionReasons']['other'] ? 'Yes' : 'Off',
          'updateExplanation' => form_data['submissionReasons']['updateInformationText'],
          'otherExplanation' => form_data['submissionReasons']['otherText'],
          'institutionType' => INSTITUTION_TYPE_ENUM[form_data['institutionClassification']],
          'isHigherLearning' => form_data['institutionProfile']['isIHL'] ? 'YES' : 'NO',
          'isTitle4' => form_data['institutionProfile']['participatesInTitleIV'] ? 'YES' : 'NO',
          'higherLearningDescription' => form_data['institutionProfile']['ihlDegreeTypes'],
          'title4Description' => form_data['institutionProfile']['opeidNumber']
        }
      end

      def format_acknowledgements(form_data)
        form_data['acknowledgement10a']['financiallySound'] =
          form_data['acknowledgement10a']['financiallySound'] ? 'YES' : 'NO'
      end

      def format_faculty(form_data)
        form_data['faculty'] = (form_data['governingBodyAndFaculty'] || []).map do |data|
          {
            'name' => combine_full_name(data['fullName']),
            'title' => data['title']
          }
        end
      end

      def format_medical_data(form_data)
        unless form_data['isMedicalSchool']
          form_data['medicalData'] = {}
          return
        end

        form_data['medicalData'] = {
          'isInWDOMS' => form_data['listedInWDOMS'] ? 'YES' : 'NO',
          'accreditingAgency' => form_data['accreditingAuthorityName'],
          'providesClassroomInstruction' => form_data['programAtLeast32Months'] ? 'YES' : 'NO',
          'hasRecentGraduatingClasses' => form_data['graduatedLast12Months'] ? 'YES' : 'NO'
        }
        if form_data['graduatedClasses'].present? && form_data['graduatedClasses'].size >= 2
          form_data['medicalData']['graduation1Date'] = form_data['graduatedClasses'][0]['graduationDate']
          form_data['medicalData']['graduation1NumStudents'] = form_data['graduatedClasses'][0]['graduatesCount']
          form_data['medicalData']['graduation2Date'] = form_data['graduatedClasses'][1]['graduationDate']
          form_data['medicalData']['graduation2NumStudents'] = form_data['graduatedClasses'][1]['graduatesCount']
        end
      end

      def format_contacts(form_data)
        form_data['contactInfo'] = {
          'financialRepName' => combine_full_name(form_data['financialRepresentative']['fullName']),
          'financialRepEmail' => form_data['financialRepresentative']['email'],
          'scoRepName' => combine_full_name(form_data['schoolCertifyingOfficial']['fullName']),
          'scoRepEmail' => form_data['schoolCertifyingOfficial']['email'],
          'authorizingOfficialName' => combine_full_name(form_data['authorizingOfficial']['fullName']),
          'authorizingOfficialSignature' => form_data['authorizingOfficial']['signature']
        }
      end
    end
  end
end
