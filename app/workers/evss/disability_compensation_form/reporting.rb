# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class Reporting
      def mark_has_uploads(saved_claim_id)
        saved_claim(saved_claim_id).disability_compensation_submission.update_attribute(:has_uploads, true)
      end

      def on_uploads_success(_status, options)
        saved_claim_id = options['saved_claim_id']
        saved_claim(saved_claim_id).disability_compensation_submission.update_attribute(:uploads_success, true)
      end

      def mark_has_form_4142(saved_claim_id)
        saved_claim(saved_claim_id).disability_compensation_submission.update_attribute(:has_form_4142, true)
      end

      def on_form_4142_success(saved_claim_id)
        saved_claim(saved_claim_id).disability_compensation_submission.update_attribute(:form_4142_success, true)
      end

      private

      def saved_claim(saved_claim_id)
        SavedClaim::DisabilityCompensation.find(saved_claim_id)
      end
    end
  end
end
