# frozen_string_literal: true

module CovidVaccine
  module V0
    class ExpandedRegistrationSubmission < ApplicationRecord
      include AASM

      # CSV Constants
      CSV_AGENCY = 8

      # Processing States
      SEQUESTERED = 'sequestered'
      INELIGIBLE = 'ineligible'
      ENROLLMENT_PENDING = 'enrollment_pending'
      ENROLLMENT_COMPLETE = 'enrollment_complete'
      ENROLLMENT_FAILED = 'enrollment_failed'
      REGISTERED = 'registered'

      aasm do
        # Fire off job for email confirmation to the user that submission has been received
        # Fire off job to determine EMIS eligibility to kick off after hours; transition to eligible or ineligible
        state :sequestered, initial: true
        state :ineligible, :enrollment_pending, :enrollment_complete, :enrollment_failed, :registered

        # ICN and EMIS lookup both satisfactory; transitions to eligible
        event :emis_eligibility_successful do
          transitions from: :sequestered, to: :eligible
        end

        # ICN and/or EMIS lookup failed to return results; transitions to eligible
        event :emis_eligibility_unknown do
          transitions from: :sequestered, to: :eligible
        end

        # ICN and EMIS returns unsatisfatory eligibility results; transitions to ineligible
        event :emis_eligibility_failed do
          transitions from: :sequestered, to: :ineligible
        end

        # Batch id is updated based on time that batch was submitted; transitions to enrollment_pending
        event :submitted_for_enrollment do
          transitions from: :eligible, to: :enrollment_pending
        end

        # Enrollment returned a success; transitions to enrollment_complete
        event :enrollment_successful do
          transitions from: :enrollment_pending, to: :enrollment_complete
        end

        # Enrollment returned a failure; transitions to enrollment_failed
        event :enrollment_failed do
          transitions from: :enrollment_pending, to: :enrollment_failed
        end
      end

      after_initialize do |reg|
        reg.form_data&.symbolize_keys!
      end

      attr_encrypted :form_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller
      attr_encrypted :raw_form_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller
      attr_encrypted :eligibility_info, key: Settings.db_encryption_key, marshal: true,
                                        marshaler: JsonMarshal::Marshaller

      # We want records that have acceptable discharge status, country, state, zip and facility                                  
      def self.to_csv(separater = "^")
        CSV.generate(col_sep: separater) do |csv| 
          eligible.order('created_at DESC').each do |es|
            csv << es.send(:csv_row)
          end
        end
      end

      private

      def csv_row
        raw_form_data.slice(:first_name, :middle_name, :last_name, :birth_date, :ssn, :gender].values 
          + icn
          + csv_address
          + raw_form_data.slice(:city, :state, :zip, :phone, :email, :preferred_facility)
          + csv_agency
      end

      def csv_address
        "#{raw_form_data[:address_line_1]} #{raw_form_data[:address_line_2]} #{raw_form_data[:address_line_3]}".strip
      end

      def icn
        eligibility_info[:icn]
      end

      def csv_agency
        CSV_AGENCY
      end
    end
  end
end
