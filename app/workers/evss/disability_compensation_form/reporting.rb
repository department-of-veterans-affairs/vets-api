# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class Reporting

      def initialize(saved_claim_id)
        @submission = submission(saved_claim_id)
      end

      def workflow_complete?
        form_526_success = @submission.disability_compensation_job.transaction_status == 'received'

        return form_526_success if no_ancillary_items?
        return form_526_success && @submission.uploads_success? if only_includes_uploads?
        return form_526_success && @submission.form_4142_success? if only_includes_4142_form?
        form_526_success && @submission.uploads_success? && @submission.form_4142_success?
      end

      def set_has_uploads
        @submission.update_attribute(:has_uploads, true)
      end

      def uploads_success_handler(_status, options)
        @submission = submission(options['saved_claim_id'])
        @submission.update_attribute(:uploads_success, true)
      end

      def set_has_form_4142
        @submission.update_attribute(:has_form_4142, true)
      end

      def form_4142_success_handler
        @submission.update_attribute(:form_4142_success, true)
      end

      private

      def form_526_success?(async_job)
        async_job.transaction_status == 'received'
      end

      def no_ancillary_items?
        !@submission.has_uploads? && !@submission.has_form_4142?
      end

      def only_includes_uploads?
        @submission.has_uploads? && !@submission.has_form_4142?
      end

      def only_includes_4142_form?
        !@submission.has_uploads? && @submission.has_form_4142?
      end

      def submission(saved_claim_id)
        SavedClaim::DisabilityCompensation.find(saved_claim_id).disability_compensation_submission
      end
    end
  end
end
