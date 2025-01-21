# frozen_string_literal: true

module DecisionReviews
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
        raise "Invalid class type '#{claim_class}'" unless VALID_CLASS.include? claim_class

        claim = claim_class.new(form:, guid:, uploaded_forms:)
        claim.save!
      end
    end
  end
end
