# frozen_string_literal: true

require 'json_marshal/marshaller'

module CovidVaccine
  module V0
    class ExpandedRegistrationSubmission < ApplicationRecord
      include AASM

      aasm(:state) do
        # Fire off job for email confirmation to the user that submission has been received
        # Fire off job to determine EMIS eligibility to kick off after hours; transition to eligible or ineligible
        state :received, initial: true
        state :enrollment_pending, :enrollment_complete, :enrollment_failed, :registered,
              :enrollment_out_of_band, :registered_no_icn, :registered_no_facility

        # Batch id is updated based on time that batch was submitted; transitions to enrollment_pending
        event :submitted_for_enrollment do
          transitions from: :received, to: :enrollment_pending
        end

        # submission is successfully sent to VeText without an ICN
        event :successful_registration_no_icn do
          transitions from: :enrollment_failed, to: :registered_no_icn
        end

        # submission is successfully sent to VeText without a facility match
        event :successful_registration_no_facility do
          transitions from: :enrollment_failed, to: :registered_no_facility
        end

        # Enrollment returned a success; transitions to enrollment_complete
        event :detected_enrollment do
          transitions from: :enrollment_pending, to: :enrollment_complete
        end

        # submission is successfully sent to VeText
        event :successful_registration do
          transitions from: :enrollment_complete, to: :registered
        end

        # Enrollment returned a failure; transitions to enrollment_failed
        event :failed_enrollment do
          transitions from: :enrollment_pending, to: :enrollment_failed
        end

        # If there is no preferred facility the registration will need to be handled manually
        event :enrollment_requires_intervention do
          transitions from: :enrollment_pending, to: :enrollment_out_of_band
        end
      end

      after_initialize do |reg|
        reg.form_data&.symbolize_keys!
      end

      attr_encrypted :form_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller
      attr_encrypted :raw_form_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller
      attr_encrypted :eligibility_info, key: Settings.db_encryption_key, marshal: true,
                                        marshaler: JsonMarshal::Marshaller
    end
  end
end
