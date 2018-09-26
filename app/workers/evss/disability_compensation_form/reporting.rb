# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class Reporting
      def initialize(saved_claim_id)
        @submission = submission(saved_claim_id)
      end

      def workflow_complete?
        return form_526_complete? if no_ancillary_items?
        return form_526_and_uploads_complete? if only_uploads?
        return form_526_and_4142_form_complete? if only_4142_form?
        all_complete?
      end

      def set_has_uploads
        @submission.update(has_uploads: true)
      end

      def uploads_success_handler(_status, options)
        @submission = submission(options['saved_claim_id'])
        @submission.update(uploads_success: true)
      end

      def set_has_form_4142
        @submission.update(has_form_4142: true)
      end

      def form_4142_success_handler
        @submission.update(form_4142_success: true)
      end

      private

      def form_526_and_4142_form_complete?
        form_526_complete? && @submission.form_4142_success?
      end

      def form_526_and_uploads_complete?
        form_526_complete? && @submission.uploads_success?
      end

      def all_complete?
        form_526_complete? && @submission.uploads_success? && @submission.form_4142_success?
      end

      def form_526_complete?
        @submission.disability_compensation_job.transaction_status == 'received'
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

      def submission(saved_claim_id)
        SavedClaim::DisabilityCompensation.find(saved_claim_id).disability_compensation_submission
      end
    end
  end
end
