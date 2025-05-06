# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/field_mappings/va1010cg'

module PdfFill
  module Forms
    class Va1010cg < FormBase
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
