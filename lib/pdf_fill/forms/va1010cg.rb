# frozen_string_literal: true

require 'pdf_fill/forms/form_base'

# rubocop:disable Metrics/ClassLength

module PdfFill
  module Forms
    class Va1010cg < FormBase
      PDF_INPUT_LOCATIONS = OpenStruct.new(
        veteran: {
          name: {
            first: 'form1[0].#subform[14].TextField3[1]',
            middle: 'form1[0].#subform[14].TextField3[2]',
            last: 'form1[0].#subform[14].TextField3[0]'
          },
          ssn: 'form1[0].#subform[14].TextField3[3]',
          dob: 'form1[0].#subform[14].Date[0]',
          gender: 'form1[0].#subform[14].RadioButtonList[0]', # "2" | "3" | "Off"
          address: {
            street: 'form1[0].#subform[14].TextField3[4]',
            city: 'form1[0].#subform[14].TextField3[5]',
            state: 'form1[0].#subform[14].TextField3[6]',
            zip: 'form1[0].#subform[14].TextField3[7]'
          },
          primary_phone: 'form1[0].#subform[14].TextField3[8]',
          alternative_phone: 'form1[0].#subform[14].TextField3[9]',
          email: 'form1[0].#subform[14].TextField3[11]',
          planned_clinic: 'form1[0].#subform[14].TextField3[10]',
          last_treatment_facility: {
            name: 'form1[0].#subform[14].TextField3[12]',
            type: 'form1[0].#subform[14].RadioButtonList[1]' # "1" | "2" | "Off"
          },
          signature: {
            name: 'form1[0].#subform[14].SignatureTextField1[0]',
            date: 'form1[0].#subform[14].Date[2]'
          }
        },
        primaryCaregiver: {
          name: {
            first: 'form1[0].#subform[14].TextField3[14]',
            middle: 'form1[0].#subform[14].TextField3[13]',
            last: 'form1[0].#subform[14].TextField3[15]'
          },
          ssn: 'form1[0].#subform[14].TextField3[16]',
          dob: 'form1[0].#subform[14].Date[1]',
          gender: 'form1[0].#subform[14].RadioButtonList[3]', # "2" | "3" | "Off"
          address: {
            street: 'form1[0].#subform[14].TextField3[17]',
            city: 'form1[0].#subform[14].TextField3[18]',
            state: 'form1[0].#subform[14].TextField3[19]',
            zip: 'form1[0].#subform[14].TextField3[20]'
          },
          primary_phone: 'form1[0].#subform[14].TextField3[21]',
          alternative_phone: 'form1[0].#subform[14].TextField3[22]',
          email: 'form1[0].#subform[14].TextField3[24]',
          vet_relationship: 'form1[0].#subform[14].TextField3[23]',
          has_health_insurance: 'form1[0].#subform[14].RadioButtonList[2]', # "1" | "2" | "Off"
          signature: {
            name: 'form1[0].#subform[15].SignatureTextField2[0]',
            date: 'form1[0].#subform[15].Date[3]'
          }
        },
        secondaryCaregiverOne: {
          name: {
            first: 'form1[0].#subform[15].TextField3[26]',
            middle: 'form1[0].#subform[15].TextField3[27]',
            last: 'form1[0].#subform[15].TextField3[25]'
          },
          ssn: 'form1[0].#subform[15].TextField3[34]',
          dob: 'form1[0].#subform[15].Date[5]',
          gender: 'form1[0].#subform[15].RadioButtonList[4]', # "2" | "3" | "Off"
          address: {
            street: 'form1[0].#subform[15].TextField3[28]',
            city: 'form1[0].#subform[15].TextField3[29]',
            state: 'form1[0].#subform[15].TextField3[30]',
            zip: 'form1[0].#subform[15].TextField3[31]'
          },
          primary_phone: 'form1[0].#subform[15].TextField3[36]',
          alternative_phone: 'form1[0].#subform[15].TextField3[35]',
          email: 'form1[0].#subform[15].TextField3[33]',
          vet_relationship: 'form1[0].#subform[15].TextField3[32]',
          signature: {
            name: 'form1[0].#subform[15].SignatureTextField3[0]',
            date: 'form1[0].#subform[15].Date[4]'
          }
        },
        secondaryCaregiverTwo: {
          name: {
            first: 'form1[0].#subform[16].TextField3[38]',
            middle: 'form1[0].#subform[16].TextField3[39]',
            last: 'form1[0].#subform[16].TextField3[37]'
          },
          ssn: 'form1[0].#subform[16].TextField3[46]',
          dob: 'form1[0].#subform[16].Date[7]',
          gender: 'form1[0].#subform[16].RadioButtonList[5]', # "2" | "3" | "Off"
          address: {
            street: 'form1[0].#subform[16].TextField3[40]',
            city: 'form1[0].#subform[16].TextField3[41]',
            state: 'form1[0].#subform[16].TextField3[42]',
            zip: 'form1[0].#subform[16].TextField3[43]'
          },
          primary_phone: 'form1[0].#subform[16].TextField3[48]',
          alternative_phone: 'form1[0].#subform[16].TextField3[47]',
          email: 'form1[0].#subform[16].TextField3[45]',
          vet_relationship: 'form1[0].#subform[16].TextField3[44]',
          signature: {
            name: 'form1[0].#subform[16].SignatureTextField4[0]',
            date: 'form1[0].#subform[16].Date[6]'
          }
        }
      )

      KEY = {
        # Formatted fields
        'helpers' => {
          'veteran' => {
            'address' => {
              'street' => {
                key: PDF_INPUT_LOCATIONS.veteran[:address][:street],
                limit: 80,
                question_num: 7,
                question_text: 'VETERAN/SERVICEMEMBER > Address > Street'
              }
            },
            'gender' => {
              key: PDF_INPUT_LOCATIONS.veteran[:gender]
            },
            'lastTreatmentFacility' => {
              'type' => {
                key: PDF_INPUT_LOCATIONS.veteran[:last_treatment_facility][:type]
              }
            },
            'signature' => {
              'name' => {
                key: PDF_INPUT_LOCATIONS.veteran[:signature][:name]
              },
              'date' => {
                key: PDF_INPUT_LOCATIONS.veteran[:signature][:date],
                format: 'date'
              }
            },
            'plannedClinic' => {
              key: PDF_INPUT_LOCATIONS.veteran[:planned_clinic]
            }
          },
          'primaryCaregiver' => {
            'address' => {
              'street' => {
                key: PDF_INPUT_LOCATIONS.primaryCaregiver[:address][:street],
                limit: 80,
                question_num: 25,
                question_text: 'PRIMARY FAMILY CAREGIVER > Address > Street'
              }
            },
            'gender' => {
              key: PDF_INPUT_LOCATIONS.primaryCaregiver[:gender]
            },
            'hasHealthInsurance' => {
              key: PDF_INPUT_LOCATIONS.primaryCaregiver[:has_health_insurance]
            },
            'signature' => {
              'name' => {
                key: PDF_INPUT_LOCATIONS.primaryCaregiver[:signature][:name]
              },
              'date' => {
                key: PDF_INPUT_LOCATIONS.primaryCaregiver[:signature][:date],
                format: 'date'
              }
            }
          },
          'secondaryCaregiverOne' => {
            'address' => {
              'street' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:address][:street],
                limit: 80,
                question_num: 48,
                question_text: 'SECONDARY FAMILY CAREGIVER (1) > Address > Street'
              }
            },
            'gender' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:gender]
            },
            'signature' => {
              'name' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:signature][:name]
              },
              'date' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:signature][:date],
                format: 'date'
              }
            }
          },
          'secondaryCaregiverTwo' => {
            'address' => {
              'street' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:address][:street],
                limit: 80,
                question_num: 65,
                question_text: 'SECONDARY FAMILY CAREGIVER (2) > Address > Street'
              }
            },
            'gender' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:gender]
            },
            'signature' => {
              'name' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:signature][:name]
              },
              'date' => {
                key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:signature][:date],
                format: 'date'
              }
            }
          }
        },
        # Direct input
        'veteran' => {
          'fullName' => {
            'last' => {
              key: PDF_INPUT_LOCATIONS.veteran[:name][:last],
              limit: 29,
              question_num: 1,
              question_text: 'VETERAN/SERVICEMEMBER > Last Name'
            },
            'first' => {
              key: PDF_INPUT_LOCATIONS.veteran[:name][:first],
              limit: 29,
              question_num: 2,
              question_text: 'VETERAN/SERVICEMEMBER > First Name'
            },
            'middle' => {
              key: PDF_INPUT_LOCATIONS.veteran[:name][:middle],
              limit: 29,
              question_num: 3,
              question_text: 'VETERAN/SERVICEMEMBER > Middle Name'
            }
          },
          'ssnOrTin' => {
            key: PDF_INPUT_LOCATIONS.veteran[:ssn]
          },
          'dateOfBirth' => {
            key: PDF_INPUT_LOCATIONS.veteran[:dob],
            format: 'date'
          },
          'address' => {
            'city' => {
              key: PDF_INPUT_LOCATIONS.veteran[:address][:city],
              limit: 29,
              question_num: 8,
              question_text: 'VETERAN/SERVICEMEMBER > Address > City'
            },
            'state' => {
              key: PDF_INPUT_LOCATIONS.veteran[:address][:state],
              limit: 29,
              question_num: 9,
              question_text: 'VETERAN/SERVICEMEMBER > Address > State'
            },
            'postalCode' => {
              key: PDF_INPUT_LOCATIONS.veteran[:address][:zip],
              limit: 29,
              question_num: 10,
              question_text: 'VETERAN/SERVICEMEMBER > Address > Zip Code'
            }
          },
          'primaryPhoneNumber' => {
            key: PDF_INPUT_LOCATIONS.veteran[:primary_phone]
          },
          'alternativePhoneNumber' => {
            key: PDF_INPUT_LOCATIONS.veteran[:alternative_phone]
          },
          'email' => {
            key: PDF_INPUT_LOCATIONS.veteran[:email],
            limit: 79,
            question_num: 13,
            question_text: 'VETERAN/SERVICEMEMBER > Email'
          },
          'lastTreatmentFacility' => {
            'name' => {
              key: PDF_INPUT_LOCATIONS.veteran[:last_treatment_facility][:name],
              limit: 72,
              question_num: 16,
              question_text: 'VETERAN/SERVICEMEMBER > Last Treatment Facility > Name'
            }
          }
        },
        'primaryCaregiver' => {
          'fullName' => {
            'last' => {
              key: PDF_INPUT_LOCATIONS.primaryCaregiver[:name][:last],
              limit: 29,
              question_num: 19,
              question_text: 'PRIMARY FAMILY CAREGIVER > Last Name'
            },
            'first' => {
              key: PDF_INPUT_LOCATIONS.primaryCaregiver[:name][:first],
              limit: 29,
              question_num: 20,
              question_text: 'PRIMARY FAMILY CAREGIVER > First Name'
            },
            'middle' => {
              key: PDF_INPUT_LOCATIONS.primaryCaregiver[:name][:middle],
              limit: 29,
              question_num: 21,
              question_text: 'PRIMARY FAMILY CAREGIVER > Middle Name'
            }
          },
          'ssnOrTin' => {
            key: PDF_INPUT_LOCATIONS.primaryCaregiver[:ssn]
          },
          'dateOfBirth' => {
            key: PDF_INPUT_LOCATIONS.primaryCaregiver[:dob],
            format: 'date'
          },
          'address' => {
            'city' => {
              key: PDF_INPUT_LOCATIONS.primaryCaregiver[:address][:city],
              limit: 29,
              question_num: 26,
              question_text: 'PRIMARY FAMILY CAREGIVER > Address > City'
            },
            'state' => {
              key: PDF_INPUT_LOCATIONS.primaryCaregiver[:address][:state],
              limit: 29,
              question_num: 27,
              question_text: 'PRIMARY FAMILY CAREGIVER > Address > State'
            },
            'postalCode' => {
              key: PDF_INPUT_LOCATIONS.primaryCaregiver[:address][:zip],
              limit: 29,
              question_num: 28,
              question_text: 'PRIMARY FAMILY CAREGIVER > Address > Zip Code'
            }
          },
          'primaryPhoneNumber' => {
            key: PDF_INPUT_LOCATIONS.primaryCaregiver[:primary_phone]
          },
          'alternativePhoneNumber' => {
            key: PDF_INPUT_LOCATIONS.primaryCaregiver[:alternative_phone]
          },
          'email' => {
            key: PDF_INPUT_LOCATIONS.primaryCaregiver[:email],
            limit: 45,
            question_num: 31,
            question_text: 'PRIMARY FAMILY CAREGIVER > Email'
          },
          'vetRelationship' => {
            key: PDF_INPUT_LOCATIONS.primaryCaregiver[:vet_relationship]
          }
        },
        'secondaryCaregiverOne' => {
          'fullName' => {
            'last' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:name][:last],
              limit: 29,
              question_num: 42,
              question_text: 'SECONDARY FAMILY CAREGIVER (1) > Last Name'
            },
            'first' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:name][:first],
              limit: 29,
              question_num: 43,
              question_text: 'SECONDARY FAMILY CAREGIVER (1) > First Name'
            },
            'middle' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:name][:middle],
              limit: 29,
              question_num: 44,
              question_text: 'SECONDARY FAMILY CAREGIVER (1) > Middle Name'
            }
          },
          'ssnOrTin' => {
            key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:ssn]
          },
          'dateOfBirth' => {
            key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:dob],
            format: 'date'
          },
          'address' => {
            'city' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:address][:city],
              limit: 29,
              question_num: 49,
              question_text: 'SECONDARY FAMILY CAREGIVER (1) > Address > City'
            },
            'state' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:address][:state],
              limit: 29,
              question_num: 50,
              question_text: 'SECONDARY FAMILY CAREGIVER (1) > Address > State'
            },
            'postalCode' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:address][:zip],
              limit: 29,
              question_num: 51,
              question_text: 'SECONDARY FAMILY CAREGIVER (1) > Address > Zip Code'
            }
          },
          'primaryPhoneNumber' => {
            key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:primary_phone]
          },
          'alternativePhoneNumber' => {
            key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:alternative_phone]
          },
          'email' => {
            key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:email],
            limit: 45,
            question_num: 54,
            question_text: 'SECONDARY FAMILY CAREGIVER (1) > Email'
          },
          'vetRelationship' => {
            key: PDF_INPUT_LOCATIONS.secondaryCaregiverOne[:vet_relationship]
          }
        },
        'secondaryCaregiverTwo' => {
          'fullName' => {
            'last' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:name][:last],
              limit: 29,
              question_num: 59,
              question_text: 'SECONDARY FAMILY CAREGIVER (2) > Last Name'
            },
            'first' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:name][:first],
              limit: 29,
              question_num: 60,
              question_text: 'SECONDARY FAMILY CAREGIVER (2) > First Name'
            },
            'middle' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:name][:middle],
              limit: 29,
              question_num: 61,
              question_text: 'SECONDARY FAMILY CAREGIVER (2) > Middle Name'
            }
          },
          'ssnOrTin' => {
            key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:ssn]
          },
          'dateOfBirth' => {
            key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:dob],
            format: 'date'
          },
          'address' => {
            'city' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:address][:city],
              limit: 29,
              question_num: 66,
              question_text: 'SECONDARY FAMILY CAREGIVER (2) > Address > City'
            },
            'state' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:address][:state],
              limit: 29,
              question_num: 67,
              question_text: 'SECONDARY FAMILY CAREGIVER (2) > Address > State'
            },
            'postalCode' => {
              key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:address][:zip],
              limit: 29,
              question_num: 68,
              question_text: 'SECONDARY FAMILY CAREGIVER (2) > Address > Zip'
            }
          },
          'primaryPhoneNumber' => {
            key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:primary_phone]
          },
          'alternativePhoneNumber' => {
            key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:alternative_phone]
          },
          'email' => {
            key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:email],
            limit: 45,
            question_num: 71,
            question_text: 'SECONDARY FAMILY CAREGIVER (2) > Email'
          },
          'vetRelationship' => {
            key: PDF_INPUT_LOCATIONS.secondaryCaregiverTwo[:vet_relationship]
          }
        }
      }.freeze

      def merge_fields(options = {})
        @form_data['helpers'] = {
          'veteran' => {},
          'primaryCaregiver' => {},
          'secondaryCaregiverOne' => {},
          'secondaryCaregiverTwo' => {}
        }

        merge_address_helpers
        merge_sex_helpers
        merge_signature_helpers if options[:sign]

        merge_primary_caregiver_has_health_insurance_helper
        merge_veteran_last_treatment_facility_helper
        merge_planned_facility_label_helper(options[:facility_label])

        @form_data
      end

      private

      def merge_address_helpers
        subjects.each do |subject|
          @form_data['helpers'][subject]['address'] = {
            'street' => combine_hash(@form_data.dig(subject, 'address'), %w[street street2])
          }
        end
      end

      def merge_sex_helpers
        subjects.each do |subject|
          @form_data['helpers'][subject]['gender'] = case @form_data.dig(subject, 'gender')
                                                     when 'M'
                                                       '2'
                                                     when 'F'
                                                       '3'
                                                     else
                                                       'Off'
                                                     end
        end
      end

      def merge_signature_helpers
        timestamp = generate_signiture_timestamp

        subjects.each do |subject|
          user_provided_signature = @form_data.dig(subject, 'signature')
          signature = user_provided_signature || combine_full_name(@form_data.dig(subject, 'fullName'))

          if @form_data[subject].present? && signature.present?
            @form_data['helpers'][subject]['signature'] = {
              'name' => "/es/ #{signature}",
              'date' => timestamp
            }
          end
        end
      end

      def subjects
        %w[veteran primaryCaregiver secondaryCaregiverOne secondaryCaregiverTwo]
      end

      def merge_primary_caregiver_has_health_insurance_helper
        value = @form_data.dig('primaryCaregiver', 'hasHealthInsurance')
        selection = case value
                    when true
                      '2'
                    when false
                      '1'
                    else
                      'Off'
                    end

        @form_data['helpers']['primaryCaregiver']['hasHealthInsurance'] = selection
      end

      def merge_veteran_last_treatment_facility_helper
        value = @form_data.dig('veteran', 'lastTreatmentFacility', 'type')
        selection = case value
                    when 'hospital'
                      '2'
                    when 'clinic'
                      '1'
                    else
                      'Off'
                    end

        @form_data['helpers']['veteran']['lastTreatmentFacility'] = {
          'type' => selection
        }
      end

      # facility_label is an optional parameter, so it is important to fall back to form value if absent
      def merge_planned_facility_label_helper(facility_label = @form_data['veteran']['plannedClinic'])
        @form_data['helpers']['veteran']['plannedClinic'] = facility_label
      end

      def generate_signiture_timestamp
        Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m/%d/%Y %l:%M%P %Z')
      end
    end
  end
end

# rubocop:enable Metrics/ClassLength
