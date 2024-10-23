# frozen_string_literal: true

module DataMigrations
  module WriteBenefitsIntakeUuidsToFormSubmissionAttempts
    module_function

    def run
      FormSubmissionAttempt.find_each do |attempt|
        next if attempt.benefits_intake_uuid

        attempt.update(benefits_intake_uuid: attempt.form_submission.benefits_intake_uuid)
      end
    end
  end
end
