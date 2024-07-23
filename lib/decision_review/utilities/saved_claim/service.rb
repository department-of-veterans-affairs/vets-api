# frozen_string_literal: true

module DecisionReview
  ##
  # Service for persisting Decision Review SavedClaim
  #
  module SavedClaim
    module Service
      VALID_CLASS = [
        ::SavedClaim::HigherLevelReview,
        ::SavedClaim::NoticeOfDisagreement,
        ::SavedClaim::SupplementalClaim
      ].freeze

      def store_saved_claim(claim_class:, form:, guid:, uploaded_forms: [])
        return unless Flipper.enabled? :decision_review_form_store_saved_claims

        raise "Invalid class type '#{claim_class}'" unless VALID_CLASS.include? claim_class

        claim = claim_class.new(form:, guid:, uploaded_forms:)
        claim.save!
      rescue => e
        Rails.logger.warn("DecisionReview:Error saving #{claim_class}", { guid:, error: e.message })
      end
    end
  end
end
