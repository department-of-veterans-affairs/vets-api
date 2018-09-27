# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class WorkflowReport
      def initialize(saved_claim_id)
        @submission = submission(saved_claim_id)
      end

      def workflow_success?
        return form_526_success? if no_ancillary_items?
        return form_526_and_uploads_success? if only_uploads?
        return form_526_and_4142_form_success? if only_4142_form?
        full_workflow_success?
      end

      def form_526_success?
        @submission.disability_compensation_job.transaction_status == 'received'
      end

      def uploads_success?
        @submission.uploads_success?
      end

      def form_4142_success?
        @submission.form_4142_success?
      end

      private

      def form_526_and_4142_form_success?
        form_526_success? && form_4142_success?
      end

      def form_526_and_uploads_success?
        form_526_success? && uploads_success?
      end

      def full_workflow_success?
        form_526_success? && uploads_success? && form_4142_success?
      end

      def no_ancillary_items?
        !@submission.has_uploads? && !@submission.has_form_4142?
      end

      def only_uploads?
        @submission.has_uploads? && !@submission.has_form_4142?
      end

      def only_4142_form?
        !@submission.has_uploads? && @submission.has_form_4142?
      end

      def submission(id)
        SavedClaim::DisabilityCompensation.find(id).disability_compensation_submission
      end
    end
  end
end
