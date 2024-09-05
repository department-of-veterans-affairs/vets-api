# frozen_string_literal: true

class SupportingEvidenceAttachmentSerializer
  include JSONAPI::Serializer

  set_type :supporting_evidence_attachments

  attribute :guid
end
