# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class WorkflowSteps
      def set_has_uploads(id)
        submission(id).update(has_uploads: true)
      end

      def set_has_form_4142(id)
        submission(id).update(has_form_4142: true)
      end

      def uploads_success_handler(_status, options)
        submission(options['saved_claim_id']).update(uploads_success: true)
      end

      def form_4142_success_handler(id)
        submission(id).update(form_4142_success: true)
      end

      private

      def submission(id)
        SavedClaim::DisabilityCompensation.find(id).disability_compensation_submission
      end
    end
  end
end
