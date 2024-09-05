# frozen_string_literal: true

class DecisionReviewEvidenceAttachmentSerializer
  include JSONAPI::Serializer

  set_type :decision_review_evidence_attachments

  attribute :guid
end
