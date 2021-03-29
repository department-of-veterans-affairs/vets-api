# frozen_string_literal: true

module CovidVaccine
  module V0
    class ExpandedRegistrationSubmission < ApplicationRecord
      include AASM

      # CSV Constants
      VA_AGENCY_IDENTIFIER = '8'

      aasm(:state) do
        # Fire off job for email confirmation to the user that submission has been received
        # Fire off job to determine EMIS eligibility to kick off after hours; transition to eligible or ineligible
        state :sequestered, initial: true
        state :eligible_us, :eligible_non_us, :ineligible, :enrollment_pending, :enrollment_complete,
              :enrollment_failed, :registered

        # ICN and EMIS lookup both satisfactory or no lookup possible; transitions to eligible
        event :emis_eligibility_criteria_passed do
          transitions from: :sequestered, to: :eligible_us, if: :country_us?
          transitions from: :sequestered, to: :eligible_non_us, unless: :country_us?
        end

        # ICN and EMIS returns unsatisfatory eligibility results; transitions to ineligible
        event :emis_eligibility_failed do
          transitions from: :sequestered, to: :ineligible
        end

        # Batch id is updated based on time that batch was submitted; transitions to enrollment_pending
        event :submitted_for_enrollment do
          transitions from: :eligible_us, to: :enrollment_pending
        end

        # Enrollment returned a success; transitions to enrollment_complete
        event :enrolled_successfully do
          transitions from: :enrollment_pending, to: :enrollment_complete
        end

        # Enrollment returned a failure; transitions to enrollment_failed
        event :failed_enrollment do
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

      private

      def country_us?
        raw_form_data[:country_name] == 'USA'
      end
    end
  end
end
