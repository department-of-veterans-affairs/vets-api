# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/field_mappings/va1010cg'

module PdfFill
  module Forms
    class Va1010cg < FormBase
      PDF_INPUT_LOCATIONS = OpenStruct.new(
        veteran: {
          name: {
            last: 'form1[0].#subform[15].LastName[0]',
            first: 'form1[0].#subform[15].FirstName[0]',
            middle: 'form1[0].#subform[15].MiddleName[0]',
            suffix: 'form1[0].#subform[15].Suffix[0]'
          },
          ssn: 'form1[0].#subform[15].SSN_TaxID[0]',
          dob: 'form1[0].#subform[15].DateOfBirth[0]',
          gender: 'form1[0].#subform[15].RadioButtonList[0]', # "2" | "3" | "Off"
          address: {
            street: 'form1[0].#subform[15].StreetAddress[0]',
            city: 'form1[0].#subform[15].City[0]',
            county: 'form1[0].#subform[15].County[0]',
            state: 'form1[0].#subform[15].State[0]',
            zip: 'form1[0].#subform[15].Zip[0]'
          },
          primary_phone: 'form1[0].#subform[15].PrimaryPhone[0]',
          alternative_phone: 'form1[0].#subform[15].AltPhone[0]',
          email: 'form1[0].#subform[15].Email[0]',
          planned_clinic: 'form1[0].#subform[15].NameVAMedicalCenter[0]',
          signature: {
            name: 'form1[0].#subform[15].Signature[0]',
            date: 'form1[0].#subform[15].DateSigned[0]'
          }
        },
        primaryCaregiver: {
          name: {
            last: 'form1[0].#subform[16].LastName[1]',
            first: 'form1[0].#subform[16].FirstName[1]',
            middle: 'form1[0].#subform[16].MiddleName[1]',
            suffix: 'form1[0].#subform[16].Suffix[1]'
          },
          ssn: 'form1[0].#subform[16].SSN_TaxID[1]',
          dob: 'form1[0].#subform[16].DateOfBirth[1]',
          gender: 'form1[0].#subform[16].RadioButtonList[1]', # "2" | "3" | "Off"
          address: {
            street: 'form1[0].#subform[16].StreetAddress[1]',
            city: 'form1[0].#subform[16].City[1]',
            county: 'form1[0].#subform[16].County[1]',
            state: 'form1[0].#subform[16].State[1]',
            zip: 'form1[0].#subform[16].Zip[1]'
          },
          mailingAddress: {
            street: 'form1[0].#subform[16].MailingStreetAddress[0]',
            city: 'form1[0].#subform[16].City[2]',
            county: 'form1[0].#subform[16].County[2]',
            state: 'form1[0].#subform[16].State[2]',
            zip: 'form1[0].#subform[16].Zip[2]'
          },
          primary_phone: 'form1[0].#subform[16].PrimaryPhone[1]',
          alternative_phone: 'form1[0].#subform[16].AltPhone[1]',
          email: 'form1[0].#subform[16].Email[1]',
          vet_relationship: 'form1[0].#subform[16].Relationship[0]',
          signature: {
            name: 'form1[0].#subform[16].Signature[1]',
            date: 'form1[0].#subform[16].DateSigned[1]'
          }
        },
        secondaryCaregiverOne: {
          name: {
            last: 'form1[0].#subform[17].LastName[2]',
            first: 'form1[0].#subform[17].FirstName[2]',
            middle: 'form1[0].#subform[17].MiddleName[2]',
            suffix: 'form1[0].#subform[17].Suffix[2]'
          },
          ssn: 'form1[0].#subform[17].SSN_TaxID[2]',
          dob: 'form1[0].#subform[17].DateOfBirth[2]',
          gender: 'form1[0].#subform[17].RadioButtonList[2]', # "2" | "3" | "Off"
          address: {
            street: 'form1[0].#subform[17].StreetAddress[2]',
            city: 'form1[0].#subform[17].City[3]',
            county: 'form1[0].#subform[17].County[3]',
            state: 'form1[0].#subform[17].State[3]',
            zip: 'form1[0].#subform[17].Zip[3]'
          },
          mailingAddress: {
            street: 'form1[0].#subform[17].MailingStreetAddress[1]',
            city: 'form1[0].#subform[17].City[4]',
            county: 'form1[0].#subform[17].County[4]',
            state: 'form1[0].#subform[17].State[4]',
            zip: 'form1[0].#subform[17].Zip[4]'
          },
          primary_phone: 'form1[0].#subform[17].PrimaryPhone[2]',
          alternative_phone: 'form1[0].#subform[17].AltPhone[2]',
          email: 'form1[0].#subform[17].Email[2]',
          vet_relationship: 'form1[0].#subform[17].Relationship[1]',
          signature: {
            name: 'form1[0].#subform[17].Signature[2]',
            date: 'form1[0].#subform[17].DateSigned[2]'
          }
        },
        secondaryCaregiverTwo: {
          name: {
            last: 'form1[0].#subform[18].LastName[3]',
            first: 'form1[0].#subform[18].FirstName[3]',
            middle: 'form1[0].#subform[18].MiddleName[3]',
            suffix: 'form1[0].#subform[18].Suffix[3]'
          },
          ssn: 'form1[0].#subform[18].SSN_TaxID[3]',
          dob: 'form1[0].#subform[18].DateOfBirth[3]',
          gender: 'form1[0].#subform[18].RadioButtonList[3]', # "2" | "3" | "Off"
          address: {
            street: 'form1[0].#subform[18].StreetAddress[3]',
            city: 'form1[0].#subform[18].City[5]',
            county: 'form1[0].#subform[18].County[5]',
            state: 'form1[0].#subform[18].State[5]',
            zip: 'form1[0].#subform[18].Zip[5]'
          },
          mailingAddress: {
            street: 'form1[0].#subform[18].MailingStreetAddress[2]',
            city: 'form1[0].#subform[18].City[6]',
            county: 'form1[0].#subform[18].County[6]',
            state: 'form1[0].#subform[18].State[6]',
            zip: 'form1[0].#subform[18].Zip[6]'
          },
          primary_phone: 'form1[0].#subform[18].PrimaryPhone[3]',
          alternative_phone: 'form1[0].#subform[18].AltPhone[3]',
          email: 'form1[0].#subform[18].Email[3]',
          vet_relationship: 'form1[0].#subform[18].Relationship[2]',
          signature: {
            name: 'form1[0].#subform[18].Signature[3]',
            date: 'form1[0].#subform[18].DateSigned[3]'
          }
        }
      )

      KEY = PdfFill::Forms::FieldMappings::Va1010cg::KEY

      def merge_fields(options = {})
        @form_data['helpers'] = {
          'veteran' => {},
          'primaryCaregiver' => {},
          'secondaryCaregiverOne' => {},
          'secondaryCaregiverTwo' => {}
        }

        merge_address_helpers
        merge_mailing_address_helpers
        merge_sex_helpers
        merge_signature_helpers if options[:sign]
        merge_planned_facility_label_helper

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

      def merge_mailing_address_helpers
        %w[primaryCaregiver secondaryCaregiverOne secondaryCaregiverTwo].each do |subject|
          @form_data['helpers'][subject]['mailingAddress'] = {
            'street' => combine_hash(@form_data.dig(subject, 'mailingAddress'), %w[street street2])
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

      def merge_planned_facility_label_helper
        target_facility_code = @form_data.dig 'veteran', 'plannedClinic'

        display_value = if Flipper.enabled? :caregiver_lookup_facility_name_db
                          selected_facility = HealthFacility.find_by(station_number: target_facility_code)
                          if selected_facility.nil?
                            target_facility_code
                          else
                            "#{selected_facility.station_number} - #{selected_facility.name}"
                          end
                        else
                          caregiver_facilities = VetsJsonSchema::CONSTANTS['caregiverProgramFacilities'].values.flatten
                          selected_facility = caregiver_facilities.find do |facility|
                            facility['code'] == target_facility_code
                          end
                          if selected_facility.nil?
                            target_facility_code
                          else
                            "#{selected_facility['code']} - #{selected_facility['label']}"
                          end
                        end

        @form_data['helpers']['veteran']['plannedClinic'] = display_value
      end

      def generate_signiture_timestamp
        Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m/%d/%Y %l:%M%P %Z')
      end
    end
  end
end
