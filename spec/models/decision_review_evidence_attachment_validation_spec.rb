# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DecisionReviewEvidenceAttachmentValidation, type: :model do
  let(:record) { build(:decision_review_evidence_attachment_validation) }

  describe 'validations' do
    it 'validates presence of guid' do
      expect_attr_valid(record, :decision_review_evidence_attachment_guid)
      record.decision_review_evidence_attachment_guid = nil
      expect_attr_invalid(record, :decision_review_evidence_attachment_guid, "can't be blank")
    end
  end
end
